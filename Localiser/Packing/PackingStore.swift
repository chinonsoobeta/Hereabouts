import CoreData

@MainActor extension LocaliserStore {
    @discardableResult
    func addKit(name: String) throws -> Kit {
        let clean = try requiredName(name)
        let kit = NSEntityDescription.insertNewObject(forEntityName: "Kit", into: context) as! Kit
        kit.id = UUID(); kit.name = clean; kit.home = currentHome
        for title in [String(localized: "Check appliances"), String(localized: "Lock doors"), String(localized: "Take keys")] {
            let task = NSEntityDescription.insertNewObject(forEntityName: "KitTask", into: context) as! KitTask
            task.id = UUID(); task.title = title; task.kit = kit
        }
        try save(); return kit
    }

    func editKit(_ kit: Kit, name: String) throws { kit.name = try requiredName(name); try save() }

    @discardableResult
    func setKitEntry(kit: Kit, existing: KitEntry? = nil, name: String, item: Belonging?, unit: Int, perNight: Bool, perDay: Bool = false, condition: PackingCondition) throws -> KitEntry {
        let clean = try requiredName(item?.name ?? name)
        guard (1...99).contains(unit), item?.archived != true else { throw LocaliserError.invalidPackingEntry }
        let entry = existing ?? (NSEntityDescription.insertNewObject(forEntityName: "KitEntry", into: context) as! KitEntry)
        if existing == nil { entry.id = UUID() }
        entry.kit = kit; entry.name = clean; entry.item = item; entry.unitQuantity = Int64(unit); entry.perNight = perNight && !perDay; entry.perDay = perDay; entry.unlinked = false; entry.conditionRaw = condition.rawValue
        try save(); return entry
    }

    func deleteKitEntry(_ entry: KitEntry) throws { context.delete(entry); try save() }
    func addKitTask(_ kit: Kit, title: String) throws {
        let clean = try requiredName(title)
        let task = NSEntityDescription.insertNewObject(forEntityName: "KitTask", into: context) as! KitTask
        task.id = UUID(); task.title = clean; task.kit = kit; try save()
    }
    func deleteKitTask(_ task: KitTask) throws { context.delete(task); try save() }
    func deleteKit(_ kit: Kit) throws {
        for entry in kit.entries { context.delete(entry) }; for task in kit.tasks { context.delete(task) }
        context.delete(kit); try save()
    }

    @discardableResult
    func addTrip(_ details: TripDetails, kit: Kit? = nil) throws -> TripRecord {
        let clean = try requiredName(details.name)
        guard details.end >= details.start else { throw LocaliserError.invalidTripDates }
        let trip = NSEntityDescription.insertNewObject(forEntityName: "TripRecord", into: context) as! TripRecord
        trip.id = UUID(); trip.stateRaw = TripState.packing.rawValue; trip.home = kit?.home ?? currentHome
        apply(details, name: clean, to: trip)
        for template in kit?.entries ?? [] where template.item?.archived != true {
            let entry = NSEntityDescription.insertNewObject(forEntityName: "TripEntry", into: context) as! TripEntry
            entry.id = UUID(); entry.trip = trip; entry.item = template.item; entry.name = template.name
            entry.unitQuantity = template.unitQuantity; entry.perNight = template.perNight; entry.perDay = template.perDay; entry.unlinked = template.unlinked; entry.conditionRaw = template.conditionRaw
            entry.manualQuantity = -1; entry.packedCount = 0; entry.resolutionRaw = HomeResolution.pending.rawValue
        }
        let tasks = kit.map { $0.tasks.map(\.title) } ?? [String(localized: "Check appliances"), String(localized: "Lock doors"), String(localized: "Take keys")]
        for title in tasks {
            let task = NSEntityDescription.insertNewObject(forEntityName: "TripTask", into: context) as! TripTask
            task.id = UUID(); task.trip = trip; task.title = title; task.checked = false
        }
        try save(); return trip
    }

    func editTrip(_ trip: TripRecord, details: TripDetails) throws {
        let clean = try requiredName(details.name)
        guard details.end >= details.start else { throw LocaliserError.invalidTripDates }
        // Validate the proposed dates before changing anything: existing allocations may overlap after an edit.
        for entry in trip.entries where entry.allocatesItem {
            if let item = entry.item, let conflict = tripEntries.first(where: { $0.item == item && $0.trip != trip && $0.allocatesItem && ($0.trip?.startDay ?? "") <= details.end.stored && details.start.stored <= ($0.trip?.endDay ?? "") }) {
                throw LocaliserError.packingConflict(conflict.trip?.name ?? String(localized: "another trip"))
            }
        }
        apply(details, name: clean, to: trip); try save()
    }

