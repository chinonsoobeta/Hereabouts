import SwiftUI
import CoreData
import CoreSpotlight

@main
struct LocaliserApp: App {
    @State private var store: LocaliserStore?
    /// Created at launch so a notification tapped while the app was closed is not lost.
    @State private var reminders = ReminderService()
    @UIApplicationDelegateAdaptor(HereaboutsAppDelegate.self) private var appDelegate
    private let loadError: String?

    init() {
        do {
            var url: URL?
            #if DEBUG
            let arguments = ProcessInfo.processInfo.arguments
            if let index = arguments.firstIndex(of: "--ui-test-library"), arguments.indices.contains(index + 1), let id = UUID(uuidString: arguments[index + 1]) {
                let directory = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                url = directory.appendingPathComponent("UITests/\(id.uuidString)/Localiser.sqlite")
                UserDefaults.standard.set(true, forKey: OnboardingView.seenKey)
                UserDefaults.standard.removeObject(forKey: Rituals.stocktakeDoneKey)
                UserDefaults.standard.set("2000-01-01", forKey: Rituals.recapReadKey) // An old read week, so the recap is on offer.
                UserDefaults.standard.removeObject(forKey: ItemEditor.lastPlaceKey)
                UserDefaults.standard.removeObject(forKey: Home.nameKey)
                UserDefaults.standard.removeObject(forKey: LocaliserStore.currentHomeKey)
            }
            if arguments.contains("--show-onboarding") { UserDefaults.standard.set(false, forKey: OnboardingView.seenKey) }
            if let index = arguments.firstIndex(of: "--open-ritual"), arguments.indices.contains(index + 1) {
                let service = ReminderService(); service.openedRitual = arguments[index + 1]
                _reminders = State(initialValue: service)
            }
            #endif
            let store = try LocaliserStore(url: url)
            #if DEBUG
            if url != nil, ProcessInfo.processInfo.arguments.contains("--demo-library") { try MainActor.assumeIsolated { try DemoLibrary.seed(store) } }
            if url != nil, ProcessInfo.processInfo.arguments.contains("--second-home") { try MainActor.assumeIsolated { try DemoLibrary.addSecondHome(store) } }
            #endif
            IntentLibrary.store = store
            _store = State(initialValue: store); loadError = nil
        }
        catch { loadError = error.localizedDescription }
        Appearance.apply()
        HereaboutsTips.configure()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let store { RootView().environment(store) }
                else { StoreFailureView(reason: loadError) }
            }
            .environment(reminders)
            .tint(Theme.purple)
            #if DEBUG
            .background { if ProcessInfo.processInfo.arguments.contains("--force-compact") { CompactWindow() } }
            #endif
        }
        .commands { HereaboutsCommands() }
    }
}

#if DEBUG
/// UI tests on an iPad: `--force-compact` gives the window the compact width a third-width Split View window or Slide Over has.
private struct CompactWindow: UIViewRepresentable {
    final class Probe: UIView {
        override func didMoveToWindow() { super.didMoveToWindow(); window?.traitOverrides.horizontalSizeClass = .compact }
    }
    func makeUIView(context: Context) -> Probe { Probe() }
    func updateUIView(_ view: Probe, context: Context) {}
}
#endif

/// Which layout a window gets. Every iPad window, in any Split View, Slide Over or Stage Manager size, and the Duo's inner
/// screen get the sidebar layout while the system says the width is regular, and the iPhone's tabs whenever it is compact.
enum WindowLayout {
    static func isWide(_ horizontal: UserInterfaceSizeClass?) -> Bool { horizontal == .regular }
}

/// What the menu bar and the hardware keyboard do in the window that has focus.
struct WindowShortcuts {
    var newThing: () -> Void
    var search: () -> Void
    var show: (AppTab) -> Void
}

extension FocusedValues {
    @Entry var windowShortcuts: WindowShortcuts?
}

/// New thing (⌘N), search (⌘F) and the four sections (⌘1 to ⌘4), in the iPadOS menu bar and the ⌘-hold overlay.
struct HereaboutsCommands: Commands {
    @FocusedValue(\.windowShortcuts) private var shortcuts

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New thing") { shortcuts?.newThing() }.keyboardShortcut("n")
        }
        CommandMenu("Go") {
            Button("Search") { shortcuts?.search() }.keyboardShortcut("f")
            Divider()
            Button("Find") { shortcuts?.show(.find) }.keyboardShortcut("1")
            Button("Places") { shortcuts?.show(.places) }.keyboardShortcut("2")
            Button("Trips") { shortcuts?.show(.packing) }.keyboardShortcut("3")
            Button("Settings") { shortcuts?.show(.settings) }.keyboardShortcut("4")
        }
    }
}

