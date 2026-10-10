import Foundation

struct CalendarDay: Equatable, Comparable, Sendable {
    let year: Int
    let month: Int
    let day: Int
    var stored: String { String(format: "%04d-%02d-%02d", year, month, day) }

    init(_ date: Date, calendar: Calendar = .current) {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = calendar.timeZone
        let values = gregorian.dateComponents([.year, .month, .day], from: date)
        year = values.year!; month = values.month!; day = values.day!
    }

    init?(stored: String) {
        let parts = stored.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3, let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]),
              (1...9999).contains(year), (1...12).contains(month), (1...31).contains(day) else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12)),
              calendar.component(.year, from: date) == year,
              calendar.component(.month, from: date) == month,
              calendar.component(.day, from: date) == day else { return nil }
        self.year = year; self.month = month; self.day = day
    }

    func date(calendar: Calendar = .current, hour: Int = 12) -> Date? {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = calendar.timeZone
        return gregorian.date(from: DateComponents(year: year, month: month, day: day, hour: hour))
    }

    static func < (lhs: Self, rhs: Self) -> Bool { lhs.stored < rhs.stored }

    func adding(days: Int, calendar: Calendar = .current) -> CalendarDay? {
        guard let noon = date(calendar: calendar), let result = calendar.date(byAdding: .day, value: days, to: noon) else { return nil }
        return CalendarDay(result, calendar: calendar)
    }
}

enum DeadlineKind: String, CaseIterable, Identifiable, Sendable {
    case returns, warranty, expiry
    var id: String { rawValue }
    var title: String { switch self { case .returns: "Return by"; case .warranty: "Warranty ends"; case .expiry: "Expires" } }
    /// The date in a sentence, like "Looks like a return date".
    var noun: String { switch self { case .returns: "return date"; case .warranty: "warranty end date"; case .expiry: "expiry date" } }
    var defaultLeadDays: Int { switch self { case .returns: 3; case .warranty: 30; case .expiry: 180 } }
}

enum ReturnDecision: String, Sendable { case open, keeping, returning, returned }

/// Where a date sits on the Due board.
enum DueGroup: String, CaseIterable, Sendable {
    case missed, thisWeek, later, done
    var title: String { switch self { case .missed: "Missed"; case .thisWeek: "This week"; case .later: "Later"; case .done: "Done" } }

    /// A return stays open after its day until someone says what happened. A warranty or expiry
    /// that has passed needs nothing more, so it joins Done rather than piling up as missed.
    static func of(kind: DeadlineKind?, active: Bool, day: CalendarDay?, today: CalendarDay, calendar: Calendar = .current) -> DueGroup {
        guard active else { return .done }
        guard let day else { return .later }
        if day < today { return kind == .returns ? .missed : .done }
        if let weekOut = today.adding(days: 7, calendar: calendar), day <= weekOut { return .thisWeek }
        return .later
    }
}

struct ReminderInput: Sendable {
    var id: UUID
    var day: CalendarDay
    var kind: DeadlineKind
    var leadDays: Int
    var hour: Int
    var enabled: Bool
    var archived: Bool
    var decision: ReturnDecision
    var itemName: String = ""
    var itemID: UUID?
}

struct PlannedReminder: Equatable, Sendable {
    var id: String
    var deadlineID: UUID
    var fireDate: Date
    var kind: DeadlineKind
    var daysBefore: Int = 0
    var itemName: String = ""
    var itemID: UUID?
    var day: CalendarDay?

    /// Notification wording. Item names appear unless the person turned them off in Settings.
    func content(showingNames: Bool) -> (title: String, body: String) {
        let subject = showingNames && !itemName.isEmpty ? itemName : "A saved thing"
        let when = daysBefore == 0 ? "today" : (daysBefore == 1 ? "tomorrow" : "in \(daysBefore) days")
        let body: String = switch kind {
        case .returns: "\(subject): last day to return is \(when)."
        case .warranty: "\(subject): warranty ends \(when)."
        case .expiry: "\(subject): expires \(when)."
        }
        let title: String = switch kind { case .returns: "Return window closing"; case .warranty: "Warranty ending"; case .expiry: "Expiry coming up" }
        return (title, body)
    }
}

enum ReminderPlan {
    static func candidates(_ inputs: [ReminderInput], now: Date = .now, calendar: Calendar = .current) -> [PlannedReminder] {
        inputs.flatMap { input -> [PlannedReminder] in
            guard input.enabled, !input.archived,
                  input.kind != .returns || [.open, .returning].contains(input.decision) else { return [] }
            let offsets = input.leadDays == 0 ? [0] : [input.leadDays, 0]
            return offsets.compactMap { offset in
                guard let day = input.day.adding(days: -offset, calendar: calendar),
                      let fireDate = day.date(calendar: calendar, hour: input.hour), fireDate > now else { return nil }
                return PlannedReminder(id: "localiser.deadline.\(input.id.uuidString).\(offset)", deadlineID: input.id, fireDate: fireDate, kind: input.kind, daysBefore: offset, itemName: input.itemName, itemID: input.itemID, day: input.day)
            }
        }.sorted { $0.fireDate == $1.fireDate ? $0.id < $1.id : $0.fireDate < $1.fireDate }
    }
}
