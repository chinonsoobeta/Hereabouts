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

/// What is open in the window, kept above the part of the view tree that swaps between the compact tabs and the
/// wide sidebar. Folding the Duo or resizing an iPad window tears that part down, so nothing here may live inside it.
@MainActor @Observable final class WindowState {
    var destination = Destination.find
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
    var itemSheet: ItemSheet?
    var upgrading = false
    /// "Moved to the shelf" after Found it, shown on the thing it was said about.
    var foundNote: (item: UUID, text: String)?
    /// Whether the wide layout's sidebar is showing. Find draws its own Add a thing bar only when it isn't.
    var sidebar = NavigationSplitViewVisibility.all

    /// Whether a sheet that the window itself presents is open.
    var sheetOpen: Bool { newThing != nil || speaking || addingPlace || ritual != nil || itemSheet != nil || upgrading }

    var tab: AppTab {
        get { destination.tab }
        set { destination = Destination(tab: newValue, keeping: destination) }
    }

    /// Opens a place in the wide layout, with the thing beside it if one is given.
    func reveal(_ place: Place, item: UUID? = nil) {
        destination = .place(place.topLevel.id)
        selectedItem = item
    }

    /// The compact Places stack for what the wide layout has open: the room, the places down to the thing, then the thing.
    func routes(in store: LocaliserStore) -> [PlaceRoute] {
        guard case .place(let id) = destination else { return [] }
        var routes: [PlaceRoute] = [.place(id)]
        if let picked = selectedItem, let item = store.items.first(where: { $0.id == picked }), let place = item.place {
            var inside: [PlaceRoute] = []
            var current: Place? = place
            var seen: Set<UUID> = []
            while let here = current, here.id != id, seen.insert(here.id).inserted { inside.append(.place(here.id)); current = here.parent }
            routes += inside.reversed()
            routes.append(.item(picked))
        }
        return routes
    }

    /// Makes what the compact Places stack has open the wide layout's room and thing.
    func adopt(_ routes: [PlaceRoute], in store: LocaliserStore) {
        guard case .place(let first)? = routes.first, let place = store.places.first(where: { $0.id == first }) else {
            if destination.tab == .places { destination = .places; selectedItem = nil }
            return
        }
        destination = .place(place.topLevel.id)
        if case .item(let id)? = routes.last { selectedItem = id } else { selectedItem = nil }
    }

    /// Forgets what has been deleted or no longer belongs where it was picked.
    func dropStaleSelection(in store: LocaliserStore) {
        switch destination {
        case .place(let id) where !store.placesHere.contains { $0.id == id }: destination = .find
        case .trip(let id) where !store.tripsHere.contains { $0.id == id }: destination = .trips
        case .kit(let id) where !store.kitsHere.contains { $0.id == id }: destination = .trips
        default: break
        }
        if let id = selectedItem {
            if let item = store.items.first(where: { $0.id == id }), !item.isDeleted {
                if case .place(let placeID) = destination, item.place?.topLevel.id != placeID { selectedItem = nil }
            } else { selectedItem = nil }
        }
        if let id = findItem, !store.items.contains(where: { $0.id == id }) { findItem = nil }
        let gone = placesPath.firstIndex { route in
            switch route {
            case .place(let id): !store.places.contains { $0.id == id }
            case .item(let id): !store.items.contains { $0.id == id && !$0.isDeleted }
            }
        }
        if let gone { placesPath.removeSubrange(gone...) }
        if let sheet = itemSheet, !store.items.contains(where: { $0.id == sheet.itemID }) { itemSheet = nil }
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
            // On a wide screen a thing with a place opens beside that place.
            if wide, let item = store.items.first(where: { $0.id == id }), let place = item.place {
                ui.reveal(place, item: id); store.openedItem = nil
            } else { ui.tab = .find }
        }
        .onChange(of: ui.destination) { _, destination in
            if destination == .search { ui.destination = .find; store.findRequest = .find }
            // A different place starts with nothing picked.
            if case .place(let id) = destination, let picked = ui.selectedItem, store.items.first(where: { $0.id == picked })?.place?.topLevel.id != id { ui.selectedItem = nil }
        }
        .onChange(of: wide) { _, nowWide in
            // A place or thing open on one layout is open on the other.
            guard ui.destination.tab == .places else { return }
            if nowWide { ui.adopt(ui.placesPath, in: store) } else { ui.placesPath = ui.routes(in: store) }
        }
        .onChange(of: seenOnboarding) { _, seen in if !seen { ui.tab = .find } }
        .onContinueUserActivity(CSSearchableItemActionType) { activity in
            if let raw = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String { store.openedItem = UUID(uuidString: raw) }
        }
        .onOpenURL { url in if let link = AppLink(url: url) { open(link) } }
        .onChange(of: QuickActions.shared.link, initial: true) { _, link in
            guard let link else { return }
            open(link)
            QuickActions.shared.link = nil
        }
        .onChange(of: scenePhase) { _, value in
            if value == .active { do { try store.refresh() } catch { reminders.error = error.localizedDescription }; Task { await pro.refresh(); await backUpIfDue() } }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            // Midnight or a time-zone change: regroup the dates and requeue reminders (the revision change does both).
            do { try store.refresh() } catch { reminders.error = error.localizedDescription }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange).receive(on: RunLoop.main)) { _ in
            do { try store.mergeOutsideChanges(); try store.refresh() } catch { reminders.error = error.localizedDescription }
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
            Tab(value: AppTab.packing) { NavigationStack { PackingView() } } label: { Label("Trips", systemImage: "suitcase").environment(\.symbolVariants, .none) }
            Tab(value: AppTab.settings) { NavigationStack(path: $ui.settingsPath) { LibrarySettingsView() } } label: { Label("Settings", systemImage: "gear").environment(\.symbolVariants, .none) }
                .badge(reminders.coverageGap ? Text("!") : nil)
        }
    }

    /// The compact Places stack, with its path kept in the window state.
    private var placesStack: some View {
        @Bindable var ui = ui
        return NavigationStack(path: $ui.placesPath) {
            PlacesView()
                .navigationDestination(for: PlaceRoute.self) { route in
                    switch route {
                    case .place(let id): if let place = store.places.first(where: { $0.id == id }) { PlaceDetailView(place: place) }
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
                catch { reminders.error = error.localizedDescription; return false }
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
        case .trips: NavigationStack { PackingView() }
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
                NavigationStack {
                    PlaceDetailView(place: place)
                        .navigationDestination(item: Binding(get: { split ? nil : selected }, set: { if !split { ui.selectedItem = $0?.id } })) { ItemDetailView(item: $0) }
                }
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
            if wide, let place = store.places.first(where: { $0.id == id }) { ui.reveal(place) }
            else { ui.tab = .places; store.openedPlace = id }
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