enum AppTab: Hashable { case find, places, packing, settings }

/// Where the window is. The compact layout shows four tabs; the wide layout also lists each place, trip and kit.
enum Destination: Hashable {
    case find, search, places, place(UUID), trips, trip(UUID), kit(UUID), settings

    /// The tab this destination belongs to, which is all the compact layout can show.
    var tab: AppTab {
        switch self {
        case .find, .search: .find
        case .places, .place: .places
        case .trips, .trip, .kit: .packing
        case .settings: .settings
        }
    }

    /// Picking a tab keeps a place, trip or kit that is already open in it.
    init(tab: AppTab, keeping current: Destination) {
        if current.tab == tab { self = current; return }
        switch tab {
        case .find: self = .find
        case .places: self = .places
        case .packing: self = .trips
        case .settings: self = .settings
        }
    }
}

/// A place or thing pushed on the compact Places tab. The window keeps the path, so a fold can carry it to the wide layout and back.
enum PlaceRoute: Hashable { case place(UUID), item(UUID) }

/// A page pushed in Settings, kept in the window state so a fold doesn't send you back to the list.
enum SettingsPage: Hashable { case pro, homes, leaving, acknowledgements }

/// The sheets a thing opens. They are presented from the root, so they stay open when the layout changes.
enum ItemSheet: Hashable, Identifiable {
    case edit(UUID), move(UUID), moveHome(UUID), lend(UUID), found(UUID)
    var id: Self { self }
    var itemID: UUID {
        switch self { case .edit(let id), .move(let id), .moveHome(let id), .lend(let id), .found(let id): id }
    }
}

/// A trip or kit pushed on the Trips tab. The window keeps the path, so a fold can carry it to the wide layout and back.
enum TripRoute: Hashable { case trip(UUID), kit(UUID) }

/// The place editors, presented from the root so what was typed in them survives a fold.
enum PlaceSheet: Hashable, Identifiable {
    case edit(UUID), addInside(UUID)
    var id: Self { self }
}

/// The trip and kit editors, presented from the root for the same reason.
enum PackingSheet: Hashable, Identifiable {
    case newTrip, newKit, editTrip(UUID), editKit(UUID), tripWithKit(UUID), addToTrip(UUID), addToKit(UUID), editKitEntry(kit: UUID, entry: UUID)
    var id: Self { self }
}

/// What is open in the window, kept above the part of the view tree that swaps between the compact tabs and the
/// wide sidebar. Folding the Duo or resizing an iPad window tears that part down, so nothing here may live inside it.
@MainActor @Observable final class WindowState {
    /// Whether the window is showing the wide layout. Set by the root view.
    var wide = false
    var destination = Destination.find {
        didSet {
            guard wide, destination != oldValue else { return }
            // The wide layout's Settings and place stacks have their paths bound to this state. SwiftUI quits the app if
            // one is taken out of the detail column with a page still pushed, so the page goes in the same change.
            // (The pages stay open across a fold or a resize: neither changes the destination.)
            if oldValue == .settings { settingsPath = [] }
            if oldValue == .trips { tripsPath = [] }
            if case .place(let id) = oldValue { roomPaths[id] = nil }
            forgetLabel()
        }
    }
    /// The thing open beside its place (wide) or over its place's things.
    var selectedItem: UUID?
    /// The thing open on Find.
    var findItem: UUID?
    var query = ""
    var showArchived = false
    var putAway = false
    var newThing: NewThing?
    var speaking = false
    /// What the voice sheet heard, held until the sheet has gone and New thing can open.
    var spoken: NewThing?
    var addingPlace = false
    var ritual: Ritual?
    /// The places and things pushed on the compact Places tab.
    var placesPath: [PlaceRoute] = []
    var settingsPath: [SettingsPage] = []
    /// The trips and kits pushed on the Trips tab, or on the wide Trips list.
    var tripsPath: [TripRoute] = []
    /// The places pushed inside each room on the wide layout.
    var roomPaths: [UUID: [PlaceRoute]] = [:]
    /// The place a box label opened, which leads with putting things in.
    var labelled: UUID?
    var itemSheet: ItemSheet?
    var placeSheet: PlaceSheet?
    var packingSheet: PackingSheet?
    var upgrading = false
    /// "Moved to the shelf" after Found it, shown on the thing it was said about.
    var foundNote: (item: UUID, text: String)?
    /// Whether the wide layout's sidebar is showing. Find draws its own Add a thing bar only when it isn't.
    var sidebar = NavigationSplitViewVisibility.all

