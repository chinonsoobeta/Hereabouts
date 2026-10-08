import SwiftUI

@main
struct LocaliserApp: App {
    @State private var store: LocaliserStore?
    private let loadError: String?

    init() {
        do { _store = State(initialValue: try LocaliserStore()); loadError = nil }
        catch { loadError = error.localizedDescription }
    }

    var body: some Scene {
        WindowGroup {
            if let store { RootView().environment(store).tint(Theme.purple) }
            else { ContentUnavailableView("Unable to open your library", systemImage: "externaldrive.badge.exclamationmark", description: Text(loadError ?? "Your stored data has not been deleted. Restart the app and try again.")) }
        }
    }
}

enum Theme {
    static let purple = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(red: 0.76, green: 0.65, blue: 0.98, alpha: 1) : UIColor(red: 0.42, green: 0.31, blue: 0.73, alpha: 1)
    })
    static let ground = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(red: 0.09, green: 0.07, blue: 0.13, alpha: 1) : UIColor(red: 0.97, green: 0.96, blue: 0.98, alpha: 1)
    })
}

struct RootView: View {
    @Environment(LocaliserStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @State private var reminders = ReminderService()
    var body: some View {
        TabView {
            Tab("Find", systemImage: "magnifyingglass") { NavigationStack { FindView() } }
            Tab("Places", systemImage: "shippingbox") { NavigationStack { PlacesView() } }
            Tab("Due soon", systemImage: "calendar.badge.clock") { NavigationStack { DueView() } }
        }
        .environment(reminders)
        .onChange(of: store.revision, initial: true) { _, _ in reminders.store = store; reminders.refresh(store.deadlines) }
        .onChange(of: scenePhase) { _, value in
            if value == .active { do { try store.refresh() } catch { reminders.error = error.localizedDescription } }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            reminders.refresh(store.deadlines)
        }
    }
}
