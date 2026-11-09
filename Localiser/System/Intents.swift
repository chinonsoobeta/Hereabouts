import AppIntents
import Foundation

/// Siri, Shortcuts and Spotlight actions all reach the notebook through these.
/// They run inside the app's process and use the same store the screens use.
@MainActor enum IntentLibrary {
    static var store: LocaliserStore?
    static func open() throws -> LocaliserStore {
        if let store { return store }
        let opened = try LocaliserStore()
        store = opened
        return opened
    }
}

enum HereaboutsIntentError: Error, CustomLocalizedStringResourceConvertible {
    case notFound, freeLimit, emptyName
    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .notFound: "That thing isn't in your notebook anymore."
        case .freeLimit: "You can save \(CreationKind.item.freeLimit) things for free. Open Hereabouts to get Pro, or archive a thing first."
        case .emptyName: "Give your thing a name."
        }
    }
}

// MARK: Entities

struct ThingEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Thing" }
    static var defaultQuery: ThingQuery { ThingQuery() }
    var id: UUID
    var name: String
    var path: String
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: path.isEmpty ? "No place yet" : "\(path)")
    }
}

extension ThingEntity {
    /// A private thing can still be asked for by name, but its place isn't shown.
    @MainActor init(_ item: Belonging) { self.init(id: item.id, name: item.name, path: item.isPrivate ? String(localized: "Private") : item.place?.path ?? "") }
}

struct ThingQuery: EntityStringQuery {
    @MainActor func entities(for identifiers: [UUID]) async throws -> [ThingEntity] {
        let store = try IntentLibrary.open()
        return store.items.filter { identifiers.contains($0.id) && !$0.isDeleted }.map(ThingEntity.init)
    }
    @MainActor func entities(matching string: String) async throws -> [ThingEntity] {
        Self.matches(string, in: try IntentLibrary.open()).map(ThingEntity.init)
    }
    /// A private thing is only found by its name or another name, so a place or note doesn't give it away.
    @MainActor static func matches(_ string: String, in store: LocaliserStore) -> [Belonging] {
        // A blank query matches everything in Find, but here it would list private things.
        let named = !ItemSearch.normalized(string).isEmpty
        return ItemSearch.results(query: string, entries: store.searchIndex, archived: false)
            .filter { !$0.isPrivate || named && ItemSearch.score(query: string, name: $0.name, aliases: $0.aliases, place: "", notes: "") != nil }
            .prefix(12).map { $0 }
    }
    @MainActor func suggestedEntities() async throws -> [ThingEntity] {
        try Self.shareable(in: IntentLibrary.open()).map(ThingEntity.init)
    }
    /// The names handed to Siri and the Shortcuts picker: most recently confirmed first, never private, archived or deleted.
    @MainActor static func shareable(in store: LocaliserStore, limit: Int = ShortcutParameters.cap) -> [Belonging] {
        Array(store.items.filter { !$0.archived && !$0.isDeleted && !$0.isPrivate }.sorted { $0.lastConfirmed > $1.lastConfirmed }.prefix(limit))
    }
}

/// Siri only knows the thing names it was last told. This tells it again after the notebook changes.
@MainActor final class ShortcutParameters {
    /// Xcode's App Intents notes say the system serves about 1,000 expanded phrases per language and truncates beyond that.
    /// Seven phrases take a thing, so 100 names use 700 of them and leave room for the rest.
    static let cap = 100
        static let shared = ShortcutParameters()
    static func schedule() { shared.schedule() }

    /// A restore or an import saves many times in a row; the system hears about it once, a moment after the last save.
    let delay: Duration
    let update: @MainActor () -> Void
    private var pending: Task<Void, Never>?
    init(delay: Duration = .seconds(2), update: @escaping @MainActor () -> Void = { HereaboutsShortcuts.updateAppShortcutParameters() }) {
        self.delay = delay; self.update = update
    }
    func schedule() {
        pending?.cancel()
        pending = Task {
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            update()
        }
    }
}

struct PlaceEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Place" }
    static var defaultQuery: PlaceQuery { PlaceQuery() }
    var id: UUID
    var path: String
    /// With several homes, the home leads: "Mum's house · Hall › Drawer".
    var title: String
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(title)") }
    @MainActor init(_ place: Place, severalHomes: Bool) {
        id = place.id; path = place.path
        title = severalHomes ? place.home.map { "\($0.name) · \(place.path)" } ?? place.path : place.path
    }
}

struct PlaceQuery: EntityStringQuery {
    @MainActor func entities(for identifiers: [UUID]) async throws -> [PlaceEntity] {
        let store = try IntentLibrary.open()
        return store.places.filter { identifiers.contains($0.id) }.map { PlaceEntity($0, severalHomes: store.hasSeveralHomes) }
    }
    @MainActor func entities(matching string: String) async throws -> [PlaceEntity] {
        let needle = string.trimmingCharacters(in: .whitespacesAndNewlines)
        let store = try IntentLibrary.open()
        return store.places
            .filter { needle.isEmpty || $0.path.localizedStandardContains(needle) }
            .sorted { $0.path.count < $1.path.count }
            .prefix(12).map { PlaceEntity($0, severalHomes: store.hasSeveralHomes) }
    }
    @MainActor func suggestedEntities() async throws -> [PlaceEntity] {
        let store = try IntentLibrary.open()
        return store.places.sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }.prefix(20).map { PlaceEntity($0, severalHomes: store.hasSeveralHomes) }
    }
}