    /// Whether a sheet that the window itself presents is open.
    var sheetOpen: Bool { newThing != nil || speaking || addingPlace || ritual != nil || itemSheet != nil || placeSheet != nil || packingSheet != nil || upgrading }

    var tab: AppTab {
        get { destination.tab }
        set { destination = Destination(tab: newValue, keeping: destination) }
    }

    /// Opens a place in the wide layout, with the thing beside it if one is given.
    func reveal(_ place: Place, item: UUID? = nil) {
        let room = place.topLevel.id
        destination = .place(room)
        roomPaths[room] = nil
        selectedItem = item
        labelled = nil
    }

    /// Opens a place inside its room in the wide layout, as the compact Places tab does: the places down to it are pushed.
    func reveal(inside place: Place, fromLabel: Bool) {
        let room = place.topLevel
        destination = .place(room.id)
        var down: [PlaceRoute] = []
        var current: Place? = place
        var seen: Set<UUID> = []
        while let here = current, here.id != room.id, seen.insert(here.id).inserted { down.append(.place(here.id)); current = here.parent }
        roomPaths[room.id] = down.isEmpty ? nil : down.reversed()
        selectedItem = nil
        labelled = fromLabel ? place.id : nil
    }

    /// A thing opened from a link, Spotlight, a reminder or the widget. On the compact layout Find takes it. On the wide
    /// layout a thing with a place in this home opens beside that place, and any other opens in Find, where it is.
    func openThing(_ id: UUID, wide: Bool, in store: LocaliserStore) {
        guard wide, let item = store.items.first(where: { $0.id == id }) else { tab = .find; return }
        if let place = item.place, store.placesHere.contains(place) { reveal(place, item: id) }
        else { destination = .find; findItem = id }
        store.openedItem = nil
    }

    /// A place opened from a link or a box label. On the compact layout the Places tab takes it. On the wide layout it opens
    /// inside its room, in that place's home: the window moves to it if it is another home's.
    func openPlace(_ id: UUID, wide: Bool, in store: LocaliserStore) {
        guard wide, let place = store.places.first(where: { $0.id == id }) else { tab = .places; store.openedPlace = id; return }
        if let home = place.home, home != store.currentHome { store.switchHome(to: home) }
        reveal(inside: place, fromLabel: true)
    }

    /// The compact Places stack for what the wide layout has open: the room, the places pushed in it, the places down to the thing, then the thing.
    func routes(in store: LocaliserStore) -> [PlaceRoute] {
        guard case .place(let id) = destination else { return [] }
        var routes: [PlaceRoute] = [.place(id)] + roomPaths[id, default: []]
        if let picked = selectedItem, let item = store.items.first(where: { $0.id == picked }) {
            var inside: [PlaceRoute] = []
            var current = item.place
            var seen: Set<UUID> = []
            // Walk up from the thing's place to the nearest place that is already on the stack.
            while let here = current, !routes.contains(.place(here.id)), seen.insert(here.id).inserted { inside.append(.place(here.id)); current = here.parent }
            if let here = current, let index = routes.firstIndex(of: .place(here.id)) {
                routes.removeSubrange((index + 1)...)
                routes += inside.reversed()
            }
            routes.append(.item(picked))
        }
        return routes
    }

    /// Makes what the compact Places stack has open the wide layout's room, places and thing.
    func adopt(_ routes: [PlaceRoute], in store: LocaliserStore) {
        let thing: UUID? = if case .item(let id)? = routes.last { id } else { nil }
        let deepest = routes.reversed().lazy.compactMap { route -> Place? in
            guard case .place(let id) = route else { return nil }
            return store.places.first { $0.id == id }
        }.first
        if let deepest {
            let kept = labelled
            reveal(inside: deepest, fromLabel: false)
            labelled = kept
            selectedItem = thing
        } else if let thing, let item = store.items.first(where: { $0.id == thing }) {
            // A thing opened on its own, from Lent out: beside its place if this home has it, otherwise in Find.
            if let place = item.place, store.placesHere.contains(place) { reveal(place, item: thing) }
            else { destination = .find; findItem = thing }
        } else if destination.tab == .places {
            destination = .places; selectedItem = nil
        }
    }

    /// The compact Trips stack for what the wide layout has open: the trip or kit the sidebar picked, or what the Trips list pushed.
    func tripRoutes() -> [TripRoute] {
        switch destination {
        case .trip(let id): [.trip(id)]
        case .kit(let id): [.kit(id)]
        case .trips: tripsPath
        default: []
        }
    }

