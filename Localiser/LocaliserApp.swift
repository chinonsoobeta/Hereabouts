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
                UserDefaults.standard.removeObject(forKey: Rituals.recapReadKey)
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

enum AppTab: Hashable { case find, places, packing }

struct RootView: View {
    @Environment(LocaliserStore.self) private var store
    @Environment(ReminderService.self) private var reminders
    @Environment(\.scenePhase) private var scenePhase
    @State private var pro = ProAccess()
    @State var tab = AppTab.find
    @AppStorage(OnboardingView.seenKey) private var seenOnboarding = false
    var body: some View {
        TabView(selection: $tab) {
            Tab(value: AppTab.find) { NavigationStack { FindView() } } label: { Label("Find", systemImage: "magnifyingglass").environment(\.symbolVariants, .none) }
            Tab(value: AppTab.places) { NavigationStack { PlacesView().settingsButton() } } label: { Label("Places", systemImage: "shippingbox").environment(\.symbolVariants, .none) }
            Tab(value: AppTab.packing) { NavigationStack { PackingView().settingsButton() } } label: { Label("Trips", systemImage: "suitcase").environment(\.symbolVariants, .none) }
        }
        .tint(Theme.purpleInk)
        .tipViewStyle(NotebookTipStyle())
        .tipBackground(Theme.lilacPaper)
        .environment(pro)
        .overlay(alignment: .bottom) { UndoDeletionToast() }
        .fullScreenCover(isPresented: Binding(get: { !seenOnboarding }, set: { if !$0 { seenOnboarding = true } })) {
            OnboardingView { seenOnboarding = true }
        }
        .task { await pro.observeTransactions() }
        .onChange(of: store.revision, initial: true) { _, _ in reminders.store = store; reminders.refresh(store.deadlines); reminders.refreshRituals(store); Spotlight.index(store) }
        .onChange(of: reminders.openedRitual) { _, ritual in
            switch ritual {
            case "trip": tab = .packing; reminders.openedRitual = nil
            case .some: tab = .find
            case nil: break
            }
        }
        .onChange(of: store.openedItem) { _, id in if id != nil { tab = .find } }
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
            if value == .active { do { try store.refresh() } catch { reminders.error = error.localizedDescription }; Task { await pro.refresh() } }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            // Midnight or a time-zone change: regroup the dates and requeue reminders (the revision change does both).
            do { try store.refresh() } catch { reminders.error = error.localizedDescription }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange).receive(on: RunLoop.main)) { _ in
            do { try store.mergeOutsideChanges(); try store.refresh() } catch { reminders.error = error.localizedDescription }
        }
    }
}

extension RootView {
    func open(_ link: AppLink) {
        switch link {
        case .item(let id): store.openedItem = id
        case .place(let id): tab = .places; store.openedPlace = id
        case .find, .new, .putAway: tab = .find; store.findRequest = link
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
                    Text("Nothing has been deleted. Restarting your phone often fixes this. If it keeps happening, save a copy of the notebook file and send it to us.").font(.wbBody).foregroundStyle(Theme.secondary)
                    if let reason { Text(reason).font(.wbCaption).foregroundStyle(Theme.secondary).textSelection(.enabled) }
                    if !files.isEmpty {
                        ShareLink(items: files) { Label("Save a copy of the notebook file", systemImage: "square.and.arrow.up") }.buttonStyle(PrimaryButtonStyle())
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