    private func apply(_ details: TripDetails, name: String, to trip: TripRecord) {
        trip.name = name; trip.startDay = details.start.stored; trip.endDay = details.end.stored
        trip.flying = details.flying; trip.international = details.international; trip.work = details.work
    }

    func addTripEntry(_ trip: TripRecord, name: String, item: Belonging?) throws {
        let clean = try requiredName(item?.name ?? name)
        guard trip.state == .packing, item?.archived != true else { throw LocaliserError.invalidPackingEntry }
        let entry = NSEntityDescription.insertNewObject(forEntityName: "TripEntry", into: context) as! TripEntry
        entry.id = UUID(); entry.trip = trip; entry.item = item; entry.name = clean; entry.unitQuantity = 1
        entry.perNight = false; entry.perDay = false; entry.unlinked = false; entry.conditionRaw = PackingCondition.always.rawValue
        entry.manualQuantity = -1; entry.packedCount = 0; entry.resolutionRaw = HomeResolution.pending.rawValue
        try save()
    }

    func pack(_ entry: TripEntry, count: Int) throws {
        guard let trip = entry.trip, trip.state == .packing, count >= 0,
              count <= max(entry.requiredCount, Int(entry.packedCount)), count == 0 || entry.item?.archived != true else { throw LocaliserError.invalidPackingEntry }
        if count > 0, let item = entry.item {
            if let conflict = tripEntries.first(where: { $0.id != entry.id && $0.item == item && $0.allocatesItem && ($0.trip == trip || $0.trip.map(trip.overlaps) == true) }) {
                throw LocaliserError.packingConflict(conflict.trip?.name ?? String(localized: "another checklist row"))
            }
        }
        if entry.packedCount == 0 && count > 0 { entry.homePlace = entry.item?.place; entry.resolutionRaw = HomeResolution.pending.rawValue }
        entry.packedCount = Int64(count); try save()
    }

    func setTripQuantity(_ entry: TripEntry, override: Int?) throws {
        guard entry.trip?.state == .packing, override.map({ (0...9999).contains($0) }) ?? true else { throw LocaliserError.invalidPackingEntry }
        entry.manualQuantity = Int64(override ?? -1); try save()
    }

    func deleteTripEntry(_ entry: TripEntry) throws {
        guard entry.trip?.state == .packing else { throw LocaliserError.invalidPackingEntry }
        context.delete(entry); try save()
    }
    func addTripTask(_ trip: TripRecord, title: String) throws {
        let clean = try requiredName(title)
        let task = NSEntityDescription.insertNewObject(forEntityName: "TripTask", into: context) as! TripTask
        task.id = UUID(); task.title = clean; task.trip = trip; task.checked = false; try save()
    }
    func checkTask(_ task: TripTask, checked: Bool) throws { task.checked = checked; try save() }
    func deleteTripTask(_ task: TripTask) throws { context.delete(task); try save() }

    func changeTripState(_ trip: TripRecord, to state: TripState) throws {
        if state == .away {
            guard trip.state == .packing, trip.tasks.allSatisfy(\.checked), trip.entries.allSatisfy({ $0.requiredCount == 0 || ($0.item?.archived != true && $0.packedCount >= $0.requiredCount) }) else { throw LocaliserError.incompleteDeparture }
        }
        if state == .comingHome { guard trip.state == .away || trip.state == .packing else { throw LocaliserError.invalidPackingEntry } }
        if state == .finished { guard trip.state == .comingHome, trip.unresolvedEntries.isEmpty else { throw LocaliserError.unresolvedHome } }
        trip.stateRaw = state.rawValue; try save()
    }

    func resolveHome(_ entry: TripEntry, resolution: HomeResolution, newPlace: Place? = nil) throws {
        guard entry.trip?.state == .comingHome, entry.packedCount > 0 else { throw LocaliserError.invalidPackingEntry }
        if resolution == .newPlace && newPlace == nil { throw LocaliserError.invalidPackingEntry }
        if entry.item?.archived == true && resolution != .noLongerHere && resolution != .unresolved { throw LocaliserError.invalidPackingEntry }
        if resolution == .noLongerHere && entry.item?.archived != true { throw LocaliserError.invalidPackingEntry }
        if let item = entry.item {
            if resolution == .putBack { recordMove(item, to: entry.homePlace) }
            if resolution == .newPlace { recordMove(item, to: newPlace) }
            // Back where it lives isn't a move, but it was just seen there.
            if resolution == .putBack || resolution == .newPlace { item.confirmedAt = .now }
        }
        entry.resolutionRaw = resolution.rawValue; try save()
    }

    func deleteTrip(_ trip: TripRecord) throws {
        for entry in trip.entries { context.delete(entry) }; for task in trip.tasks { context.delete(task) }
        context.delete(trip); try save()
    }
}