    /// Makes the trip or kit the compact Trips stack has open the wide layout's pick. The wide Trips list keeps no copy of the path.
    func adoptTrips(_ routes: [TripRoute], in store: LocaliserStore) {
        switch routes.last {
        case .trip(let id)?: destination = .trip(id); tripsPath = []
        case .kit(let id)?: destination = .kit(id); tripsPath = []
        case nil: if destination.tab == .packing { destination = .trips }
        }
    }

    /// The label's "Put things in this box" goes when the box it was for is no longer open.
    func forgetLabel() {
        guard let id = labelled else { return }
        let open: Bool
        if wide {
            guard case .place(let room) = destination else { labelled = nil; return }
            open = room == id || roomPaths[room, default: []].contains(.place(id))
        } else {
            open = placesPath.contains(.place(id))
        }
        if !open { labelled = nil }
    }

    /// Forgets what has been deleted or no longer belongs where it was picked.
    func dropStaleSelection(in store: LocaliserStore) {
        let here = Set(store.placesHere.map(\.id))
        switch destination {
        case .place(let id) where !here.contains(id): destination = .find
        case .trip(let id) where !store.tripsHere.contains { $0.id == id }: destination = .trips
        case .kit(let id) where !store.kitsHere.contains { $0.id == id }: destination = .trips
        default: break
        }
        if let id = selectedItem {
            if let item = store.items.first(where: { $0.id == id }), !item.isDeleted, store.itemsHere.contains(item) {
                if case .place(let placeID) = destination, item.place?.topLevel.id != placeID { selectedItem = nil }
            } else { selectedItem = nil }
        }
        if let id = findItem, !store.items.contains(where: { $0.id == id }) { findItem = nil }
        // A place stays only while it is in the current home. A thing on its own (from Lent out) may be from any home.
        let gone = placesPath.firstIndex { route in
            switch route {
            case .place(let id): !here.contains(id)
            case .item(let id): !store.items.contains { $0.id == id && !$0.isDeleted }
            }
        }
        if let gone { placesPath.removeSubrange(gone...) }
        for (room, path) in roomPaths {
            if !here.contains(room) { roomPaths[room] = nil; continue }
            if let index = path.firstIndex(where: { if case .place(let id) = $0 { !here.contains(id) } else { true } }) { roomPaths[room] = index == 0 ? nil : Array(path[..<index]) }
        }
        if let id = labelled, !here.contains(id) { labelled = nil }
        let kits = Set(store.kitsHere.map(\.id)), trips = Set(store.tripsHere.map(\.id))
        if let gone = tripsPath.firstIndex(where: { route in
            switch route { case .trip(let id): !trips.contains(id); case .kit(let id): !kits.contains(id) }
        }) { tripsPath.removeSubrange(gone...) }
        if let sheet = itemSheet, !store.items.contains(where: { $0.id == sheet.itemID }) { itemSheet = nil }
        // An editor stays only while what it edits is still there.
        if let sheet = placeSheet {
            switch sheet {
            case .edit(let id), .addInside(let id): if !store.places.contains(where: { $0.id == id }) { placeSheet = nil }
            }
        }
        switch packingSheet {
        case .editTrip(let id), .addToTrip(let id): if !trips.contains(id) { packingSheet = nil }
        case .editKit(let id), .tripWithKit(let id), .addToKit(let id), .editKitEntry(let id, _): if !kits.contains(id) { packingSheet = nil }
        default: break
        }
    }
}

