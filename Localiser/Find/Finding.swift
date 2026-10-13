import CoreData

/// "Not there" and "Found it": a thing that wasn't where the notebook said, and where it turned up.
@MainActor extension LocaliserStore {
    var missingItems: [Belonging] {
        items.filter { $0.isMissing && !$0.archived && !$0.isDeleted }.sorted { ($0.missingSince ?? .distantPast) > ($1.missingSince ?? .distantPast) }
    }

    func markMissing(_ item: Belonging, on date: Date = .now) throws {
        item.missingSince = date
        try save()
    }

    /// Records where it turned up, even when that's where it was meant to be. Finding a thing is seeing it.
    func found(_ item: Belonging, at place: Place?, on date: Date = .now) throws {
        let movement = NSEntityDescription.insertNewObject(forEntityName: "Movement", into: context) as! Movement
        movement.id = UUID(); movement.date = date; movement.item = item; movement.kindRaw = Movement.Kind.found.rawValue; movement.by = author
        movement.fromPath = item.place?.path ?? Movement.noPlace
        movement.toPath = place?.path ?? Movement.noPlace
        item.place = place
        item.missingSince = nil
        item.confirmedAt = date
        try save()
    }

    /// Where to look first: where it's meant to be, the last three places it has been, then places used lately.
    func foundSuggestions(for item: Belonging, limit: Int = 6) -> [Place] {
        let byPath = Dictionary(places.map { ($0.path, $0) }, uniquingKeysWith: { first, _ in first })
        var chosen: [Place] = []
        func add(_ place: Place?) { if let place, !chosen.contains(place) { chosen.append(place) } }
        add(item.place)
        let history = item.movements.sorted { $0.date > $1.date }.flatMap { [$0.toPath, $0.fromPath] }.compactMap { byPath[$0] }
        var own: [Place] = []
        for place in history where place != item.place && !own.contains(place) { own.append(place) }
        own.prefix(3).forEach(add)
        let recent = items.flatMap(\.movements).sorted { $0.date > $1.date }.compactMap { byPath[$0.toPath] }
        for place in recent where chosen.count < limit { add(place) }
        return Array(chosen.prefix(limit))
    }
}

extension Movement {
    /// One line for "Where it's been".
    var summary: String {
        switch kind {
        case .moved: "\(Movement.display(fromPath)) → \(Movement.display(toPath))"
        case .found: fromPath == toPath ? "Found where it should be" : "Found in \(Movement.display(toPath))"
        case .lent: "Lent to \(toPath)"
        case .back: "Back from \(fromPath)"
        }
    }

    /// "Sam, Tuesday": who made the move, once a home is shared. Nil for the phone's owner.
    var byline: String? { by.isEmpty ? nil : by }

    /// What the app says after a find: "Noted. Next time, look in Hall › Drawer."
    static func foundSentence(_ place: Place?) -> String {
        place.map { "Noted. Next time, look in \($0.path)." } ?? "Noted. Give it a place when you know where it lives."
    }
}
