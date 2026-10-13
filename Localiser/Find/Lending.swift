import CoreData

/// "Lend it…" and "It's back": who has a thing, and when to ask for it.
@MainActor extension LocaliserStore {
    var lentItems: [Belonging] {
        items.filter { $0.isLent && !$0.archived && !$0.isDeleted }.sorted { ($0.lentAt ?? .distantPast) > ($1.lentAt ?? .distantPast) }
    }

    /// The thing keeps its home; the movement says who has it. An ask-back day adds a date to Due.
    @discardableResult
    func lend(_ item: Belonging, to person: String, askBackOn day: CalendarDay?, hour: Int = 9, on date: Date = .now) throws -> Deadline? {
        let who = try requiredName(person)
        let movement = NSEntityDescription.insertNewObject(forEntityName: "Movement", into: context) as! Movement
        movement.id = UUID(); movement.date = date; movement.item = item; movement.kindRaw = Movement.Kind.lent.rawValue
        movement.fromPath = item.place?.path ?? Movement.noPlace
        movement.toPath = who
        item.lentTo = who; item.lentAt = date
        guard let day else { try save(); return nil }
        let open = item.deadlines.first { $0.kind == .askBack && $0.decision == .open }
        return try setDeadline(item: item, kind: .askBack, day: day, source: "", leadDays: 0, hour: hour, enabled: true, confirmed: true, existing: open)
    }

    /// Back home: closes the ask-back date and counts as seeing the thing.
    func gotBack(_ item: Belonging, on date: Date = .now) throws {
        guard item.isLent else { return }
        let movement = NSEntityDescription.insertNewObject(forEntityName: "Movement", into: context) as! Movement
        movement.id = UUID(); movement.date = date; movement.item = item; movement.kindRaw = Movement.Kind.back.rawValue
        movement.fromPath = item.lentTo
        movement.toPath = item.place?.path ?? Movement.noPlace
        item.lentTo = ""; item.lentAt = nil; item.confirmedAt = date
        for deadline in item.deadlines where deadline.kind == .askBack && deadline.decision == .open { deadline.decisionRaw = ReturnDecision.returned.rawValue }
        try save()
    }

    /// "Ask again next week": a week from today, or from the ask-back day if that's still ahead.
    func askAgainNextWeek(_ deadline: Deadline, today: CalendarDay = CalendarDay(.now)) throws {
        guard deadline.kind == .askBack, let day = deadline.day else { return }
        guard let next = max(day, today).adding(days: 7) else { return }
        deadline.dayString = next.stored
        try save()
    }
}

extension Belonging {
    /// "With Sam · since 3 Oct", for lists.
    var lentLine: String? {
        guard isLent else { return nil }
        return lentAt.map { "With \(lentTo) · since \($0.formatted(.dateTime.day().month(.abbreviated)))" } ?? "With \(lentTo)"
    }
}