struct RootView: View {
    @Environment(LocaliserStore.self) private var store
    @Environment(ReminderService.self) private var reminders
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.dynamicTypeSize) private var textSize
    @State private var pro = ProAccess()
    @State private var ui = WindowState()
    @AppStorage(OnboardingView.seenKey) private var seenOnboarding = false
    @State private var dropTarget: UUID?
    private var wide: Bool { WindowLayout.isWide(sizeClass) }

    var body: some View {
        @Bindable var ui = ui
        Group {
            if wide { wideLayout } else { compactTabs }
        }
        .tint(Theme.purpleInk)
        .tipViewStyle(NotebookTipStyle())
        .tipBackground(Theme.lilacPaper)
        .overlay(alignment: .bottom) { UndoDeletionToast() }
        .fullScreenCover(isPresented: Binding(get: { !seenOnboarding }, set: { if !$0 { seenOnboarding = true } })) {
            OnboardingView { seenOnboarding = true }.environment(pro)
        }
        // These sheets are presented from here, above the layouts, so they stay open when the layout changes.
        .sheet(item: $ui.newThing) { new in NavigationStack { ItemEditor(place: store.places.first { $0.id == new.placeID }, name: new.name, photoFirst: new.photoFirst, spokenPlace: new.spokenPlace) } }
        .sheet(isPresented: $ui.speaking, onDismiss: { if let spoken = ui.spoken { ui.newThing = spoken; ui.spoken = nil } }) { NavigationStack { VoiceSheet { ui.spoken = $0 } } }
        .sheet(isPresented: $ui.addingPlace) { NavigationStack { PlaceEditor() } }
        .sheet(item: $ui.itemSheet) { sheet in
            NavigationStack { ItemSheetView(sheet: sheet) }
        }
        .sheet(item: $ui.placeSheet) { sheet in NavigationStack { placeEditor(sheet) } }
        .sheet(item: $ui.packingSheet) { sheet in NavigationStack { packingEditor(sheet) } }
        .sheet(isPresented: $ui.upgrading) { NavigationStack { ProView() } }
        .sheet(item: $ui.ritual) { ritual in
            NavigationStack {
                switch ritual {
                case .recap: RecapView(startStocktake: { Task { @MainActor in ui.ritual = .stocktake } })
                case .stocktake: StocktakeView()
                }
            }
        }
        .task { await pro.observeTransactions() }
        .task { await pro.refresh(); await backUpIfDue() }
        .onChange(of: store.revision, initial: true) { _, _ in reminders.store = store; reminders.refresh(store.deadlines); reminders.refreshRituals(store); Spotlight.index(store); ui.dropStaleSelection(in: store) }
        .onChange(of: reminders.openedRitual) { _, ritual in
            switch ritual {
            case "trip": ui.tab = .packing; reminders.openedRitual = nil
            case .some: ui.tab = .find
            case nil: break
            }
        }
        .onChange(of: store.openedItem) { _, id in
            guard let id else { return }
            ui.openThing(id, wide: wide, in: store)
        }
        .onChange(of: ui.destination) { _, destination in
            if destination == .search { ui.destination = .find; store.findRequest = .find }
            // A different place starts with nothing picked.
            if case .place(let id) = destination, let picked = ui.selectedItem, store.items.first(where: { $0.id == picked })?.place?.topLevel.id != id { ui.selectedItem = nil }
        }
        .onChange(of: wide, initial: true) { _, nowWide in ui.wide = nowWide }
        .onChange(of: ui.placesPath) { _, _ in ui.forgetLabel() }
        .onChange(of: wide) { _, nowWide in
            // A place, thing, trip or kit open on one layout is open on the other.
            switch ui.destination.tab {
            case .places: if nowWide { ui.adopt(ui.placesPath, in: store) } else { ui.placesPath = ui.routes(in: store) }
            case .packing: if nowWide { ui.adoptTrips(ui.tripsPath, in: store) } else { ui.tripsPath = ui.tripRoutes() }
            default: break
            }
        }
        .onChange(of: seenOnboarding) { _, seen in if !seen { ui.tab = .find } }
        .onContinueUserActivity(CSSearchableItemActionType) { activity in
            if let raw = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String { store.openedItem = UUID(uuidString: raw) }
        }
        .onOpenURL { url in
            #if DEBUG
            // UI tests don't know the demo library's ids: hereabouts://demo/item/Cordless%20drill finds the thing by its name.
            if let link = DemoLibrary.link(for: url, in: store) { open(link); return }
            #endif
            if let link = AppLink(url: url) { open(link) }
        }
        .onChange(of: QuickActions.shared.link, initial: true) { _, link in
            guard let link else { return }
            open(link)
            QuickActions.shared.link = nil
        }
        .onChange(of: scenePhase) { _, value in
            if value == .active { store.catchUp(); Task { await pro.refresh(); await backUpIfDue() } }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            // Midnight or a time-zone change: regroup the dates and requeue reminders (the revision change does both).
            store.catchUp()
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange).receive(on: RunLoop.main)) { _ in
            store.catchUp(mergingOutside: true)
        }
        // Last, so the sheets and the cover above are inside it and see these too.
        .environment(pro)
        .environment(self.ui)
        .focusedSceneValue(\.windowShortcuts, shortcuts)
    }

    /// The keyboard shortcuts do nothing while anything is presented over the window: one of its own sheets, the
    /// introduction, or a sheet, alert or cover that a screen presents for itself.
    private var shortcuts: WindowShortcuts {
        func allowed() -> Bool { seenOnboarding && !ui.sheetOpen && !Self.somethingIsPresented() }
        return WindowShortcuts(
            newThing: { if allowed() { ui.newThing = NewThing() } },
            search: { if allowed() { open(.find) } },
            show: { tab in if allowed() { ui.tab = tab } })
    }

    /// Whether UIKit has a sheet, alert or cover up in the active window. A search that is open is not one: it is how
    /// the search field is shown, and the shortcuts still work while someone is searching.
    static func somethingIsPresented() -> Bool {
        func presenting(_ controller: UIViewController) -> Bool {
            if let shown = controller.presentedViewController, !(shown is UISearchController) { return true }
            return controller.children.contains(where: presenting)
        }
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first { $0.activationState == .foregroundActive }
        return scene?.keyWindow?.rootViewController.map(presenting) ?? false
    }

    /// Four tabs: every iPhone, and the Duo's outer screen.
    private var compactTabs: some View {
        @Bindable var ui = ui
        return TabView(selection: $ui.tab) {
            Tab(value: AppTab.find) { NavigationStack { FindView() } } label: { Label("Find", systemImage: "magnifyingglass").environment(\.symbolVariants, .none) }
            Tab(value: AppTab.places) { placesStack } label: { Label("Places", systemImage: "shippingbox").environment(\.symbolVariants, .none) }
            Tab(value: AppTab.packing) { tripsStack } label: { Label("Trips", systemImage: "suitcase").environment(\.symbolVariants, .none) }
            Tab(value: AppTab.settings) { NavigationStack(path: $ui.settingsPath) { LibrarySettingsView() } } label: { Label("Settings", systemImage: "gear").environment(\.symbolVariants, .none) }
                .badge(reminders.coverageGap || store.isStale ? Text("!") : nil)
        }
    }

    /// The Trips list with the trips and kits it pushes, with its path kept in the window state. Both layouts use it.
    private var tripsStack: some View {
        @Bindable var ui = ui
        return NavigationStack(path: $ui.tripsPath) {
            PackingView()
                .navigationDestination(for: TripRoute.self) { route in
                    switch route {
                    case .trip(let id): if let trip = store.trips.first(where: { $0.id == id }) { TripDetailView(trip: trip) }
                    case .kit(let id): if let kit = store.kits.first(where: { $0.id == id }) { KitDetailView(kit: kit) }
                    }
                }
        }
    }

    @ViewBuilder private func placeEditor(_ sheet: PlaceSheet) -> some View {
        switch sheet {
        case .edit(let id): if let place = store.places.first(where: { $0.id == id }) { PlaceEditor(place: place) }
        case .addInside(let id): if let parent = store.places.first(where: { $0.id == id }) { PlaceEditor(parent: parent) }
        }
    }

    @ViewBuilder private func packingEditor(_ sheet: PackingSheet) -> some View {
        switch sheet {
        case .newTrip: TripEditor()
        case .newKit: KitEditor()
        case .editTrip(let id): if let trip = store.trips.first(where: { $0.id == id }) { TripEditor(trip: trip) }
        case .editKit(let id): if let kit = store.kits.first(where: { $0.id == id }) { KitEditor(kit: kit) }
        case .tripWithKit(let id): if let kit = store.kits.first(where: { $0.id == id }) { TripEditor(kit: kit) }
        case .addToTrip(let id): if let trip = store.trips.first(where: { $0.id == id }) { TripEntryAdder(trip: trip) }
        case .addToKit(let id): if let kit = store.kits.first(where: { $0.id == id }) { KitEntryEditor(kit: kit) }
        case .editKitEntry(let id, let entry):
            if let kit = store.kits.first(where: { $0.id == id }), let found = kit.entries.first(where: { $0.id == entry }) { KitEntryEditor(kit: kit, entry: found) }
        }
    }

    /// The compact Places stack, with its path kept in the window state.
    private var placesStack: some View {
        @Bindable var ui = ui
        return NavigationStack(path: $ui.placesPath) {
            PlacesView()
                .navigationDestination(for: PlaceRoute.self) { route in
                    switch route {
                    case .place(let id): if let place = store.places.first(where: { $0.id == id }) { PlaceDetailView(place: place, fromLabel: ui.labelled == id) }
                    case .item(let id): if let item = store.items.first(where: { $0.id == id }) { ItemDetailView(item: item) }
                    }
                }
        }
        .environment(\.pushesRoutes, true)
    }

    /// A lilac sidebar beside the content: the Duo's inner screen and every iPad.
    private var wideLayout: some View {
        @Bindable var ui = ui
        let _ = store.revision
        return NavigationSplitView(columnVisibility: $ui.sidebar) {
            sidebar
                .navigationSplitViewColumnWidth(min: 260, ideal: textSize.isAccessibilitySize ? 400 : 300, max: textSize.isAccessibilitySize ? 440 : 340)
        } detail: {
            wideDetail
        }
        .navigationSplitViewStyle(.balanced)
    }

    private func row(_ destination: Destination, _ title: String, _ symbol: String, count: Int? = nil) -> some View {
        HStack {
            Label(title, systemImage: symbol).environment(\.symbolVariants, .none)
            if let count { Spacer(minLength: 8); Text("\(count)").foregroundStyle(Theme.secondary) }
        }
        .tag(destination)
        .listRowBackground(ui.destination == destination || isDropTarget(destination) ? Theme.highlighter : Color.clear)
    }

    private func isDropTarget(_ destination: Destination) -> Bool {
        if case .place(let id) = destination { return dropTarget == id }
        return false
    }

    /// A place in the sidebar takes the things dropped on it and moves them there, as the Move sheet would.
    private func placeRow(_ place: Place) -> some View {
        row(.place(place.id), place.name, PlaceTile.symbol(for: place.name), count: place.activeItemCount)
            .dropDestination(for: ThingDrag.self) { drops, _ in
                do { return try store.moveDropped(drops.map(\.id), to: place) > 0 }
                catch { return false }
            } isTargeted: { over in
                if over { dropTarget = place.id } else if dropTarget == place.id { dropTarget = nil }
            }
    }

    private var sidebar: some View {
        let places = store.placesHere.filter { $0.parent == nil }
        let trips = store.tripsHere.filter { [.packing, .away, .comingHome].contains($0.state) }.sorted { $0.startDay < $1.startDay }
        return List(selection: Binding(get: { ui.destination }, set: { if let destination = $0 { ui.destination = destination } })) {
            row(.search, String(localized: "Search"), "magnifyingglass")
            row(.find, String(localized: "Find"), "house")
            row(.trips, String(localized: "Trips"), "suitcase")
            row(.settings, String(localized: "Settings"), "gear")
            Section("Places") {
                row(.places, String(localized: "All places"), "shippingbox")
                ForEach(places) { place in placeRow(place) }
            }
            if !trips.isEmpty {
                Section("Coming up") { ForEach(trips) { trip in row(.trip(trip.id), trip.name, "suitcase") } }
            }
            if !store.kitsHere.isEmpty {
                Section("Kits") { ForEach(store.kitsHere) { kit in row(.kit(kit.id), kit.name, "checklist") } }
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(Theme.lilacPaper)
        // The bar stays for the sidebar toggle, which sits in it; it has no title and no background of its own.
        .navigationBarTitleDisplayMode(.inline).toolbarBackgroundVisibility(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text(store.currentHome?.name ?? Home.defaultName).font(.wbTitle).foregroundStyle(Theme.ink)
                Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide))).font(.wbCaption).foregroundStyle(Theme.pencil)
            }
            .accessibilityElement(children: .combine)
            .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 20).padding(.vertical, 12)
            .background(Theme.lilacPaper)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Button { ui.newThing = NewThing() } label: { Label("Add a thing", systemImage: "plus").fixedSize(horizontal: false, vertical: true) }
                .buttonStyle(PrimaryButtonStyle()).padding(12)
                .background(Theme.lilacPaper)
        }
    }

    @ViewBuilder private var wideDetail: some View {
        @Bindable var ui = ui
        switch ui.destination {
        case .find, .search: NavigationStack { FindView() }
        case .places: NavigationStack { PlacesView() }
        case .place(let id):
            if let place = store.placesHere.first(where: { $0.id == id }) { WidePlaceView(place: place).id(id) }
            else { NavigationStack { FindView() } }
        case .trips: tripsStack
        case .trip(let id):
            if let trip = store.tripsHere.first(where: { $0.id == id }) { NavigationStack { TripDetailView(trip: trip) }.id(id) }
            else { NavigationStack { PackingView() } }
        case .kit(let id):
            if let kit = store.kitsHere.first(where: { $0.id == id }) { NavigationStack { KitDetailView(kit: kit) }.id(id) }
            else { NavigationStack { PackingView() } }
        case .settings: NavigationStack(path: $ui.settingsPath) { LibrarySettingsView() }
        }
    }
}

