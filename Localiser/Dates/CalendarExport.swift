import EventKit

extension DeadlineKind {
    /// Calendar event title, like "Return: Blue kettle".
    func calendarTitle(itemName: String?) -> String {
        let prefix = switch self { case .returns: "Return"; case .warranty: "Warranty ends"; case .expiry: "Expires"; case .askBack: "Ask for it back" }
        let name = itemName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? prefix : "\(prefix): \(name)"
    }
}

/// Writes all-day events for deadlines. Uses write-only access, so existing events are never read.
@MainActor
enum CalendarExport {
    struct EventPlan: Equatable {
        var title: String
        var start: Date
        var end: Date
        var alarmOffset: TimeInterval
        var notes: String
    }

    static func plan(for deadline: Deadline) -> EventPlan? {
        guard let day = deadline.day, let start = day.date(hour: 0) else { return nil }
        // An all-day event ends on its own day. Ending at the next midnight makes it a two-day event.
        let end = start
        let kind = deadline.kind ?? .returns
        // Alert at the person's chosen hour on the day before (or on the day when there is no lead time).
        let leadDays = min(Int(deadline.leadDays), 1)
        let alarm = TimeInterval(Int(deadline.hour) * 3600 - leadDays * 86_400)
        var notes = "Added by Hereabouts."
        if !deadline.source.isEmpty { notes = deadline.source + "\n\n" + notes }
        return EventPlan(title: kind.calendarTitle(itemName: deadline.item?.publicName), start: start, end: end, alarmOffset: alarm, notes: notes)
    }

    static func makeEvent(_ plan: EventPlan, in store: EKEventStore) -> EKEvent {
        let event = EKEvent(eventStore: store)
        event.title = plan.title
        event.isAllDay = true
        event.startDate = plan.start
        event.endDate = plan.end
        event.notes = plan.notes
        event.addAlarm(EKAlarm(relativeOffset: plan.alarmOffset))
        return event
    }

    /// Dates still ahead that are worth putting in a calendar.
    static func upcoming(_ deadlines: [Deadline], today: CalendarDay = CalendarDay(.now)) -> [Deadline] {
        deadlines.filter { $0.active && ($0.day.map { $0 >= today } ?? false) }
    }

    /// Write-only access can't see what is already in the calendar, so Hereabouts remembers each
    /// date it added, by id and day. Moving a date to another day lets it be added again.
    nonisolated static let exportedKey = "calendarExportedDates"
    static func exportKey(_ deadline: Deadline) -> String { "\(deadline.id.uuidString)|\(deadline.dayString)" }
    nonisolated static func remember(_ keys: [String], defaults: UserDefaults = .standard) {
        let known = Set(defaults.stringArray(forKey: exportedKey) ?? [])
        defaults.set(Array(known.union(keys)).sorted(), forKey: exportedKey)
    }

    /// Saves events straight to the default calendar, skipping dates added before.
    static func addAll(_ deadlines: [Deadline], defaults: UserDefaults = .standard) async throws -> (added: Int, skipped: Int) {
        let known = Set(defaults.stringArray(forKey: exportedKey) ?? [])
        let fresh = deadlines.filter { !known.contains(exportKey($0)) && plan(for: $0) != nil }
        let skipped = deadlines.count - fresh.count
        guard !fresh.isEmpty else { return (0, skipped) }
        let store = EKEventStore()
        guard try await store.requestWriteOnlyAccessToEvents() else { throw CalendarError.denied }
        guard let calendar = store.defaultCalendarForNewEvents else { throw CalendarError.noCalendar }
        var keys = [String]()
        for deadline in fresh {
            guard let plan = plan(for: deadline) else { continue }
            let event = makeEvent(plan, in: store)
            event.calendar = calendar
            try store.save(event, span: .thisEvent, commit: false)
            keys.append(exportKey(deadline))
        }
        try store.commit()
        remember(keys, defaults: defaults)
        return (keys.count, skipped)
    }

    static func summary(added: Int, skipped: Int) -> String {
        if added == 0 {
            return skipped == 0 ? "There are no dates ahead to add." : "These dates were added before. To add one again, open it and choose Add to Calendar."
        }
        let first = added == 1 ? "Added 1 date to your calendar." : "Added \(added) dates to your calendar."
        if skipped == 0 { return first }
        return first + (skipped == 1 ? " 1 was added before." : " \(skipped) were added before.")
    }

    enum CalendarError: LocalizedError {
        case denied, noCalendar
        var errorDescription: String? {
            switch self {
            case .denied: "Hereabouts can't add events. Allow calendar access in Settings, then try again."
            case .noCalendar: "There's no calendar to add events to. Set a default calendar in Settings > Apps > Calendar."
            }
        }
    }
}
