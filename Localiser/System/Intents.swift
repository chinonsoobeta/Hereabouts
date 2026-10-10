import AppIntents
import Foundation

/// Siri, Shortcuts, Spotlight actions and the Action button all reach the notebook through these.
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
        case .notFound: "That thing isn't in the notebook any more."
        case .freeLimit: "The free notebook holds \(CreationKind.item.freeLimit) things. Open Hereabouts to get Pro, or archive something first."
        case .emptyName: "A thing needs a name."
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
    @MainActor init(_ item: Belonging) { self.init(id: item.id, name: item.name, path: item.place?.path ?? "") }
}

struct ThingQuery: EntityStringQuery {
    @MainActor func entities(for identifiers: [UUID]) async throws -> [ThingEntity] {
        let store = try IntentLibrary.open()
        return store.items.filter { identifiers.contains($0.id) && !$0.isDeleted }.map(ThingEntity.init)
    }
    @MainActor func entities(matching string: String) async throws -> [ThingEntity] {
        let store = try IntentLibrary.open()
        return ItemSearch.results(query: string, entries: store.searchIndex, archived: false).prefix(12).map(ThingEntity.init)
    }
    @MainActor func suggestedEntities() async throws -> [ThingEntity] {
        let store = try IntentLibrary.open()
        return store.items.filter { !$0.archived && !$0.isDeleted }.sorted { $0.lastConfirmed > $1.lastConfirmed }.prefix(12).map(ThingEntity.init)
    }
}

struct PlaceEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Place" }
    static var defaultQuery: PlaceQuery { PlaceQuery() }
    var id: UUID
    var path: String
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(path)") }
}

struct PlaceQuery: EntityStringQuery {
    @MainActor func entities(for identifiers: [UUID]) async throws -> [PlaceEntity] {
        try IntentLibrary.open().places.filter { identifiers.contains($0.id) }.map { PlaceEntity(id: $0.id, path: $0.path) }
    }
    @MainActor func entities(matching string: String) async throws -> [PlaceEntity] {
        let needle = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return try IntentLibrary.open().places
            .filter { needle.isEmpty || $0.path.localizedStandardContains(needle) }
            .sorted { $0.path.count < $1.path.count }
            .prefix(12).map { PlaceEntity(id: $0.id, path: $0.path) }
    }
    @MainActor func suggestedEntities() async throws -> [PlaceEntity] {
        try IntentLibrary.open().places.sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }.prefix(20).map { PlaceEntity(id: $0.id, path: $0.path) }
    }
}

// MARK: Intents

struct FindThingIntent: AppIntent {
    static var title: LocalizedStringResource { "Where is it?" }
    static var description: IntentDescription { IntentDescription("Says where a thing lives, from your notebook.") }
    @Parameter(title: "Thing", requestValueDialog: "Which thing?") var thing: ThingEntity

    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = try IntentLibrary.open()
        guard let item = store.items.first(where: { $0.id == thing.id && !$0.isDeleted }) else { throw HereaboutsIntentError.notFound }
        return .result(dialog: IntentDialog(stringLiteral: Self.answer(for: item)))
    }

    @MainActor static func answer(for item: Belonging) -> String {
        let path = item.place?.path
        if item.archived { return path.map { "\(item.name) is archived. It was last in \($0)." } ?? "\(item.name) is archived." }
        if let trip = item.packedTrips.first { return path.map { "\(item.name) is packed for \(trip.name). It lives in \($0)." } ?? "\(item.name) is packed for \(trip.name)." }
        guard let path else { return "\(item.name) is written down, but without a place yet." }
        return "\(item.name) is in \(path)."
    }
}

struct AddThingIntent: AppIntent {
    static var title: LocalizedStringResource { "Write a thing down" }
    static var description: IntentDescription { IntentDescription("Adds a thing to the notebook, and where it lives.") }
    @Parameter(title: "Thing", requestValueDialog: "What are you writing down?") var name: String
    @Parameter(title: "Place", requestValueDialog: "Where does it live?") var place: PlaceEntity?

    static var parameterSummary: some ParameterSummary { Summary("Write \(\.$name) down in \(\.$place)") }

    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = try IntentLibrary.open()
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw HereaboutsIntentError.emptyName }
        let pro = ProAccess()
        await pro.refresh()
        guard pro.allows(.item, count: store.activeItemCount) else { throw HereaboutsIntentError.freeLimit }
        let chosen = place.flatMap { entity in store.places.first { $0.id == entity.id } }
        let item = try store.addItem(name: name, place: chosen)
        return .result(dialog: IntentDialog(stringLiteral: chosen.map { "Written down: \(item.name), in \($0.path)." } ?? "Written down: \(item.name). Add a place in Hereabouts when you know it."))
    }
}

struct WhatsDueIntent: AppIntent {
    static var title: LocalizedStringResource { "What's due?" }
    static var description: IntentDescription { IntentDescription("Reads the next return, warranty and expiry dates.") }

    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = try IntentLibrary.open()
        return .result(dialog: IntentDialog(stringLiteral: Self.answer(for: store.deadlines)))
    }

    /// The next month of dates, as Siri says them: "Kettle: warranty ends tomorrow."
    @MainActor static func answer(for deadlines: [Deadline], today: CalendarDay = CalendarDay(.now)) -> String {
        guard let horizon = today.adding(days: 30) else { return "Nothing is due in the next month." }
        let due = deadlines.filter { $0.active && ($0.day.map { $0 >= today && $0 <= horizon } ?? false) }.sorted { $0.dayString < $1.dayString }
        guard !due.isEmpty else { return "Nothing is due in the next month." }
        let lines = due.prefix(3).map { deadline -> String in
            let name = deadline.item?.name ?? "A saved thing"
            let day = deadline.day?.spoken(today: today) ?? ""
            switch deadline.kind {
            case .returns: return "\(name): last day to return is \(day)"
            case .warranty: return "\(name): warranty ends \(day)"
            case .expiry: return "\(name): expires \(day)"
            case nil: return "\(name): \(day)"
            }
        }
        let more = due.count > 3 ? " And \(due.count - 3) more in the app." : ""
        return lines.joined(separator: ". ") + "." + more
    }
}

extension CalendarDay {
    /// A date to be read aloud: "today", "tomorrow", "Sunday 11 October".
    func spoken(today: CalendarDay = CalendarDay(.now)) -> String {
        if self == today { return "today" }
        if today.adding(days: 1) == self { return "tomorrow" }
        guard let date = date() else { return stored }
        return date.isThisYear ? date.formatted(.dateTime.weekday(.wide).day().month(.wide)) : date.formatted(.dateTime.day().month(.wide).year())
    }
}

struct HereaboutsShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: FindThingIntent(), phrases: [
            "Where is \(\.$thing) in \(.applicationName)",
            "Find \(\.$thing) in \(.applicationName)",
            "Ask \(.applicationName) where something is",
        ], shortTitle: "Where is it?", systemImageName: "magnifyingglass")
        AppShortcut(intent: AddThingIntent(), phrases: [
            "Write something down in \(.applicationName)",
            "Add a thing to \(.applicationName)",
        ], shortTitle: "Write it down", systemImageName: "square.and.pencil")
        AppShortcut(intent: WhatsDueIntent(), phrases: [
            "What's due in \(.applicationName)",
            "Ask \(.applicationName) what's due",
        ], shortTitle: "What's due", systemImageName: "calendar")
    }
}