extension TabContent {
    /// The sidebar opens its sections on iOS 27; earlier systems keep their own default.
    @TabContentBuilder<TabValue> func expandedByDefault() -> some TabContent<TabValue> {
        if #available(iOS 27, *) { defaultSectionExpansion(.expanded) } else { self }
    }
}

/// A place's things, with the thing you pick opening in the column beside when the screen is wide enough
/// and sliding over the things when it isn't.
struct WidePlaceView: View {
    @Environment(LocaliserStore.self) private var store
    @Environment(WindowState.self) private var ui
    let place: Place
    /// The things column keeps this width when a third column fits.
    static let thingsWidth: CGFloat = 410
    static let splitWidth: CGFloat = 760

    private var selected: Belonging? { ui.selectedItem.flatMap { id in store.items.first { $0.id == id } } }

    var body: some View {
        GeometryReader { geometry in
            let split = geometry.size.width >= Self.splitWidth
            HStack(spacing: 0) {
                NavigationStack(path: Binding(get: { ui.roomPaths[place.id, default: []] }, set: { ui.roomPaths[place.id] = $0.isEmpty ? nil : $0 })) {
                    PlaceDetailView(place: place, fromLabel: ui.labelled == place.id)
                        .navigationDestination(for: PlaceRoute.self) { route in
                            // The places pushed inside this one. A thing is never pushed by value here: it opens beside.
                            if case .place(let id) = route, let inside = store.places.first(where: { $0.id == id }) { PlaceDetailView(place: inside, fromLabel: ui.labelled == id) }
                        }
                        .navigationDestination(item: Binding(get: { split ? nil : selected }, set: { if !split { ui.selectedItem = $0?.id } })) { ItemDetailView(item: $0) }
                }
                .environment(\.pushesRoutes, true)
                .frame(minWidth: split ? Self.thingsWidth : 0, maxWidth: split ? Self.thingsWidth : .infinity)
                if split {
                    Divider()
                    detail.frame(maxWidth: .infinity)
                }
            }
        }
        .environment(\.picksThingsBeside, true)
    }

