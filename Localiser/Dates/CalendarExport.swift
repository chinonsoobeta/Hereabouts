import EventKit

extension DeadlineKind {
    /// Calendar event title, like "Return: Blue kettle".
    func calendarTitle(itemName: String?) -> String {
        let prefix = switch self { case .returns: "Return"; case .warranty: "Warranty ends"; case .expiry: "Expires" }
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
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start
        let kind = deadline.kind ?? .returns
        // Alert at the person's chosen hour on the day before (or on the day when there is no lead time).
        let leadDays = min(Int(deadline.leadDays), 1)
        let alarm = TimeInterval(Int(deadline.hour) * 3600 - leadDays * 86_400)
        var notes = "Added by Hereabouts."
        if !deadline.source.isEmpty { notes = deadline.source + "\n\n" + notes }
        return EventPlan(title: kind.calendarTitle(itemName: deadline.item?.name), start: start, end: end, alarmOffset: alarm, notes: notes)
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

    /// Saves events for every deadline straight to the default calendar. Returns how many were added.
    static func addAll(_ deadlines: [Deadline]) async throws -> Int {
        let store = EKEventStore()
        guard try await store.requestWriteOnlyAccessToEvents() else { throw CalendarError.denied }
        guard let calendar = store.defaultCalendarForNewEvents else { throw CalendarError.noCalendar }
        var added = 0
        for deadline in deadlines {
            guard let plan = plan(for: deadline) else { continue }
            let event = makeEvent(plan, in: store)
            event.calendar = calendar
            try store.save(event, span: .thisEvent, commit: false)
            added += 1
        }
        try store.commit()
        return added
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
