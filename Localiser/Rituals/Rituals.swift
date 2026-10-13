import Foundation

/// The coming-back habits from plan section 10.7: the keeping-up count, the Sunday recap and the
/// monthly stocktake. Everything here is derived from records already in the store.
enum Rituals {
    static let recapKey = "sundayRecapEnabled"
    static let stocktakeKey = "monthlyStocktakeEnabled"
    static let stocktakeDoneKey = "stocktakeDoneMonth"
    static let recapReadKey = "recapReadWeek"
    static var recapEnabled: Bool { UserDefaults.standard.object(forKey: recapKey) as? Bool ?? true }
    static var stocktakeEnabled: Bool { UserDefaults.standard.object(forKey: stocktakeKey) as? Bool ?? true }

    /// Things not confirmed for this long come up in the stocktake and as drifting.
    static let staleMonths = 3
    static let stocktakeSize = 5

    // MARK: Keeping up

    /// Weeks run Sunday to Saturday, whatever the region's first weekday.
    static func weekStart(of date: Date, calendar: Calendar = .current) -> Date {
        var sundays = calendar
        sundays.firstWeekday = 1
        return sundays.dateInterval(of: .weekOfYear, for: date)?.start ?? sundays.startOfDay(for: date)
    }

    /// Consecutive weeks with something written down, moved or confirmed. This week joins the run once it
    /// has activity, so a quiet Monday never resets the count; it simply shows last week's number.
    static func keepingUpWeeks(activity: [Date], now: Date = .now, calendar: Calendar = .current) -> Int {
        let weeks = Set(activity.filter { $0 <= now }.map { weekStart(of: $0, calendar: calendar) })
        var cursor = weekStart(of: now, calendar: calendar)
        if !weeks.contains(cursor) { cursor = previousWeek(cursor, calendar: calendar) }
        var count = 0
        while weeks.contains(cursor) {
            count += 1
            cursor = previousWeek(cursor, calendar: calendar)
        }
        return count
    }

    private static func previousWeek(_ start: Date, calendar: Calendar) -> Date {
        // Step back from midweek so a daylight-saving change cannot land on the wrong Sunday.
        let midweek = calendar.date(byAdding: .day, value: -4, to: start) ?? start
        return weekStart(of: midweek, calendar: calendar)
    }

    @MainActor static func activity(in items: [Belonging]) -> [Date] {
        items.flatMap { item in [item.createdAt] + [item.confirmedAt].compactMap { $0 } + item.movements.map(\.date) }
    }

    // MARK: Stocktake and drifting

    @MainActor static func stale(_ items: [Belonging], now: Date = .now, calendar: Calendar = .current) -> [Belonging] {
        guard let cutoff = calendar.date(byAdding: .month, value: -staleMonths, to: now) else { return [] }
        return items.filter { !$0.archived && !$0.isDeleted && !$0.isMissing && $0.lastConfirmed < cutoff }.sorted { $0.lastConfirmed < $1.lastConfirmed }
    }

    /// Up to five things to ask about this month, oldest confirmation first.
    @MainActor static func stocktake(_ items: [Belonging], now: Date = .now, calendar: Calendar = .current) -> [Belonging] {
        Array(stale(items, now: now, calendar: calendar).prefix(stocktakeSize))
    }

    static func monthKey(_ date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", parts.year ?? 0, parts.month ?? 0)
    }

    /// The stocktake is offered once a month, when there is something to ask about.
    @MainActor static func stocktakeDue(_ items: [Belonging], doneMonth: String?, now: Date = .now, calendar: Calendar = .current) -> Bool {
        stocktakeEnabled && doneMonth != monthKey(now, calendar: calendar) && !stale(items, now: now, calendar: calendar).isEmpty
    }

    /// The first Saturday of the month after `date`, at 10:00. Stocktake nudges land here.
    static func nextStocktakeDate(after date: Date, calendar: Calendar = .current) -> Date? {
        guard let monthStart = calendar.dateInterval(of: .month, for: date)?.start else { return nil }
        for offset in [0, 1] {
            guard let month = calendar.date(byAdding: .month, value: offset, to: monthStart) else { continue }
            var parts = calendar.dateComponents([.year, .month], from: month)
            parts.weekday = 7; parts.weekdayOrdinal = 1; parts.hour = 10
            if let saturday = calendar.date(from: parts), saturday > date { return saturday }
        }
        return nil
    }

    // MARK: Recap

    /// The recap that is currently on offer: this week's from Sunday 18:00, otherwise last week's.
    static func recapWeekKey(now: Date = .now, calendar: Calendar = .current) -> String {
        let start = weekStart(of: now, calendar: calendar)
        let ready = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: start) ?? start
        let week = now >= ready ? start : weekStart(of: calendar.date(byAdding: .day, value: -4, to: start) ?? start, calendar: calendar)
        let parts = calendar.dateComponents([.year, .month, .day], from: week)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    struct Recap {
        var added: [String]
        var moved: Int
        var found: Int = 0
        var confirmed: Int
        var due: [Deadline]
        var drifting: [Belonging]
        var stocktakeCount: Int
        var keepingUp: Int
    }

    /// The last seven days, and the seven ahead.
    @MainActor static func recap(items: [Belonging], deadlines: [Deadline], now: Date = .now, calendar: Calendar = .current) -> Recap {
        let since = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        let live = items.filter { !$0.isDeleted }
        let added = live.filter { $0.createdAt > since }.sorted { $0.createdAt < $1.createdAt }
        // Each figure counts things, once each. A move also counts as seeing a thing, so a thing moved this week
        // is counted as moved, not again as checked.
        // A find is counted as a find rather than a move.
        let foundThisWeek = Set(live.filter { $0.movements.contains { $0.date > since && $0.kind == .found } }.map(\.objectID))
        let movedThisWeek = Set(live.filter { $0.movements.contains { $0.date > since } }.map(\.objectID))
        let moved = movedThisWeek.subtracting(foundThisWeek).count
        let confirmed = live.filter { item in (item.confirmedAt ?? .distantPast) > since && item.createdAt <= since && !movedThisWeek.contains(item.objectID) }.count
        let horizon = CalendarDay(now, calendar: calendar).adding(days: 7, calendar: calendar)
        let due = deadlines.filter { deadline in
            guard deadline.active, let day = deadline.day, let horizon else { return false }
            return day >= CalendarDay(now, calendar: calendar) && day <= horizon
        }.sorted { $0.dayString < $1.dayString }
        let stale = stale(live, now: now, calendar: calendar)
        return Recap(added: added.map(\.name), moved: moved, found: foundThisWeek.count, confirmed: confirmed, due: due, drifting: Array(stale.prefix(3)),
                     stocktakeCount: min(stale.count, stocktakeSize), keepingUp: keepingUpWeeks(activity: activity(in: live), now: now, calendar: calendar))
    }

    // MARK: Trips

    /// Trips still being packed that leave tomorrow or later, with at least one thing not yet in the bag.
    @MainActor static func tripsNeedingEveReminder(_ trips: [TripRecord], now: Date = .now, calendar: Calendar = .current) -> [TripRecord] {
        let today = CalendarDay(now, calendar: calendar)
        return trips.filter { trip in
            guard trip.state == .packing, let start = CalendarDay(stored: trip.startDay), start > today else { return false }
            return trip.entries.contains { $0.packedCount < Int64($0.requiredCount) }
        }
    }
}