    @ViewBuilder private var detail: some View {
        if let selected {
            NavigationStack { ItemDetailView(item: selected) }.id(selected.id)
        } else {
            LibraryEmptyState(title: String(localized: "Pick a thing"), systemImage: "shippingbox", description: String(localized: "It opens here."))
                .frame(maxWidth: .infinity, maxHeight: .infinity).background(Theme.ground)
        }
    }
}

extension RootView {
    /// Pro's weekly backup, when a week has passed. It runs when the app opens.
    func backUpIfDue() async {
        guard pro.unlocked else { return }
        _ = await AutomaticBackups(folder: await AutomaticBackups.resolveFolder(), isPro: pro.unlocked).runIfDue(store: store)
    }

    func open(_ link: AppLink) {
        switch link {
        case .item(let id): store.openedItem = id
        case .place(let id):
            ui.openPlace(id, wide: wide, in: store)
        case .find, .new, .putAway, .say: ui.tab = .find; store.findRequest = link
        }
    }
}

/// Shown when the library file cannot be opened. Offers the raw file so nothing is lost.
struct StoreFailureView: View {
    let reason: String?
    private var files: [URL] {
        guard let legacy = try? LocaliserStore.defaultStoreURL() else { return [] }
        let base = NotebookFile.groupStoreURL().flatMap { FileManager.default.fileExists(atPath: $0.path) ? $0 : nil } ?? legacy
        return ["", "-wal", "-shm"].map { URL(fileURLWithPath: base.path + $0) }.filter { FileManager.default.fileExists(atPath: $0.path) }
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Image(systemName: "externaldrive.badge.exclamationmark").font(.system(size: 44)).foregroundStyle(Theme.purple).accessibilityHidden(true)
                    Text("Hereabouts couldn't open your notebook").font(.wbTitle).foregroundStyle(Theme.ink)
                    Text("Nothing has been deleted. Try restarting your iPhone. If you still need help, save your notebook file and send it to support.").font(.wbBody).foregroundStyle(Theme.secondary)
                    if let reason { Text(reason).font(.wbCaption).foregroundStyle(Theme.secondary).textSelection(.enabled) }
                    if !files.isEmpty {
                        ShareLink(items: files) { Label("Save the notebook file (photos stay on this iPhone)", systemImage: "square.and.arrow.up") }.buttonStyle(PrimaryButtonStyle())
                    }
                    Link(destination: Support.mail(subject: "Notebook won't open", body: reason ?? "")) { Label("Contact support", systemImage: "envelope") }.buttonStyle(SoftButtonStyle())
                }
                .padding(20)
            }
            .groundBackground()
        }
    }
}

struct LibraryEmptyState: View {
    let title: String
    let systemImage: String
    let description: String
    var body: some View {
        ContentUnavailableView {
            Label {
                Text(title).fixedSize(horizontal: false, vertical: true).multilineTextAlignment(.center)
            } icon: {
                Image(systemName: systemImage).foregroundStyle(Theme.purpleInk).accessibilityHidden(true)
            }
        } description: {
            Text(description).foregroundStyle(Theme.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
}
