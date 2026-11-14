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
    /// "Text them" on an ask-back reminder (the owner's yes, 12 Nov). It opens Hereabouts, so the phone is unlocked
    /// first, and Messages opens with the note written; nothing is sent from the Lock Screen.
    static let textAction = "localiser.askBack.text"
    static let askBackCategoryID = "localiser.askBack"
    static var askBackCategory: UNNotificationCategory {
        UNNotificationCategory(identifier: askBackCategoryID, actions: [UNNotificationAction(identifier: textAction, title: String(localized: "Text them"), options: [.foreground], icon: UNNotificationActionIcon(systemImageName: "message"))], intentIdentifiers: [])
    }

    override init() {
        super.init()
        center.delegate = self
        // Without Messages on this device, ask-back reminders have no button.
        center.setNotificationCategories([AskBackNote.canText ? Self.askBackCategory : UNNotificationCategory(identifier: Self.askBackCategoryID, actions: [], intentIdentifiers: [])])
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
            if reminder.kind == .askBack { content.categoryIdentifier = Self.askBackCategoryID }
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

    /// What a tapped notification says, read out before it leaves the system's thread.
    struct Tap: Sendable {
        var ritual: String?
        var deadlineID: String?
        var action: String
        init(userInfo: [AnyHashable: Any], action: String) {
            ritual = userInfo["ritual"] as? String
            deadlineID = userInfo["deadlineID"] as? String
            self.action = action
        }
    }

    // Completion handlers, not the async versions: those hand control back to iOS on a background thread, and UIKit
    // aborts when it then updates the app's snapshot (the build 4 beta crash, 12 November). Both finish on the main actor.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        nonisolated(unsafe) let finish = completionHandler
        Task { @MainActor in finish([.banner, .sound]) }
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                            withCompletionHandler completionHandler: @escaping () -> Void) {
        let tap = Tap(userInfo: response.notification.request.content.userInfo, action: response.actionIdentifier)
        nonisolated(unsafe) let finish = completionHandler
        Task { @MainActor in
            self.receive(tap)
            finish()
        }
    }

    func receive(_ tap: Tap) {
        if let ritual = tap.ritual { openedRitual = ritual; return }
        guard let raw = tap.deadlineID, let id = UUID(uuidString: raw) else { return }
        handle(id: id, action: tap.action)
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
        // Tapping an ask-back reminder opens the thing it's about. "Text them" opens it with the note in Messages over it.
        guard action == UNNotificationDefaultActionIdentifier || action == Self.textAction,
              let item = store.deadlines.first(where: { $0.id == id })?.item else { return }
        store.openedItem = item.id
        if action == Self.textAction { store.textRequest = item.id }
    }

    private func replayPendingActions() {
        guard store != nil, !pendingActions.isEmpty else { return }
        let queued = pendingActions
        pendingActions = []
        for entry in queued { handle(id: entry.id, action: entry.action) }
    }
}
