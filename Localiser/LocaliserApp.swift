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

    var tab: AppTab {
        get { destination.tab }
        set { destination = Destination(tab: newValue, keeping: destination) }
    }

    /// Opens a place in the wide layout, with the thing beside it if one is given.
    func reveal(_ place: Place, item: UUID? = nil) {
        destination = .place(place.topLevel.id)
        selectedItem = item
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
            guard let item = store.items.first(where: { $0.id == id }), !item.isDeleted else { selectedItem = nil; return }
            if case .place(let placeID) = destination, item.place?.topLevel.id != placeID { selectedItem = nil }
        }
        if let id = findItem, !store.items.contains(where: { $0.id == id }) { findItem = nil }
    }
}

struct RootView: View {
    @Environment(LocaliserStore.self) private var store
    @Environment(ReminderService.self) private var reminders
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var pro = ProAccess()
    @State private var ui = WindowState()
    @AppStorage(OnboardingView.seenKey) private var seenOnboarding = false
    private var wide: Bool { sizeClass == .regular }

    var body: some View {
        @Bindable var ui = ui
        Group {
            if wide { wideTabs } else { compactTabs }
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
    }

    /// Four tabs: every iPhone, and the Duo's outer screen.
    private var compactTabs: some View {
        @Bindable var ui = ui
        return TabView(selection: $ui.tab) {
            Tab(value: AppTab.find) { NavigationStack { FindView() } } label: { Label("Find", systemImage: "magnifyingglass").environment(\.symbolVariants, .none) }
            Tab(value: AppTab.places) { NavigationStack { PlacesView() } } label: { Label("Places", systemImage: "shippingbox").environment(\.symbolVariants, .none) }
            Tab(value: AppTab.packing) { NavigationStack { PackingView() } } label: { Label("Trips", systemImage: "suitcase").environment(\.symbolVariants, .none) }
            Tab(value: AppTab.settings) { NavigationStack { LibrarySettingsView() } } label: { Label("Settings", systemImage: "gear").environment(\.symbolVariants, .none) }
                .badge(reminders.coverageGap ? Text("!") : nil)
        }
    }

    /// A sidebar beside the content: the Duo's inner screen and every iPad.
    private var wideTabs: some View {
        @Bindable var ui = ui
        let _ = store.revision
        return TabView(selection: $ui.destination) {
            Tab(value: Destination.search, role: .search) { Color.clear } label: { Label("Search", systemImage: "magnifyingglass") }
            Tab(value: Destination.find) { NavigationStack { FindView() } } label: { Label("Find", systemImage: "house") }
            Tab(value: Destination.trips) { NavigationStack { PackingView() } } label: { Label("Trips", systemImage: "suitcase") }
            Tab(value: Destination.settings) { NavigationStack { LibrarySettingsView() } } label: { Label("Settings", systemImage: "gear") }
                .badge(reminders.coverageGap ? Text("!") : nil)
            TabSection("Places") {
                Tab(value: Destination.places) { NavigationStack { PlacesView() } } label: { Label("All places", systemImage: "shippingbox") }
                ForEach(store.placesHere.filter { $0.parent == nil }) { place in
                    Tab(value: Destination.place(place.id)) { WidePlaceView(place: place) } label: { Label(place.name, systemImage: PlaceTile.symbol(for: place.name)) }
                        .badge(place.activeItemCount)
                }
            }
            .expandedByDefault()
            TabSection("Coming up") {
                ForEach(store.tripsHere.filter { [.packing, .away, .comingHome].contains($0.state) }.sorted { $0.startDay < $1.startDay }) { trip in
                    Tab(value: Destination.trip(trip.id)) { NavigationStack { TripDetailView(trip: trip) } } label: { Label(trip.name, systemImage: "suitcase") }
                }
            }
            .expandedByDefault()
            TabSection("Kits") {
                ForEach(store.kitsHere) { kit in
                    Tab(value: Destination.kit(kit.id)) { NavigationStack { KitDetailView(kit: kit) } } label: { Label(kit.name, systemImage: "checklist") }
                }
            }
            .expandedByDefault()
        }
        .tabViewStyle(.sidebarAdaptable)
        .tabViewSidebarHeader {
            VStack(alignment: .leading, spacing: 2) {
                Text(store.currentHome?.name ?? Home.defaultName).font(.wbTitle).foregroundStyle(Theme.ink)
                Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide))).font(.wbCaption).foregroundStyle(Theme.pencil)
            }
            .accessibilityElement(children: .combine)
            .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 12)
        }
        .tabViewSidebarBottomBar {
            Button { ui.newThing = NewThing() } label: { Label("Add a thing", systemImage: "plus").fixedSize(horizontal: false, vertical: true) }
                .buttonStyle(PrimaryButtonStyle()).padding(12)
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
