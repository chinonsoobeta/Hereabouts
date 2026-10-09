import UserNotifications
import Observation

@MainActor @Observable
final class ReminderService: NSObject, UNUserNotificationCenterDelegate {
    var permission = "Not checked"
    var scheduled: [PlannedReminder] = []
    var candidateCount = 0
    var error: String?
    @ObservationIgnored private var updateTask: Task<Void, Never>?
    @ObservationIgnored weak var store: LocaliserStore? {
        didSet { replayPendingActions() }
    }
    /// Actions tapped on a notification before the library finished opening (cold launch).
    @ObservationIgnored private(set) var pendingActions: [(id: UUID, action: String)] = []
    /// Deadline the person opened from a notification, for the Due soon tab to show.
    var openedDeadline: UUID?
    /// True when some upcoming reminders cannot be delivered (permission off or over the system limit).
    var coverageGap: Bool { candidateCount > scheduled.count }
    static let showNamesKey = "reminderShowsItemNames"
    /// Item names appear in reminders unless turned off in Settings.
    static var showsItemNames: Bool { UserDefaults.standard.object(forKey: showNamesKey) as? Bool ?? true }
    private let center = UNUserNotificationCenter.current()

    override init() {
        super.init()
        center.delegate = self
        let keep = UNNotificationAction(identifier: "keep", title: "Keep purchase", options: [.foreground])
        let returning = UNNotificationAction(identifier: "returning", title: "Plan to return", options: [.foreground])
        center.setNotificationCategories([UNNotificationCategory(identifier: "localiser.return", actions: [keep, returning], intentIdentifiers: [])])
    }

    func enable() async {
        do { _ = try await center.requestAuthorization(options: [.alert, .sound, .badge]); error = nil }
        catch { self.error = error.localizedDescription }
        if let store { refresh(store.deadlines) }
    }

    func refresh(_ deadlines: [Deadline]) {
        let inputs = deadlines.compactMap(\.reminderInput)
        let previous = updateTask
        previous?.cancel()
        updateTask = Task {
            await previous?.value
            guard !Task.isCancelled else { return }
            await replace(inputs)
        }
    }

    private func replace(_ inputs: [ReminderInput]) async {
        let settings = await center.notificationSettings()
        guard !Task.isCancelled else { return }
        let authorized = [.authorized, .provisional, .ephemeral].contains(settings.authorizationStatus)
        switch settings.authorizationStatus {
        case .notDetermined: permission = "Not enabled"
        case .denied: permission = "Disabled in Settings"
        case .authorized: permission = "Enabled"
        case .provisional: permission = "Quiet delivery"
        case .ephemeral: permission = "Temporary permission"
        @unknown default: permission = "Unknown permission"
        }
        let candidates = ReminderPlan.candidates(inputs)
        candidateCount = candidates.count
        let pending = await center.pendingNotificationRequests()
        guard !Task.isCancelled else { return }
        center.removePendingNotificationRequests(withIdentifiers: pending.filter { $0.identifier.hasPrefix("localiser.deadline.") }.map(\.identifier))
        scheduled = []; error = nil
        guard authorized else { return }
        for reminder in candidates.prefix(50) {
            guard !Task.isCancelled else { return }
            let content = UNMutableNotificationContent()
            let text = reminder.content(showingNames: Self.showsItemNames)
            content.title = text.title
            content.body = text.body
            content.sound = .default
            content.interruptionLevel = .active
            if let itemID = reminder.itemID { content.threadIdentifier = itemID.uuidString }
            content.userInfo = ["deadlineID": reminder.deadlineID.uuidString]
            if reminder.kind == .returns { content.categoryIdentifier = "localiser.return" }
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminder.fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            do {
                try await center.add(UNNotificationRequest(identifier: reminder.id, content: content, trigger: trigger))
                scheduled.append(reminder)
            } catch { self.error = error.localizedDescription }
        }
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions { [.banner, .sound] }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        guard let raw = response.notification.request.content.userInfo["deadlineID"] as? String,
              let id = UUID(uuidString: raw) else { return }
        let action = response.actionIdentifier
        await handle(id: id, action: action)
    }

    func handle(id: UUID, action: String) {
        guard let store else { pendingActions.append((id, action)); return }
        if action == UNNotificationDefaultActionIdentifier { openedDeadline = id; return }
        guard let deadline = store.deadlines.first(where: { $0.id == id }), deadline.kind == .returns, deadline.active else { return }
        do {
            if action == "keep" { try store.decide(deadline, .keeping) }
            else if action == "returning" { try store.decide(deadline, .returning) }
            refresh(store.deadlines)
        } catch { self.error = error.localizedDescription }
    }

    private func replayPendingActions() {
        guard store != nil, !pendingActions.isEmpty else { return }
        let queued = pendingActions
        pendingActions = []
        for entry in queued { handle(id: entry.id, action: entry.action) }
    }
}
