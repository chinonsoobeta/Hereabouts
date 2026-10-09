import SwiftUI
import CoreData
import CoreSpotlight

@main
struct LocaliserApp: App {
    @State private var store: LocaliserStore?
    /// Created at launch so a notification tapped while the app was closed is not lost.
    @State private var reminders = ReminderService()
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
            }
            if arguments.contains("--show-onboarding") { UserDefaults.standard.set(false, forKey: OnboardingView.seenKey) }
            #endif
            let store = try LocaliserStore(url: url)
            #if DEBUG
            if url != nil, ProcessInfo.processInfo.arguments.contains("--demo-library") { try MainActor.assumeIsolated { try DemoLibrary.seed(store) } }
            #endif
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

enum AppTab: Hashable { case find, places, due, packing }

struct RootView: View {
    @Environment(LocaliserStore.self) private var store
    @Environment(ReminderService.self) private var reminders
    @Environment(\.scenePhase) private var scenePhase
    @State private var pro = ProAccess()
    @State private var tab = AppTab.find
    @AppStorage(OnboardingView.seenKey) private var seenOnboarding = false
    var body: some View {
        TabView(selection: $tab) {
            Tab("Find", systemImage: "magnifyingglass", value: AppTab.find) { NavigationStack { FindView() } }
            Tab("Places", systemImage: "shippingbox", value: AppTab.places) { NavigationStack { PlacesView().settingsButton() } }
            Tab("Due soon", systemImage: "calendar.badge.clock", value: AppTab.due) { NavigationStack { DueView().settingsButton() } }
                .badge(reminders.coverageGap ? Text("!") : nil)
            Tab("Packing", systemImage: "suitcase", value: AppTab.packing) { NavigationStack { PackingView().settingsButton() } }
        }
        .environment(pro)
        .overlay(alignment: .bottom) { UndoDeletionToast() }
        .fullScreenCover(isPresented: Binding(get: { !seenOnboarding }, set: { if !$0 { seenOnboarding = true } })) {
            OnboardingView { seenOnboarding = true }
        }
        .task { await pro.observeTransactions() }
        .onChange(of: store.revision, initial: true) { _, _ in reminders.store = store; reminders.refresh(store.deadlines); Spotlight.index(store) }
        .onChange(of: reminders.openedDeadline) { _, id in if id != nil { tab = .due } }
        .onChange(of: store.openedItem) { _, id in if id != nil { tab = .find } }
        .onContinueUserActivity(CSSearchableItemActionType) { activity in
            if let raw = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String { store.openedItem = UUID(uuidString: raw) }
        }
        .onOpenURL { url in
            // hereabouts://item/<id> and hereabouts://due, used by the widget.
            guard url.scheme == "hereabouts" else { return }
            if url.host() == "item", let id = UUID(uuidString: url.lastPathComponent) { store.openedItem = id }
            if url.host() == "due" { tab = .due }
        }
        .onChange(of: scenePhase) { _, value in
            if value == .active { do { try store.refresh() } catch { reminders.error = error.localizedDescription }; Task { await pro.refresh() } }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            reminders.refresh(store.deadlines)
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange).receive(on: RunLoop.main)) { _ in
            do { try store.refresh() } catch { reminders.error = error.localizedDescription }
        }
    }
}

/// Shown when the library file cannot be opened. Offers the raw file so nothing is lost.
struct StoreFailureView: View {
    let reason: String?
    private var files: [URL] {
        guard let base = try? LocaliserStore.defaultStoreURL() else { return [] }
        return ["", "-wal", "-shm"].map { URL(fileURLWithPath: base.path + $0) }.filter { FileManager.default.fileExists(atPath: $0.path) }
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Image(systemName: "externaldrive.badge.exclamationmark").font(.system(size: 44)).foregroundStyle(Theme.purple).accessibilityHidden(true)
                    Text("Hereabouts couldn't open your library").font(.wbTitle).foregroundStyle(Theme.ink)
                    Text("Nothing has been deleted. Restarting your phone often fixes this. If it keeps happening, save a copy of the library file and send it to us.").font(.wbBody).foregroundStyle(Theme.secondary)
                    if let reason { Text(reason).font(.wbCaption).foregroundStyle(Theme.secondary).textSelection(.enabled) }
                    if !files.isEmpty {
                        ShareLink(items: files) { Label("Save a copy of the library file", systemImage: "square.and.arrow.up") }.buttonStyle(PrimaryButtonStyle())
                    }
                    Link(destination: Support.mail(subject: "Library won't open", body: reason ?? "")) { Label("Contact support", systemImage: "envelope") }.buttonStyle(SoftButtonStyle())
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
