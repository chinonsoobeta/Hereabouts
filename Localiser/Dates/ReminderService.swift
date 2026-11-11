import UserNotifications
import Observation

@MainActor @Observable
final class ReminderService: NSObject, UNUserNotificationCenterDelegate {
    var permission = "Not checked"
    var scheduled: [PlannedReminder] = []
    var candidateCount = 0
    /// What Settings says under Reminders when turning them on or setting one fails. Always the app's own
    /// words: the system's error text ("Cocoa error 134501") never reaches the screen.
    enum Problem: CaseIterable {
        case notTurnedOn, notSet
        var message: String {
            switch self {
            case .notTurnedOn: String(localized: "Reminders couldn't be turned on. Try again.")
            case .notSet: String(localized: "Some reminders couldn't be set. Close Hereabouts and open it again.")
            }
        }
    }
    var problem: Problem?
    @ObservationIgnored private var updateTask: Task<Void, Never>?
    @ObservationIgnored weak var store: LocaliserStore? {
        didSet { replayPendingActions() }
    }
    /// Actions tapped on a notification before the library finished opening (cold launch).
    @ObservationIgnored private(set) var pendingActions: [(id: UUID, action: String)] = []
    /// Ritual opened from a notification: "recap", "stocktake" or "trip".
    var openedRitual: String?
    @ObservationIgnored private var ritualTask: Task<Void, Never>?
    /// True when some upcoming reminders cannot be delivered (permission off or over the system limit).
    var coverageGap: Bool { candidateCount > scheduled.count }
    static let showNamesKey = "reminderShowsItemNames"
    /// Item names appear in reminders unless turned off in Settings.
    static var showsItemNames: Bool { UserDefaults.standard.object(forKey: showNamesKey) as? Bool ?? true }
    private let center = UNUserNotificationCenter.current()

    override init() {
        super.init()
        center.delegate = self
    }

    func enable() async {
        do { _ = try await center.requestAuthorization(options: [.alert, .sound]); problem = nil }
        catch { problem = .notTurnedOn }
        if let store { refresh(store.deadlines); refreshRituals(store) }
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
        scheduled = []; problem = nil
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
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminder.fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            do {
                try await center.add(UNNotificationRequest(identifier: reminder.id, content: content, trigger: trigger))
                scheduled.append(reminder)
            } catch { problem = .notSet }
        }
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions { [.banner, .sound] }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        if let ritual = response.notification.request.content.userInfo["ritual"] as? String {
            await MainActor.run { openedRitual = ritual }
            return
        }
        guard let raw = response.notification.request.content.userInfo["deadlineID"] as? String,
              let id = UUID(uuidString: raw) else { return }
        let action = response.actionIdentifier
        await handle(id: id, action: action)
    }

    /// Sunday recap, the monthly stocktake and the evening before a trip. Recomputed whenever the library changes.
    func refreshRituals(_ store: LocaliserStore, now: Date = .now) {
        let calendar = Calendar.current
        var requests: [(id: String, title: String, body: String, ritual: String, when: DateComponents, repeats: Bool)] = []
        if Rituals.recapEnabled && !store.items.isEmpty {
            requests.append(("localiser.ritual.recap", String(localized: "Your Sunday recap"), String(localized: "See what you added, lent out or haven't checked lately."), "recap", DateComponents(hour: 18, weekday: 1), true))
        }
        if Rituals.stocktakeEnabled, let date = Rituals.nextStocktakeDate(after: now, calendar: calendar) {
            let count = min(Rituals.stale(store.items, now: date, calendar: calendar).count, Rituals.stocktakeSize)
            if count > 0 {
                requests.append(("localiser.ritual.stocktake", String(localized: "Still there?"), count == 1 ? String(localized: "Check where you keep one thing.") : String(localized: "Check where you keep \(count) things."), "stocktake", calendar.dateComponents([.year, .month, .day, .hour], from: date), false))
            }
        }
        for trip in Rituals.tripsNeedingEveReminder(store.trips, now: now, calendar: calendar).prefix(5) {
            guard let eve = CalendarDay(stored: trip.startDay)?.adding(days: -1, calendar: calendar)?.date(calendar: calendar, hour: 19), eve > now else { continue }
            requests.append(("localiser.ritual.trip.\(trip.id.uuidString)", String(localized: "Leaving tomorrow"), String(localized: "\(trip.name): some things aren't packed yet."), "trip", calendar.dateComponents([.year, .month, .day, .hour], from: eve), false))
        }
        let previous = ritualTask
        previous?.cancel()
        ritualTask = Task {
            await previous?.value
            guard !Task.isCancelled else { return }
            let pending = await center.pendingNotificationRequests()
            center.removePendingNotificationRequests(withIdentifiers: pending.filter { $0.identifier.hasPrefix("localiser.ritual.") }.map(\.identifier))
            let settings = await center.notificationSettings()
            guard [.authorized, .provisional, .ephemeral].contains(settings.authorizationStatus), !Task.isCancelled else { return }
            for request in requests {
                let content = UNMutableNotificationContent()
                content.title = request.title; content.body = request.body; content.sound = .default
                // The night before a trip is worth hearing; recaps and stocktakes wait quietly.
                content.interruptionLevel = request.ritual == "trip" ? .active : .passive
                content.userInfo = ["ritual": request.ritual]
                let trigger = UNCalendarNotificationTrigger(dateMatching: request.when, repeats: request.repeats)
                try? await center.add(UNNotificationRequest(identifier: request.id, content: content, trigger: trigger))
            }
        }
    }

    func handle(id: UUID, action: String) {
        guard let store else { pendingActions.append((id, action)); return }
        // Tapping an ask-back reminder opens the thing it's about.
        guard action == UNNotificationDefaultActionIdentifier, let item = store.deadlines.first(where: { $0.id == id })?.item else { return }
        store.openedItem = item.id
    }

    private func replayPendingActions() {
        guard store != nil, !pendingActions.isEmpty else { return }
        let queued = pendingActions
        pendingActions = []
        for entry in queued { handle(id: entry.id, action: entry.action) }
    }
}
