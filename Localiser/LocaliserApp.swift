import SwiftUI
import CoreData

@main
struct LocaliserApp: App {
    @State private var store: LocaliserStore?
    private let loadError: String?

    init() {
        do {
            var url: URL?
            #if DEBUG
            let arguments = ProcessInfo.processInfo.arguments
            if let index = arguments.firstIndex(of: "--ui-test-library"), arguments.indices.contains(index + 1), let id = UUID(uuidString: arguments[index + 1]) {
                let directory = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                url = directory.appendingPathComponent("UITests/\(id.uuidString)/Localiser.sqlite")
            }
            #endif
            let store = try LocaliserStore(url: url)
            #if DEBUG
            if url != nil, ProcessInfo.processInfo.arguments.contains("--demo-library") { try MainActor.assumeIsolated { try DemoLibrary.seed(store) } }
            #endif
            _store = State(initialValue: store); loadError = nil
            Appearance.apply()
        }
        catch { loadError = error.localizedDescription }
    }

    var body: some Scene {
        WindowGroup {
            if let store { RootView().environment(store).tint(Theme.purple) }
            else { ContentUnavailableView("Unable to open your library", systemImage: "externaldrive.badge.exclamationmark", description: Text(loadError ?? "Your stored data has not been deleted. Restart the app and try again.")) }
        }
    }
}

struct RootView: View {
    @Environment(LocaliserStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @State private var reminders = ReminderService()
    @State private var pro = ProAccess()
    var body: some View {
        TabView {
            Tab("Find", systemImage: "magnifyingglass") { NavigationStack { FindView() } }
            Tab("Places", systemImage: "shippingbox") { NavigationStack { PlacesView() } }
            Tab("Due soon", systemImage: "calendar.badge.clock") { NavigationStack { DueView() } }
            Tab("Packing", systemImage: "suitcase") { NavigationStack { PackingView() } }
        }
        .environment(reminders)
        .environment(pro)
        .task { await pro.observeTransactions() }
        .onChange(of: store.revision, initial: true) { _, _ in reminders.store = store; reminders.refresh(store.deadlines) }
        .onChange(of: scenePhase) { _, value in
            if value == .active { do { try store.refresh() } catch { reminders.error = error.localizedDescription }; Task { await pro.refresh() } }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            reminders.refresh(store.deadlines)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSPersistentCloudKitContainer.eventChangedNotification).receive(on: RunLoop.main)) { store.receiveCloudEvent($0) }
        .onReceive(NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange).receive(on: RunLoop.main)) { _ in
            do { try store.refresh() } catch { reminders.error = error.localizedDescription }
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
                Image(systemName: systemImage).accessibilityHidden(true)
            }
        } description: {
            Text(description).foregroundStyle(Theme.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
}
