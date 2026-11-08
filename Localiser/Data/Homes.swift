import CoreData

/// More than one home: a parent's house, a storage unit, the boat. Lists show the current home;
/// search, dates, reminders, backups and exports cover them all.
@MainActor extension LocaliserStore {
    static let currentHomeKey = "currentHomeID"

    /// The home Find, Places and Trips are showing. Falls back to the oldest home.
    var currentHome: HomeRecord? { homes.first { $0.id == currentHomeID } ?? homes.first }
    var hasSeveralHomes: Bool { homes.count > 1 }

    var placesHere: [Place] { guard let home = currentHome else { return places }; return places.filter { $0.home == home } }
    var itemsHere: [Belonging] { guard let home = currentHome else { return items }; return items.filter { $0.home == home } }
    var kitsHere: [Kit] { guard let home = currentHome else { return kits }; return kits.filter { $0.home == home } }
    var tripsHere: [TripRecord] { guard let home = currentHome else { return trips }; return trips.filter { $0.home == home } }

    func switchHome(to home: HomeRecord) {
        currentHomeID = home.id
        UserDefaults.standard.set(home.id.uuidString, forKey: Self.currentHomeKey)
        UserDefaults.standard.set(home.name, forKey: Home.nameKey)
        revision += 1
    }

    @discardableResult func addHome(name: String) throws -> HomeRecord {
        let clean = try homeName(name)
        let home = insertHome(named: clean)
        try save()
        switchHome(to: home)
        return home
    }

    func renameHome(_ home: HomeRecord, to name: String) throws {
        home.name = try homeName(name)
        try save()
        if home == currentHome { UserDefaults.standard.set(home.name, forKey: Home.nameKey) }
    }

    /// Only an empty home can go, and never the last one.
    func deleteHome(_ home: HomeRecord) throws {
        guard homes.count > 1 else { throw LocaliserError.lastHome }
        guard home.isEmpty else { throw LocaliserError.homeNotEmpty }
        let wasCurrent = home == currentHome
        context.delete(home)
        try save()
        if wasCurrent, let next = homes.first { switchHome(to: next) }
    }

    /// A place and everything in it moves to `home`, things included.
    func move(_ place: Place, into home: HomeRecord?) {
        guard let home else { return }
        for node in place.subtree where node.home != home {
            node.home = home
            for item in node.items { item.home = home }
        }
    }

    /// Moves a thing to `home`, into `place` there or at the top level when nil. Recorded like any other move.
    /// Private stays private, and a home at the free limit still takes it: a move isn't a new thing.
    func moveThing(_ item: Belonging, toHome home: HomeRecord, place: Place?) throws {
        if let place, place.home != home { throw LocaliserError.wrongHome }
        recordMove(item, to: place)
        item.home = home
        try save()
    }

    /// Moves a place, its sub-places and everything in them (archived things too) to `home`, under `parent` there
    /// or at the top level when nil. Sub-places keep their parents, so their paths below the place stay the same.
    /// A place in the new home with the same path is kept beside it, not merged; tidying duplicates can do that later.
    /// Kits and trips point at the same place objects, so they keep working.
    func movePlace(_ place: Place, toHome home: HomeRecord, under parent: Place?) throws {
        if let parent {
            guard parent.home == home else { throw LocaliserError.wrongHome }
            if parent.isWithin(place) { throw LocaliserError.placeCycle }
        }
        guard place.home != home else { return }
        place.parent = parent
        for node in place.subtree {
            node.home = home
            for item in node.items { item.home = home }
        }
        try save()
    }

    private func homeName(_ name: String) throws -> String {
        let clean = try requiredName(name)
        guard clean.count <= Home.maxLength else { throw LocaliserError.tooLong(String(localized: "A home's name"), Home.maxLength) }
        return clean
    }

    private func insertHome(named name: String) -> HomeRecord {
        let home = NSEntityDescription.insertNewObject(forEntityName: "Home", into: context) as! HomeRecord
        home.id = UUID(); home.name = name; home.createdAt = .now
        return home
    }

    /// Notebooks from before homes, and restored older backups, get one home named as before.
    /// Anything without a home joins its place's home, or the first home.
    func ensureHomes(saving: Bool = true) throws {
        let request = NSFetchRequest<HomeRecord>(entityName: "Home")
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        let first = try context.fetch(request).first ?? insertHome(named: Home.name)
        let orphan = NSPredicate(format: "home == nil")
        func orphans<T: NSManagedObject>(_ entity: String) throws -> [T] {
            let request = NSFetchRequest<T>(entityName: entity); request.predicate = orphan
            return try context.fetch(request)
        }
        for place in try orphans("Place") as [Place] {
            var root = place; var seen: Set<UUID> = [place.id]
            while let parent = root.parent, seen.insert(parent.id).inserted { root = parent }
            place.home = root.home ?? first
        }
        for item in try orphans("Belonging") as [Belonging] { item.home = item.place?.home ?? first }
        for kit in try orphans("Kit") as [Kit] { kit.home = first }
        for trip in try orphans("TripRecord") as [TripRecord] { trip.home = first }
        if saving, context.hasChanges { try context.save() }
    }
}