// MARK: Intents

struct FindThingIntent: AppIntent {
    static var title: LocalizedStringResource { "Where is it?" }
    static var description: IntentDescription { IntentDescription("Find where you keep a thing in your notebook.") }
    @Parameter(title: "Thing", requestValueDialog: "Which thing?") var thing: ThingEntity

    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = try IntentLibrary.open()
        guard let item = store.items.first(where: { $0.id == thing.id && !$0.isDeleted }) else { throw HereaboutsIntentError.notFound }
        return .result(dialog: IntentDialog(stringLiteral: Self.answer(for: item, severalHomes: store.hasSeveralHomes)))
    }

    @MainActor static func answer(for item: Belonging, severalHomes: Bool = false) -> String {
        if item.isPrivate { return String(localized: "That one's private. Open Hereabouts to see it.") }
        // With several homes, the home leads, as in PlaceEntity.
        let path = item.place.map { place in severalHomes ? place.home.map { "\($0.name) · \(place.path)" } ?? place.path : place.path }
        if item.archived { return path.map { String(localized: "\(item.name) is archived. It was last in \($0).") } ?? String(localized: "\(item.name) is archived.") }
        if item.isMissing { return path.map { String(localized: "\(item.name) is marked missing. It was last in \($0).") } ?? String(localized: "\(item.name) is marked missing.") }
        if item.isLent { return item.lentAt.map { String(localized: "\(item.name) is with \(item.lentTo), since \($0.formatted(.dateTime.day().month(.wide))).") } ?? String(localized: "\(item.name) is with \(item.lentTo).") }
        if let trip = item.packedTrips.first { return path.map { String(localized: "\(item.name) is packed for \(trip.name). You keep it in \($0).") } ?? String(localized: "\(item.name) is packed for \(trip.name).") }
        guard let path else { return String(localized: "You've saved \(item.name), but haven't added a place yet.") }
        return String(localized: "\(item.name) is in \(path).")
    }
}

struct AddThingIntent: AppIntent {
    static var title: LocalizedStringResource { "Write a thing down" }
    static var description: IntentDescription { IntentDescription("Add a thing and its place to your notebook.") }
    @Parameter(title: "Thing", requestValueDialog: "What are you writing down?") var name: String
    @Parameter(title: "Place", requestValueDialog: "Where do you keep it?") var place: PlaceEntity?

    static var parameterSummary: some ParameterSummary { Summary("Write \(\.$name) down in \(\.$place)") }

    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = try IntentLibrary.open()
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw HereaboutsIntentError.emptyName }
        let pro = ProAccess()
        await pro.refresh()
        guard pro.allows(.item, count: store.activeItemCount) else { throw HereaboutsIntentError.freeLimit }
        let chosen = place.flatMap { entity in store.places.first { $0.id == entity.id } }
        let item = try store.addItem(name: name, place: chosen)
        return .result(dialog: IntentDialog(stringLiteral: chosen.map { String(localized: "Written down: \(item.name), in \($0.path).") } ?? String(localized: "Written down: \(item.name). Add a place in Hereabouts when you know it.")))
    }
}

struct FoundThingIntent: AppIntent {
    static var title: LocalizedStringResource { "I found it" }
    static var description: IntentDescription { IntentDescription("Save where you found a thing. Leave the place blank if you found it where you keep it.") }
    @Parameter(title: "Thing", requestValueDialog: "What did you find?") var thing: ThingEntity
    @Parameter(title: "Place", requestValueDialog: "Where was it?") var place: PlaceEntity?

    static var parameterSummary: some ParameterSummary { Summary("Found \(\.$thing) in \(\.$place)") }

    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = try IntentLibrary.open()
        guard let item = store.items.first(where: { $0.id == thing.id && !$0.isDeleted }) else { throw HereaboutsIntentError.notFound }
        let chosen = place.flatMap { entity in store.places.first { $0.id == entity.id } } ?? item.place
        try store.found(item, at: chosen)
        return .result(dialog: IntentDialog(stringLiteral: item.isPrivate ? String(localized: "Noted.") : Movement.foundSentence(chosen)))
    }
}

struct HereaboutsShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: FindThingIntent(), phrases: [
            "Ask \(.applicationName) where something is",
            "Where is \(\.$thing) in \(.applicationName)",
            "Where's \(\.$thing) in \(.applicationName)",
            "Where is my \(\.$thing) in \(.applicationName)",
            "Where's my \(\.$thing) in \(.applicationName)",
            "Find \(\.$thing) in \(.applicationName)",
            "Find my \(\.$thing) in \(.applicationName)",
        ], shortTitle: "Where is it?", systemImageName: "magnifyingglass")
        AppShortcut(intent: AddThingIntent(), phrases: [
            "Write something down in \(.applicationName)",
            "Add a thing to \(.applicationName)",
        ], shortTitle: "Write it down", systemImageName: "square.and.pencil")
        AppShortcut(intent: PutAwayIntent(), phrases: [
            "Put something away in \(.applicationName)",
            "\(.applicationName) put away",
        ], shortTitle: "Put away", systemImageName: "tray.and.arrow.down")
        AppShortcut(intent: FoundThingIntent(), phrases: [
            "Tell \(.applicationName) I found something",
            "I found \(\.$thing) in \(.applicationName)",
        ], shortTitle: "I found it", systemImageName: "sparkle.magnifyingglass")
    }
}
