import XCTest
import CoreData
import UIKit
import PDFKit
import StoreKit
import StoreKitTest
import UserNotifications
@testable import Localiser

@MainActor
final class LocaliserTests: XCTestCase {
    func testLifetimePurchaseRestoreRefundAndCreationLimitsPreserveLibrary() async throws {
        if #unavailable(iOS 27) { throw XCTSkip("iOS 26.5's local StoreKit test service rejects configuration (SKInternalErrorDomain 3). Verify this test on iOS 27; signed-device sandbox purchase testing remains required.") }
        let file = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "Localiser", withExtension: "storekit"))
        let session = try SKTestSession(contentsOf: file)
        session.resetToDefaultState(); session.disableDialogs = true; session.clearTransactions()
        defer { session.clearTransactions(); session.resetToDefaultState() }
        let pro = ProAccess()
        let changes = Task { await pro.observeTransactions() }
        defer { changes.cancel() }
        await pro.refresh(); await pro.loadProduct()
        _ = try XCTUnwrap(pro.product(.lifetime), "StoreKit did not load the local test product; do not enter an Apple account.")
        XCTAssertFalse(pro.unlocked)
        XCTAssertEqual(CreationKind.item.freeLimit, 15)
        XCTAssertTrue(pro.allows(.item, count: 14)); XCTAssertFalse(pro.allows(.item, count: 15))
        XCTAssertTrue(pro.allows(.kit, count: 0)); XCTAssertFalse(pro.allows(.kit, count: 1))
        let store = try LocaliserStore(inMemory: true)
        let item = try store.addItem(name: "Keep after refund")
        await pro.purchase(.lifetime)
        XCTAssertTrue(pro.unlocked, pro.message ?? "No purchase message")
        XCTAssertEqual(pro.standing?.plan, .lifetime)
        XCTAssertTrue(pro.allows(.item, count: 500))
        let restored = ProAccess()
        await restored.restorePurchases()
        XCTAssertTrue(restored.unlocked, restored.message ?? "No restore message")
        let transaction = try XCTUnwrap(session.allTransactions().first)
        try session.refundTransaction(identifier: transaction.identifier)
        for _ in 0..<50 {
            if !pro.unlocked { break }
            try await Task.sleep(for: .milliseconds(100))
        }
        XCTAssertFalse(pro.unlocked)
        XCTAssertEqual(store.items.first?.id, item.id)
        XCTAssertTrue(store.inventoryCSV().contains(item.name))
        XCTAssertEqual(try store.backup().records.filter { $0.entity != "Home" }.count, 1)
        try store.editItem(item, name: "Editable after refund", place: nil, notes: "", aliases: "", photo: nil)
        XCTAssertEqual(item.name, "Editable after refund")
    }

    func testCanceledFailedAndPendingPurchasesDoNotUnlock() async throws {
        if #unavailable(iOS 27) { throw XCTSkip("iOS 26.5's local StoreKit test service rejects configuration (SKInternalErrorDomain 3). Verify this test on iOS 27; signed-device sandbox purchase testing remains required.") }
        let file = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "Localiser", withExtension: "storekit"))
        let session = try SKTestSession(contentsOf: file)
        session.resetToDefaultState(); session.disableDialogs = true; session.clearTransactions()
        defer { session.clearTransactions(); session.resetToDefaultState() }
        let pro = ProAccess()
        // Until the App Store answers, the Pro screen shows a spinner rather than "Pro isn't available".
        XCTAssertFalse(pro.productChecked)
        await pro.loadProduct()
        XCTAssertTrue(pro.productChecked)
        _ = try XCTUnwrap(pro.product(.yearly), "StoreKit did not load the local test product; do not enter an Apple account.")
        try await session.setSimulatedError(.generic(.userCancelled), forAPI: .purchase)
        await pro.purchase()
        XCTAssertFalse(pro.unlocked); XCTAssertFalse(pro.busy); XCTAssertNotNil(pro.message)
        try await session.setSimulatedError(.generic(.networkError(URLError(.notConnectedToInternet))), forAPI: .purchase)
        await pro.purchase()
        XCTAssertFalse(pro.unlocked); XCTAssertFalse(pro.busy); XCTAssertNotNil(pro.message)
        try await session.setSimulatedError(nil, forAPI: .purchase)
        session.askToBuyEnabled = true
        await pro.purchase()
        XCTAssertFalse(pro.unlocked)
        XCTAssertEqual(pro.message, "Waiting for approval. Everything free still works.")
    }

    func testBackupRoundTripPreservesFilesDatesHistoryAndPacking() throws {
        let source = try LocaliserStore(inMemory: true)
        let room = try source.addPlace(name: "Bedroom")
        let drawer = try source.addPlace(name: "Drawer", parent: room)
        let item = try source.addItem(name: "Passport", place: room, notes: "Travel", aliases: "ID", photo: Data([1, 2]))
        try source.move(item, to: drawer)
        let day = try XCTUnwrap(CalendarDay(stored: "2028-07-14"))
        try source.setDeadline(item: item, kind: .askBack, day: day, source: "Confirmed", leadDays: 180, hour: 9, enabled: true, confirmed: true)
        let kit = try source.addKit(name: "Travel")
        try source.setKitEntry(kit: kit, name: "", item: item, unit: 1, perNight: false, condition: .always)
        let trip = try source.addTrip(TripDetails(name: "Trip", start: day, end: day), kit: kit)
        try source.pack(try XCTUnwrap(trip.entries.first), count: 1)
        try source.checkTask(try XCTUnwrap(trip.tasks.first), checked: true)
        let file = try LibraryBackup.decoded(source.backup(attachmentIDs: [item.id]).encoded())
        XCTAssertEqual(Set(file.records.map(\.entity)).count, 11)
        let restored = try LocaliserStore(inMemory: true)
        try restored.restore(file)
        XCTAssertEqual(restored.items.first?.id, item.id)
        XCTAssertEqual(restored.items.first?.place?.path, "Bedroom › Drawer")
        XCTAssertEqual(restored.items.first?.photo, Data([1, 2]))
        XCTAssertEqual(restored.items.first?.movements.count, 1)
        XCTAssertEqual(restored.deadlines.first?.dayString, day.stored)
        XCTAssertEqual(restored.trips.first?.entries.first?.packedCount, 1)
        XCTAssertEqual(restored.trips.first?.tasks.filter(\.checked).count, 1)
        XCTAssertEqual(restored.items.first?.packedTrips.first?.id, trip.id)
        XCTAssertFalse(restored.container is NSPersistentCloudKitContainer)
        let dateOnly = try source.backup()
        XCTAssertFalse(dateOnly.records.contains { $0.attributes.values.contains { if case .data = $0 { true } else { false } } })
        try restored.resetLibrary()
        XCTAssertEqual(try restored.backup().records.map(\.entity), ["Home"], "Erasing leaves one empty home")
        try restored.restore(dateOnly)
        XCTAssertNil(restored.items.first?.photo)
    }

    func testMalformedBackupsRejectBeforeMutationAndDoNotOverwrite() throws {
        let source = try LocaliserStore(inMemory: true)
        let parent = try source.addPlace(name: "Room")
        let child = try source.addPlace(name: "Drawer", parent: parent)
        try source.addItem(name: "Keys", place: child)
        let good = try source.backup()
        let target = try LocaliserStore(inMemory: true)
        var bad = good
        bad.records.append(good.records[0])
        XCTAssertThrowsError(try target.restore(bad))
        XCTAssertTrue(try target.backup().records.filter { $0.entity != "Home" }.isEmpty)
        bad = good
        let index = try XCTUnwrap(bad.records.firstIndex { $0.entity == "Belonging" })
        bad.records[index].relationships["place"] = [UUID()]
        XCTAssertThrowsError(try target.restore(bad))
        XCTAssertTrue(target.items.isEmpty)
        bad = good
        let p = try XCTUnwrap(bad.records.firstIndex { $0.id == parent.id })
        let c = try XCTUnwrap(bad.records.firstIndex { $0.id == child.id })
        bad.records[p].relationships["parent"] = [child.id]
        bad.records[c].relationships["children"] = [parent.id]
        XCTAssertThrowsError(try target.restore(bad))
        XCTAssertTrue(target.places.isEmpty)
        bad = good; bad.records[index].attributes["name"] = .integer(42)
        XCTAssertThrowsError(try target.restore(bad))
        bad = good; bad.version = LibraryBackup.currentVersion + 1
        XCTAssertThrowsError(try target.restore(bad))
        XCTAssertThrowsError(try LibraryBackup.decoded(Data("broken".utf8))) { XCTAssertEqual($0 as? LocaliserError, .invalidBackup(LibraryBackup.notABackup)) }
        XCTAssertThrowsError(try LibraryBackup.decoded(Data(#"{"version":99,"records":[{"future":true}]}"#.utf8))) { XCTAssertEqual($0 as? LocaliserError, .invalidBackup(LibraryBackup.newerVersion)) }
        XCTAssertThrowsError(try LibraryBackup.decoded(good.encoded().prefix(200))) { XCTAssertEqual($0 as? LocaliserError, .invalidBackup(LibraryBackup.damaged)) }
        bad = good; bad.version = LibraryBackup.currentVersion + 1
        XCTAssertThrowsError(try target.restore(bad)) { XCTAssertEqual($0 as? LocaliserError, .invalidBackup(LibraryBackup.newerVersion)) }
        let existing = try target.addItem(name: "Keep me")
        XCTAssertThrowsError(try target.restore(good)) { XCTAssertEqual($0 as? LocaliserError, .libraryNotEmpty) }
        XCTAssertEqual(target.items.map(\.id), [existing.id])
        // Erase and restore is all or nothing: a bad file leaves the current library untouched.
        XCTAssertThrowsError(try target.restore(bad, replacingExisting: true))
        XCTAssertEqual(target.items.map(\.id), [existing.id])
        try target.restore(good, replacingExisting: true)
        XCTAssertEqual(target.items.map(\.name), ["Keys"])
        XCTAssertEqual(target.items.first?.place?.path, "Room › Drawer")
    }

    func testBackupsFromBeforeV5StillRestore() throws {
        let source = try LocaliserStore(inMemory: true)
        let kit = try source.addKit(name: "Weekend")
        try source.setKitEntry(kit: kit, name: "Socks", item: nil, unit: 1, perNight: true, condition: .always)
        var file = try source.backup()
        for index in file.records.indices { for key in LocaliserStore.laterFields { file.records[index].attributes[key] = nil } }
        let target = try LocaliserStore(inMemory: true)
        try target.restore(file)
        let entry = try XCTUnwrap(target.kits.first?.entries.first)
        XCTAssertTrue(entry.perNight); XCTAssertFalse(entry.perDay); XCTAssertFalse(entry.unlinked)
    }

    func testFreeTierCountsActiveItems() throws {
        let store = try LocaliserStore(inMemory: true)
        try store.addItem(name: "Drill")
        let old = try store.addItem(name: "Old phone")
        try store.setArchived(old, true)
        XCTAssertEqual(store.activeItemCount, 1)
    }

    func testTextLimitsAndDuplicatePlaceWarning() throws {
        let store = try LocaliserStore(inMemory: true)
        XCTAssertThrowsError(try store.addItem(name: String(repeating: "a", count: 121)))
        XCTAssertNoThrow(try store.addItem(name: String(repeating: "a", count: 120)))
        XCTAssertThrowsError(try store.addItem(name: "Notes", notes: String(repeating: "n", count: 5_001)))
        XCTAssertThrowsError(try store.addItem(name: "Aliases", aliases: String(repeating: "x", count: 1_001)))
        XCTAssertEqual(store.items.count, 1)
        let garage = try store.addPlace(name: "Garage")
        XCTAssertEqual(store.duplicatePlace(named: " garage ", parent: nil), garage)
        XCTAssertNil(store.duplicatePlace(named: "Garage", parent: garage))
        XCTAssertNil(store.duplicatePlace(named: "Garage", parent: nil, excluding: garage))
    }

    func testDeletingAnItemCanBeUndone() throws {
        let store = try LocaliserStore(inMemory: true)
        let drawer = try store.addPlace(name: "Drawer")
        let item = try store.addItem(name: "Passport", place: drawer)
        let id = item.id
        try store.move(item, to: nil)
        try store.setDeadline(item: item, kind: .askBack, day: XCTUnwrap(CalendarDay(stored: "2030-01-01")), source: "", leadDays: 0, hour: 9, enabled: true, confirmed: true)
        let kit = try store.addKit(name: "Travel")
        try store.setKitEntry(kit: kit, name: "", item: item, unit: 1, perNight: false, condition: .always)
        try store.deleteItem(item)
        XCTAssertEqual(store.undoableDeletion, "Passport")
        XCTAssertTrue(store.items.isEmpty)
        XCTAssertEqual(kit.entries.first?.unlinked, true)
        try store.undoLastDeletion()
        XCTAssertNil(store.undoableDeletion)
        let back = try XCTUnwrap(store.items.first)
        XCTAssertEqual(back.id, id)
        XCTAssertEqual(back.deadlines.count, 1); XCTAssertEqual(back.movements.count, 1)
        XCTAssertEqual(kit.entries.first?.item, back); XCTAssertEqual(kit.entries.first?.unlinked, false)
        // Any other change closes the undo window.
        try store.deleteItem(back)
        try store.addPlace(name: "Shelf")
        XCTAssertNil(store.undoableDeletion)
        try store.undoLastDeletion()
        XCTAssertTrue(store.items.isEmpty)
        // A fresh store reading the same data agrees.
        XCTAssertEqual(try store.context.count(for: NSFetchRequest<NSFetchRequestResult>(entityName: "Belonging")), 0)
    }

    func testNotificationTappedBeforeLibraryOpensIsReplayed() throws {
        let store = try LocaliserStore(inMemory: true)
        let item = try store.addItem(name: "Headphones")
        let deadline = try XCTUnwrap(store.lend(item, to: "Sam", askBackOn: XCTUnwrap(CalendarDay(.now).adding(days: 5))))
        let previous = UNUserNotificationCenter.current().delegate
        defer { UNUserNotificationCenter.current().delegate = previous }
        let service = ReminderService()
        service.handle(id: deadline.id, action: UNNotificationDefaultActionIdentifier)
        XCTAssertEqual(service.pendingActions.count, 1)
        XCTAssertNil(store.openedItem)
        service.store = store
        XCTAssertTrue(service.pendingActions.isEmpty)
        XCTAssertEqual(store.openedItem, item.id, "Tapping an ask-back reminder opens the thing")
    }

    func testReminderWordingNamesTheItemOnlyWhenAllowed() throws {
        let reminder = PlannedReminder(id: "x", deadlineID: UUID(), fireDate: .now, kind: .askBack, daysBefore: 0, itemName: "Headphones", person: "Sam")
        XCTAssertEqual(reminder.content(showingNames: true).body, "Ask Sam for Headphones back.")
        XCTAssertEqual(reminder.content(showingNames: false).body, "Ask for something back.")
        XCTAssertEqual(reminder.content(showingNames: true).title, "Lent out")
    }

    func testCSVQuotesMultilineTextAndNeutralizesFormulaPrefixes() throws {
        let store = try LocaliserStore(inMemory: true)
        try store.addItem(name: "=SUM(1,2)", notes: "A \"quote\"\nand comma,", aliases: " @command")
        let csv = store.inventoryCSV()
        XCTAssertTrue(csv.contains("\"'=SUM(1,2)\""))
        XCTAssertTrue(csv.contains("\"A \"\"quote\"\"\nand comma,\""))
        XCTAssertTrue(csv.contains("\"'@command\""))
        XCTAssertTrue(csv.hasPrefix("\"id\",\"name\",\"home\",\"place\",\"notes\",\"other names\",\"archived\",\"private\",\"dates\""))
        let kettle = try store.addItem(name: "Kettle")
        try store.lend(kettle, to: "Sam", askBackOn: XCTUnwrap(CalendarDay(stored: "2030-01-01")))
        XCTAssertTrue(store.inventoryCSV().contains("\"Ask for it back 2030-01-01\""))
        XCTAssertEqual(try store.backup().contents, "2 things and 1 date")
        XCTAssertEqual(LibraryBackup(records: []).contents, "An empty notebook")
    }

    /// Writes a return date, a warranty date and a receipt scan straight into the store, the way a version
    /// before 1.0 left them. Returns their ids.
    @discardableResult
    private func addOldRecords(to store: LocaliserStore, item: Belonging) throws -> [UUID] {
        var ids: [UUID] = []
        for (kind, decision) in [("returns", "keeping"), ("warranty", "open")] {
            let deadline = NSEntityDescription.insertNewObject(forEntityName: "Deadline", into: store.context)
            let id = UUID(); ids.append(id)
            deadline.setValue(id, forKey: "id"); deadline.setValue(kind, forKey: "kindRaw"); deadline.setValue(decision, forKey: "decisionRaw")
            deadline.setValue("2030-01-0\(ids.count)", forKey: "dayString"); deadline.setValue("Receipt line", forKey: "source")
            deadline.setValue(Int16(3), forKey: "leadDays"); deadline.setValue(Int16(9), forKey: "hour")
            deadline.setValue(true, forKey: "enabled"); deadline.setValue(item, forKey: "item")
        }
        let scan = NSEntityDescription.insertNewObject(forEntityName: "ScanRecord", into: store.context)
        let scanID = UUID(); ids.append(scanID)
        scan.setValue(scanID, forKey: "id"); scan.setValue(Date.now, forKey: "createdAt"); scan.setValue(true, forKey: "counted")
        scan.setValue("receipt.jpg", forKey: "filename"); scan.setValue("image/jpeg", forKey: "mime"); scan.setValue(Data([9, 8, 7]), forKey: "data")
        scan.setValue(item, forKey: "item")
        try store.context.save()
        try store.refresh()
        return ids
    }

    private func rawRecords(_ store: LocaliserStore) throws -> [UUID: [String: String]] {
        var out: [UUID: [String: String]] = [:]
        for entity in ["Deadline", "ScanRecord"] {
            for object in try store.context.fetch(NSFetchRequest<NSManagedObject>(entityName: entity)) {
                let attributes = object.entity.attributesByName.keys.reduce(into: [String: String]()) { let value = object.value(forKey: $1); $0[$1] = (value as? Data)?.base64EncodedString() ?? String(describing: value ?? "nil") }
                out[object.value(forKey: "id") as! UUID] = attributes
            }
        }
        return out
    }

    func testOldDatesAndScansStayButOnlyAskBackShows() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("test.sqlite")
        let store = try LocaliserStore(url: url)
        let item = try store.addItem(name: "Drill")
        let askBack = try XCTUnwrap(store.lend(item, to: "Sam", askBackOn: CalendarDay(stored: "2030-02-01"))).id
        try addOldRecords(to: store, item: item)
        let before = try rawRecords(store)
        for persistentStore in store.container.persistentStoreCoordinator.persistentStores {
            try? store.container.persistentStoreCoordinator.remove(persistentStore)
        }
        let reopened = try LocaliserStore(url: url)
        defer {
            for persistentStore in reopened.container.persistentStoreCoordinator.persistentStores {
                try? reopened.container.persistentStoreCoordinator.remove(persistentStore)
            }
        }
        XCTAssertEqual(try rawRecords(reopened), before, "Opening the notebook leaves old dates and scans as they were")
        XCTAssertEqual(reopened.deadlines.map(\.id), [askBack])
        let opened = try XCTUnwrap(reopened.items.first)
        XCTAssertEqual(opened.deadlines.count, 3)
        XCTAssertEqual(opened.openAskBack?.id, askBack)
        XCTAssertEqual(opened.deadlines.compactMap(\.reminderInput).map(\.id), [askBack], "Only the ask-back date gets a reminder")
        let recap = Rituals.recap(items: reopened.items, deadlines: Array(opened.deadlines), now: try XCTUnwrap(CalendarDay(stored: "2030-01-30")?.date()))
        XCTAssertEqual(recap.due.map(\.id), [askBack])
        XCTAssertFalse(reopened.inventoryCSV().contains("2030-01-01"))
    }

    func testBackupKeepsOldDatesAndScansExactly() throws {
        let source = try LocaliserStore(inMemory: true)
        let item = try source.addItem(name: "Drill")
        _ = try source.lend(item, to: "Sam", askBackOn: CalendarDay(stored: "2030-02-01"))
        try addOldRecords(to: source, item: item)
        let file = try LibraryBackup.decoded(source.backup(attachmentIDs: Set([item.id] + (try source.context.fetch(NSFetchRequest<NSManagedObject>(entityName: "ScanRecord")).map { $0.value(forKey: "id") as! UUID }))).encoded())
        XCTAssertEqual(file.records.filter { $0.entity == "Deadline" }.count, 3)
        XCTAssertEqual(file.records.filter { $0.entity == "ScanRecord" }.count, 1)
        let restored = try LocaliserStore(inMemory: true)
        try restored.restore(file)
        XCTAssertEqual(try rawRecords(restored), try rawRecords(source))
        XCTAssertEqual(restored.deadlines.count, 1)
    }

    func testLocalPersistenceAndContainerMove() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("test.sqlite")
        let store = try LocaliserStore(url: url)
        defer {
            for persistentStore in store.container.persistentStoreCoordinator.persistentStores {
                try? store.container.persistentStoreCoordinator.remove(persistentStore)
            }
        }
        let room = try store.addPlace(name: "Bedroom")
        let drawer = try store.addPlace(name: "Drawer", parent: room)
        let item = try store.addItem(name: "Passport", place: drawer)
        let office = try store.addPlace(name: "Office")
        try store.editPlace(drawer, name: "Drawer", parent: office)
        XCTAssertEqual(item.place?.path, "Office › Drawer")
        XCTAssertTrue(ItemSearch.results(query: "Bedroom", entries: store.searchIndex, archived: false).isEmpty)
        XCTAssertEqual(ItemSearch.results(query: "Office", entries: store.searchIndex, archived: false).first?.id, item.id)
        let kit = try store.addKit(name: "Travel")
        try store.setKitEntry(kit: kit, name: "", item: item, unit: 1, perNight: false, condition: .always)
        let trip = try store.addTrip(TripDetails(name: "Work trip", start: CalendarDay(.now), end: CalendarDay(.now)), kit: kit)
        try store.pack(try XCTUnwrap(trip.entries.first), count: 1)
        let reopened = try LocaliserStore(url: url)
        defer {
            for persistentStore in reopened.container.persistentStoreCoordinator.persistentStores {
                try? reopened.container.persistentStoreCoordinator.remove(persistentStore)
            }
        }
        XCTAssertEqual(reopened.items.first?.name, "Passport")
        XCTAssertEqual(reopened.items.first?.place?.path, "Office › Drawer")
        XCTAssertEqual(reopened.items.first?.id, item.id)
        XCTAssertEqual(reopened.kits.first?.name, "Travel")
        XCTAssertEqual(reopened.trips.first?.entries.first?.packedCount, 1)
        XCTAssertEqual(reopened.items.first?.packedTrips.first?.name, "Work trip")
    }

    func testPlaceCyclesAndOccupiedDeletionPreserveData() throws {
        let store = try LocaliserStore(inMemory: true)
        let room = try store.addPlace(name: "Room")
        let drawer = try store.addPlace(name: "Drawer", parent: room)
        let item = try store.addItem(name: "Keys", place: room)
        XCTAssertThrowsError(try store.editPlace(room, name: "Room", parent: drawer)) { XCTAssertEqual($0 as? LocaliserError, .placeCycle) }
        XCTAssertThrowsError(try store.deletePlace(room)) { XCTAssertEqual($0 as? LocaliserError, .occupiedPlace) }
        XCTAssertEqual(item.place, room)
        try store.deletePlace(room, clearContents: true)
        XCTAssertNil(item.place)
        XCTAssertNil(drawer.parent)
        XCTAssertEqual(store.items.count, 1)
        XCTAssertEqual(item.movements.first?.fromPath, "Room")
        // A place inside another: what it holds moves up a level, and moving up isn't seeing.
        let kitchen = try store.addPlace(name: "Kitchen")
        let cupboard = try store.addPlace(name: "Cupboard", parent: kitchen)
        let shelf = try store.addPlace(name: "Shelf", parent: cupboard)
        let tin = try store.addItem(name: "Tin", place: cupboard)
        let seen = Date(timeIntervalSinceNow: -120 * 86_400)
        tin.confirmedAt = seen
        // Restored from a backup older than V6: no check date until the next launch fills it in.
        let jar = try store.addItem(name: "Jar", place: cupboard)
        jar.createdAt = seen; jar.confirmedAt = nil
        try store.deletePlace(cupboard, clearContents: true)
        XCTAssertEqual(tin.place, kitchen)
        XCTAssertEqual(shelf.parent, kitchen)
        XCTAssertEqual(tin.confirmedAt, seen)
        XCTAssertEqual(jar.lastConfirmed, seen)
        XCTAssertEqual(tin.movements.map(\.toPath), ["Kitchen"])
    }

    func testTypedPathsFindTheDeepestPlaceThatExists() throws {
        let store = try LocaliserStore(inMemory: true)
        let garage = try store.addPlace(name: "Garage")
        let shelf = try store.addPlace(name: "Shelf", parent: garage)
        XCTAssertEqual(store.deepestExistingPlace(forPath: "garage > shelf"), shelf)
        // The chooser checks this before creating anything, so "Garage › Shelf › Box" can't be made inside Garage
        // while Garage is the place being edited, and nothing is left behind.
        XCTAssertEqual(store.deepestExistingPlace(forPath: "Garage › Shelf › Box"), shelf)
        XCTAssertNil(store.deepestExistingPlace(forPath: "Loft / Box"))
        XCTAssertEqual(store.places.count, 2)
    }

    func testNameOnlyCaptureAndMovementHistory() throws {
        let store = try LocaliserStore(inMemory: true)
        XCTAssertThrowsError(try store.addItem(name: "  "))
        XCTAssertEqual(store.items.count, 0)
        let item = try store.addItem(name: "  Cable  ")
        XCTAssertEqual(item.name, "Cable")
        XCTAssertNil(item.photo)
        let box = try store.addPlace(name: "Box")
        try store.move(item, to: box)
        XCTAssertEqual(item.movements.count, 1)
        try store.move(item, to: box)
        XCTAssertEqual(item.movements.count, 1)
        try store.setArchived(item, true)
        XCTAssertTrue(item.archived)
        XCTAssertEqual(item.place, box)
    }

    func testSearchAndAmbiguousCaptureSuggestions() {
        XCTAssertEqual(ItemSearch.score(query: "passport", name: "Passport", aliases: "Travel ID", place: "Drawer", notes: ""), 1000)
        XCTAssertEqual(ItemSearch.score(query: "travel id", name: "Passport", aliases: "Travel ID", place: "Drawer", notes: ""), 950)
        XCTAssertEqual(ItemSearch.score(query: "passprt", name: "Passport", aliases: "", place: "", notes: ""), 600)
        XCTAssertNil(ItemSearch.score(query: "potato", name: "Passport", aliases: "", place: "", notes: ""))
        let id = UUID()
        XCTAssertEqual(ItemSearch.suggestion("Keys are missing", places: []), nil)
        XCTAssertEqual(ItemSearch.suggestion("Keys in Drawer", places: [(id, "Drawer")])?.placeID, id)
        XCTAssertNil(ItemSearch.suggestion("Keys in Drawer", places: [(id, "Drawer"), (UUID(), "Drawer")])?.placeID)
        XCTAssertEqual(ItemSearch.suggestion("Keys in New box", places: [])?.unrecognizedPlace, "New box")
        XCTAssertEqual(ItemSearch.suggestion("Keys in Drawer", places: [(id, "Bedroom › Drawer")])?.placeID, id)
        XCTAssertNil(ItemSearch.suggestion("Keys in Drawer", places: [(id, "Bedroom › Drawer"), (UUID(), "Office › Drawer")])?.placeID)
        XCTAssertEqual(ItemSearch.score(query: "drawr", name: "Keys", aliases: "", place: "Bedroom › Drawer", notes: ""), 500)
        // The editor's own hint has to work.
        let drawer = UUID()
        let hint = ItemSearch.suggestion("passport in the bedroom drawer", places: [(drawer, "Bedroom › Drawer"), (UUID(), "Office › Drawer")])
        XCTAssertEqual(hint, .init(name: "passport", placeID: drawer, unrecognizedPlace: nil))
        XCTAssertEqual(ItemSearch.suggestion("My keys are in the hall closet", places: [(id, "Hall closet")]), .init(name: "keys", placeID: id, unrecognizedPlace: nil))
        XCTAssertEqual(ItemSearch.suggestion("Tent in the loft", places: [])?.unrecognizedPlace, "loft")
    }

    func testOldHistoryIsTrimmedFromTheLibraryFile() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("history-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = try LocaliserStore(url: folder.appendingPathComponent("Localiser.sqlite"))
        try store.addItem(name: "Torch")
        func transactions() throws -> Int {
            let result = try store.context.execute(NSPersistentHistoryChangeRequest.fetchHistory(after: .distantPast)) as? NSPersistentHistoryResult
            return (result?.result as? [NSPersistentHistoryTransaction])?.count ?? 0
        }
        XCTAssertGreaterThan(try transactions(), 0)
        try store.trimHistory(before: .now.addingTimeInterval(1))
        XCTAssertEqual(try transactions(), 0)
        XCTAssertEqual(store.items.map(\.name), ["Torch"], "Trimming history never touches the library itself.")
    }

    func testDateSourcesHaveALimit() throws {
        let store = try LocaliserStore(inMemory: true)
        let item = try store.addItem(name: "Kettle")
        let day = try XCTUnwrap(CalendarDay(stored: "2030-01-01"))
        XCTAssertThrowsError(try store.setDeadline(item: item, kind: .askBack, day: day, source: String(repeating: "a", count: TextLimit.source + 1), leadDays: 3, hour: 9, enabled: true, confirmed: true)) { error in
            XCTAssertEqual(error.localizedDescription, "Source or terms can be up to 2,000 characters.")
        }
        XCTAssertTrue(store.deadlines.isEmpty, "A rejected date never lingers half-made.")
    }

    func testSearchPerformanceAtFiveThousandItems() throws {
        let store = try LocaliserStore(inMemory: true)
        let room = try store.addPlace(name: "Bedroom")
        let drawer = try store.addPlace(name: "Drawer", parent: room)
        for index in 0..<5_000 {
            let item = NSEntityDescription.insertNewObject(forEntityName: "Belonging", into: store.context) as! Belonging
            item.id = UUID(); item.name = index == 0 ? "Passport" : "Household item \(index)"
            item.aliases = index == 0 ? "Travel ID" : "Spare object \(index)"
            item.notes = "Saved household belonging"; item.place = drawer
            item.archived = index % 20 == 19; item.createdAt = Date(timeIntervalSince1970: Double(index))
        }
        try store.context.save(); try store.refresh()
        let passport = try XCTUnwrap(store.items.first { $0.name == "Passport" })
        for query in ["passport", "travel id", "passprt", "drawr", "potato"] {
            var slowest = 0.0
            for _ in 0..<5 {
                let start = ContinuousClock.now
                let matches = ItemSearch.results(query: query, entries: store.searchIndex, archived: false)
                let elapsed = start.duration(to: .now).components
                let milliseconds = Double(elapsed.seconds) * 1_000 + Double(elapsed.attoseconds) / 1e15
                slowest = max(slowest, milliseconds)
                if query == "potato" { XCTAssertTrue(matches.isEmpty) }
                else if query == "drawr" { XCTAssertEqual(matches.count, 4_750) }
                else { XCTAssertEqual(matches.first?.id, passport.id) }
            }
            print("SEARCH_5000 \(query): slowest of five = \(slowest) ms")
            #if !DEBUG
            XCTAssertLessThan(slowest, 50, "5,000-item query '\(query)' exceeded the planned 50 ms target. Use an optimized physical build for performance acceptance.")
            #endif
        }
        try store.editItem(passport, name: "Permit", place: nil, notes: "Personal paperwork", aliases: "Travel document", photo: nil)
        XCTAssertTrue(ItemSearch.results(query: "passport", entries: store.searchIndex, archived: false).isEmpty)
        XCTAssertEqual(ItemSearch.results(query: "travel document", entries: store.searchIndex, archived: false).first?.id, passport.id)
        XCTAssertEqual(ItemSearch.results(query: "personal paperwork", entries: store.searchIndex, archived: false).first?.id, passport.id)
        try store.setArchived(passport, true)
        XCTAssertTrue(ItemSearch.results(query: "permit", entries: store.searchIndex, archived: false).isEmpty)
        XCTAssertEqual(ItemSearch.results(query: "permit", entries: store.searchIndex, archived: true).first?.id, passport.id)
        try store.deleteItem(passport)
        XCTAssertTrue(ItemSearch.results(query: "permit", entries: store.searchIndex, archived: true).isEmpty)
    }

    func testMigrationPreservesExistingItemPhotoAndPlace() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("migration.sqlite")
        let modelURL = try XCTUnwrap(Bundle.main.url(forResource: "LocaliserV1", withExtension: "mom", subdirectory: "Localiser.momd"))
        let model = try XCTUnwrap(NSManagedObjectModel(contentsOf: modelURL))
        let old = NSPersistentContainer(name: "Localiser", managedObjectModel: model)
        let description = NSPersistentStoreDescription(url: url)
        description.shouldAddStoreAsynchronously = false
        old.persistentStoreDescriptions = [description]
        var loadError: Error?
        old.loadPersistentStores { _, error in loadError = error }
        if let loadError { throw loadError }
        let room = NSEntityDescription.insertNewObject(forEntityName: "Place", into: old.viewContext)
        room.setValue(UUID(), forKey: "id"); room.setValue("Drawer", forKey: "name")
        let item = NSEntityDescription.insertNewObject(forEntityName: "Belonging", into: old.viewContext)
        let id = UUID(); let photo = Data([1, 2, 3])
        item.setValue(id, forKey: "id"); item.setValue("Old passport", forKey: "name")
        item.setValue(Date(), forKey: "createdAt"); item.setValue(photo, forKey: "photo"); item.setValue(room, forKey: "place")
        try old.viewContext.save()
        old.viewContext.reset()
        for persistentStore in old.persistentStoreCoordinator.persistentStores { try old.persistentStoreCoordinator.remove(persistentStore) }
        let migrated = try LocaliserStore(url: url)
        defer { for persistentStore in migrated.container.persistentStoreCoordinator.persistentStores { try? migrated.container.persistentStoreCoordinator.remove(persistentStore) } }
        XCTAssertEqual(migrated.items.first?.id, id)
        XCTAssertEqual(migrated.items.first?.photo, photo)
        XCTAssertEqual(migrated.items.first?.place?.path, "Drawer")
        XCTAssertEqual(migrated.items.first?.deadlines.count, 0)
        XCTAssertTrue(migrated.deadlines.isEmpty)
    }

    func testAskBackDatesNeedConfirmationAndStopWhenArchived() throws {
        let store = try LocaliserStore(inMemory: true)
        let item = try store.addItem(name: "Coat")
        let day = try XCTUnwrap(CalendarDay(stored: "2027-06-01"))
        XCTAssertThrowsError(try store.setDeadline(item: item, kind: .askBack, day: day, source: "", leadDays: 0, hour: 9, enabled: true, confirmed: false))
        XCTAssertTrue(store.deadlines.isEmpty)
        let askBack = try XCTUnwrap(store.lend(item, to: "Sam", askBackOn: day))
        XCTAssertTrue(askBack.active)
        try store.setArchived(item, true)
        XCTAssertFalse(askBack.active)
        XCTAssertNil(askBack.reminderInput)
    }

    func testReminderDatesRespectCalendarDaysDSTAndReturnedThings() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/Vancouver"))
        let day = try XCTUnwrap(CalendarDay(stored: "2026-03-09"))
        let now = try XCTUnwrap(CalendarDay(stored: "2026-03-01")?.date(calendar: calendar))
        let id = UUID()
        var input = ReminderInput(id: id, day: day, kind: .askBack, leadDays: 2, hour: 9, enabled: true, archived: false, decision: .open)
        let requests = ReminderPlan.candidates([input], now: now, calendar: calendar)
        XCTAssertEqual(requests.count, 2)
        XCTAssertEqual(CalendarDay(requests[0].fireDate, calendar: calendar).stored, "2026-03-07")
        XCTAssertEqual(calendar.component(.hour, from: requests[0].fireDate), 9)
        XCTAssertEqual(requests[1].fireDate.timeIntervalSince(requests[0].fireDate), 47 * 3600)
        input.decision = .returned
        XCTAssertTrue(ReminderPlan.candidates([input], now: now, calendar: calendar).isEmpty)
        input.decision = .open
        XCTAssertEqual(ReminderPlan.candidates([input], now: now, calendar: calendar).count, 2)
        input.enabled = false
        XCTAssertTrue(ReminderPlan.candidates([input], now: now, calendar: calendar).isEmpty)
        XCTAssertNil(CalendarDay(stored: "2026-02-30"))
        let many = (0..<70).map { _ in ReminderInput(id: UUID(), day: day, kind: .askBack, leadDays: 0, hour: 9, enabled: true, archived: false, decision: .open) }
        XCTAssertEqual(ReminderPlan.candidates(many, now: now, calendar: calendar).count, 70)
    }

    func testSystemNotificationQueueCapsCoverageAndRemovesStaleRequests() async throws {
        #if targetEnvironment(simulator)
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .denied { throw XCTSkip("Use a dedicated simulator with notification permission available; do not change the owner's device settings.") }
        if settings.authorizationStatus == .notDetermined {
            _ = try await center.requestAuthorization(options: [.provisional, .alert, .sound])
        }
        let authorized = await center.notificationSettings().authorizationStatus
        XCTAssertTrue([.authorized, .provisional, .ephemeral].contains(authorized))
        let previousDelegate = center.delegate
        let previousNames = UserDefaults.standard.object(forKey: ReminderService.showNamesKey)
        UserDefaults.standard.set(false, forKey: ReminderService.showNamesKey)
        defer { UserDefaults.standard.set(previousNames, forKey: ReminderService.showNamesKey) }
        let store = try LocaliserStore(inMemory: true)
        let service = ReminderService(); service.store = store
        let foreignID = "localiser.verification.\(UUID().uuidString)"
        let foreignContent = UNMutableNotificationContent(); foreignContent.title = "Unrelated test request"
        try await center.add(UNNotificationRequest(identifier: foreignID, content: foreignContent, trigger: UNTimeIntervalNotificationTrigger(timeInterval: 86400, repeats: false)))
        defer { center.removePendingNotificationRequests(withIdentifiers: [foreignID]); center.delegate = previousDelegate }
        let today = CalendarDay(.now)
        for offset in 2...71 {
            let item = try store.addItem(name: "Private document 12345")
            try store.lend(item, to: "Sensitive person", askBackOn: XCTUnwrap(today.adding(days: offset)))
        }
        func verifyQueue() async throws -> [UNNotificationRequest] {
            let candidates = ReminderPlan.candidates(store.deadlines.compactMap(\.reminderInput))
            let expected = Set(candidates.prefix(50).map(\.id))
            service.refresh(store.deadlines)
            var requests: [UNNotificationRequest] = []
            for _ in 0..<100 {
                requests = await center.pendingNotificationRequests()
                let actual = Set(requests.filter { $0.identifier.hasPrefix("localiser.deadline.") }.map(\.identifier))
                if actual == expected && Set(service.scheduled.map(\.id)) == expected && service.candidateCount == candidates.count { break }
                try await Task.sleep(for: .milliseconds(50))
            }
            XCTAssertEqual(Set(requests.filter { $0.identifier.hasPrefix("localiser.deadline.") }.map(\.identifier)), expected)
            XCTAssertEqual(Set(service.scheduled.map(\.id)), expected)
            XCTAssertEqual(service.candidateCount, candidates.count)
            XCTAssertNil(service.error)
            XCTAssertTrue(requests.contains { $0.identifier == foreignID })
            return requests.filter { $0.identifier.hasPrefix("localiser.deadline.") }
        }
        let initial = try await verifyQueue()
        XCTAssertEqual(initial.count, 50); XCTAssertEqual(service.candidateCount, 70)
        for request in initial {
            XCTAssertFalse(request.content.body.contains("12345")); XCTAssertFalse(request.content.body.contains("Sensitive"))
            XCTAssertEqual(request.content.title, "Lent out")
            XCTAssertEqual(request.content.body, "Ask for something back.")
            XCTAssertEqual(request.content.categoryIdentifier, "", "No notification buttons")
            let trigger = try XCTUnwrap(request.trigger as? UNCalendarNotificationTrigger)
            XCTAssertFalse(trigger.repeats); XCTAssertEqual(trigger.dateComponents.hour, 9)
        }
        let first = try XCTUnwrap(store.deadlines.min { $0.dayString < $1.dayString })
        let firstID = first.id
        try store.setDeadline(item: XCTUnwrap(first.item), kind: .askBack, day: XCTUnwrap(today.adding(days: 200)), source: "", leadDays: 0, hour: 10, enabled: true, confirmed: true, existing: first)
        let edited = try await verifyQueue()
        XCTAssertFalse(edited.contains { $0.content.userInfo["deadlineID"] as? String == firstID.uuidString })
        for deadline in store.deadlines { try store.deleteDeadline(deadline) }
        let empty = try await verifyQueue()
        XCTAssertTrue(empty.isEmpty)
        let lent = try store.addItem(name: "Private drill 12345")
        let askBack = try XCTUnwrap(store.lend(lent, to: "Sam", askBackOn: XCTUnwrap(today.adding(days: 3))))
        let open = try await verifyQueue()
        XCTAssertEqual(open.map { $0.content.userInfo["deadlineID"] as? String }, [askBack.id.uuidString])
        try store.askAgainNextWeek(askBack)
        let later = try await verifyQueue()
        XCTAssertEqual(later.count, 1)
        try store.gotBack(lent)
        let returned = try await verifyQueue()
        XCTAssertTrue(returned.isEmpty)
        #else
        throw XCTSkip("This test requests quiet notification permission only on disposable simulators. Physical notification testing requires owner interaction.")
        #endif
    }

    func testOnDeviceOCRReadsTextInAPhotoOfAThing() async throws {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1200, height: 300), format: format)
        let image = renderer.image { context in
            UIColor.white.setFill(); context.fill(CGRect(x: 0, y: 0, width: 1200, height: 300))
            ("Cordless drill" as NSString).draw(at: CGPoint(x: 40, y: 100), withAttributes: [.font: UIFont.systemFont(ofSize: 70), .foregroundColor: UIColor.black])
        }
        let data = try XCTUnwrap(image.pngData())
        let text = try await Task.detached { try PhotoText.read(data) }.value
        XCTAssertTrue(text.contains("Cordless drill"), text)
        XCTAssertTrue(PhotoText.containsDate("Expiry 2028-07-14"))
        XCTAssertFalse(PhotoText.containsDate("Cordless drill"))
        XCTAssertThrowsError(try PhotoText.read(Data([0, 1])))
    }

    func testKitCopiesIndependentTripProgressAndKeepsManualCounts() throws {
        let store = try LocaliserStore(inMemory: true)
        let home = try store.addPlace(name: "Drawer")
        let item = try store.addItem(name: "Passport", place: home)
        let kit = try store.addKit(name: "Travel")
        try store.setKitEntry(kit: kit, name: "", item: item, unit: 1, perNight: false, condition: .always)
        let socks = try store.setKitEntry(kit: kit, name: "Socks", item: nil, unit: 1, perNight: true, condition: .always)
        try store.setKitEntry(kit: kit, name: "Boarding pass", item: nil, unit: 1, perNight: false, condition: .flying)
        let start = try XCTUnwrap(CalendarDay(stored: "2026-03-07"))
        let end = try XCTUnwrap(CalendarDay(stored: "2026-03-09"))
        let trip = try store.addTrip(TripDetails(name: "First", start: start, end: end), kit: kit)
        let second = try store.addTrip(TripDetails(name: "Second", start: start, end: end), kit: kit)
        let passport = try XCTUnwrap(trip.entries.first { $0.item == item })
        let tripSocks = try XCTUnwrap(trip.entries.first { $0.name == "Socks" })
        XCTAssertEqual(trip.details?.nights, 2)
        XCTAssertEqual(tripSocks.requiredCount, 2)
        XCTAssertEqual(trip.entries.first { $0.name == "Boarding pass" }?.requiredCount, 0)
        try store.pack(passport, count: 1); try store.pack(tripSocks, count: 2)
        XCTAssertEqual(second.entries.first { $0.item == item }?.packedCount, 0)
        XCTAssertEqual(item.place, home)
        try store.setKitEntry(kit: kit, existing: socks, name: "Socks", item: nil, unit: 3, perNight: true, condition: .always)
        XCTAssertEqual(tripSocks.unitQuantity, 1)
        try store.editTrip(trip, details: TripDetails(name: "First", start: start, end: try XCTUnwrap(CalendarDay(stored: "2026-03-10")), flying: true))
        XCTAssertEqual(tripSocks.requiredCount, 3); XCTAssertEqual(tripSocks.packedCount, 2)
        XCTAssertEqual(trip.entries.first { $0.name == "Boarding pass" }?.requiredCount, 1)
        try store.setTripQuantity(tripSocks, override: 5)
        try store.editTrip(trip, details: TripDetails(name: "First", start: start, end: start))
        XCTAssertEqual(trip.details?.nights, 0); XCTAssertEqual(tripSocks.requiredCount, 5); XCTAssertEqual(tripSocks.packedCount, 2)
    }

    func testPerDayRowsCoverDayTrips() throws {
        let store = try LocaliserStore(inMemory: true)
        let kit = try store.addKit(name: "Away")
        try store.setKitEntry(kit: kit, name: "Snacks", item: nil, unit: 2, perNight: false, perDay: true, condition: .always)
        try store.setKitEntry(kit: kit, name: "Pyjamas", item: nil, unit: 1, perNight: true, condition: .always)
        let day = try XCTUnwrap(CalendarDay(stored: "2026-05-01"))
        let dayTrip = try store.addTrip(TripDetails(name: "Beach", start: day, end: day), kit: kit)
        XCTAssertEqual(dayTrip.entries.first { $0.name == "Snacks" }?.requiredCount, 2)
        XCTAssertEqual(dayTrip.entries.first { $0.name == "Pyjamas" }?.requiredCount, 0)
        let weekend = try store.addTrip(TripDetails(name: "Weekend", start: day, end: XCTUnwrap(CalendarDay(stored: "2026-05-03"))), kit: kit)
        XCTAssertEqual(weekend.entries.first { $0.name == "Snacks" }?.requiredCount, 6)
        XCTAssertEqual(weekend.entries.first { $0.name == "Pyjamas" }?.requiredCount, 2)
        XCTAssertEqual(weekend.entries.first { $0.name == "Snacks" }?.perDay, true)
    }

    func testPackingConflictsCancellationAndDateEdits() throws {
        let store = try LocaliserStore(inMemory: true)
        let home = try store.addPlace(name: "Drawer")
        let item = try store.addItem(name: "Passport", place: home)
        let kit = try store.addKit(name: "Travel")
        try store.setKitEntry(kit: kit, name: "", item: item, unit: 1, perNight: false, condition: .always)
        let first = try store.addTrip(TripDetails(name: "First", start: try XCTUnwrap(CalendarDay(stored: "2027-04-01")), end: try XCTUnwrap(CalendarDay(stored: "2027-04-04"))), kit: kit)
        let second = try store.addTrip(TripDetails(name: "Second", start: try XCTUnwrap(CalendarDay(stored: "2027-04-03")), end: try XCTUnwrap(CalendarDay(stored: "2027-04-07"))), kit: kit)
        let third = try store.addTrip(TripDetails(name: "Third", start: try XCTUnwrap(CalendarDay(stored: "2027-04-10")), end: try XCTUnwrap(CalendarDay(stored: "2027-04-15"))), kit: kit)
        try store.pack(try XCTUnwrap(first.entries.first), count: 1)
        let secondEntry = try XCTUnwrap(second.entries.first)
        XCTAssertThrowsError(try store.pack(secondEntry, count: 1))
        XCTAssertEqual(secondEntry.packedCount, 0)
        try store.changeTripState(first, to: .canceled)
        try store.pack(secondEntry, count: 1)
        let thirdEntry = try XCTUnwrap(third.entries.first)
        try store.pack(thirdEntry, count: 1)
        XCTAssertThrowsError(try store.editTrip(third, details: TripDetails(name: "Third", start: try XCTUnwrap(CalendarDay(stored: "2027-04-05")), end: try XCTUnwrap(CalendarDay(stored: "2027-04-13")))))
        XCTAssertEqual(third.startDay, "2027-04-10")
        try store.deleteTrip(second)
        XCTAssertEqual(item.place, home)
        try store.setArchived(item, true)
        XCTAssertThrowsError(try store.pack(thirdEntry, count: 1))
        XCTAssertTrue(try store.addTrip(TripDetails(name: "New", start: CalendarDay(.now), end: CalendarDay(.now)), kit: kit).entries.isEmpty)
    }

    func testComingHomeNeedsExplicitResolutionIncludingFreeRows() throws {
        let store = try LocaliserStore(inMemory: true)
        let home = try store.addPlace(name: "Drawer")
        let hall = try store.addPlace(name: "Hall")
        let item = try store.addItem(name: "Passport", place: home)
        let kit = try store.addKit(name: "Travel")
        try store.setKitEntry(kit: kit, name: "", item: item, unit: 1, perNight: false, condition: .always)
        try store.setKitEntry(kit: kit, name: "Clothes", item: nil, unit: 1, perNight: false, condition: .always)
        let trip = try store.addTrip(TripDetails(name: "Trip", start: CalendarDay(.now), end: CalendarDay(.now)), kit: kit)
        for entry in trip.entries { try store.pack(entry, count: entry.requiredCount) }
        XCTAssertThrowsError(try store.changeTripState(trip, to: .away))
        for task in trip.tasks { try store.checkTask(task, checked: true) }
        try store.changeTripState(trip, to: .away)
        XCTAssertEqual(item.place, home)
        try store.changeTripState(trip, to: .comingHome)
        XCTAssertEqual(trip.unresolvedEntries.count, 2)
        let linked = try XCTUnwrap(trip.entries.first { $0.item != nil })
        try store.resolveHome(linked, resolution: .unresolved)
        XCTAssertEqual(item.place, home)
        XCTAssertThrowsError(try store.changeTripState(trip, to: .finished))
        try store.resolveHome(linked, resolution: .newPlace, newPlace: hall)
        try store.resolveHome(try XCTUnwrap(trip.entries.first { $0.item == nil }), resolution: .putBack)
        try store.changeTripState(trip, to: .finished)
        XCTAssertEqual(item.place, hall); XCTAssertTrue(item.packedTrips.isEmpty)
        XCTAssertEqual(item.movements.count, 1)
    }

    func testPuttingAThingBackCountsAsSeeingIt() throws {
        let store = try LocaliserStore(inMemory: true)
        let drawer = try store.addPlace(name: "Drawer")
        let item = try store.addItem(name: "Passport", place: drawer)
        let kit = try store.addKit(name: "Travel")
        try store.setKitEntry(kit: kit, name: "", item: item, unit: 1, perNight: false, condition: .always)
        let trip = try store.addTrip(TripDetails(name: "Trip", start: CalendarDay(.now), end: CalendarDay(.now)), kit: kit)
        for entry in trip.entries { try store.pack(entry, count: entry.requiredCount) }
        for task in trip.tasks { try store.checkTask(task, checked: true) }
        try store.changeTripState(trip, to: .away)
        try store.changeTripState(trip, to: .comingHome)
        let weekAgo = Date.now.addingTimeInterval(-7 * 86_400)
        item.confirmedAt = weekAgo
        try store.resolveHome(XCTUnwrap(trip.entries.first { $0.item != nil }), resolution: .putBack)
        XCTAssertEqual(item.place, drawer)
        XCTAssertTrue(item.movements.isEmpty, "Back where it lives isn't a move.")
        XCTAssertGreaterThan(try XCTUnwrap(item.confirmedAt), weekAgo)
    }

    func testReturnedPackedItemCanBeResolvedWithoutPuttingItBack() throws {
        let store = try LocaliserStore(inMemory: true)
        let item = try store.addItem(name: "Camera")
        let kit = try store.addKit(name: "Travel")
        try store.setKitEntry(kit: kit, name: "", item: item, unit: 1, perNight: false, condition: .always)
        let trip = try store.addTrip(TripDetails(name: "Trip", start: CalendarDay(.now), end: CalendarDay(.now)), kit: kit)
        let entry = try XCTUnwrap(trip.entries.first)
        try store.pack(entry, count: 1)
        let returns = try store.setDeadline(item: item, kind: .askBack, day: CalendarDay(.now), source: "", leadDays: 0, hour: 9, enabled: true, confirmed: true)
        try store.setArchived(item, true)
        try store.changeTripState(trip, to: .comingHome)
        XCTAssertThrowsError(try store.resolveHome(entry, resolution: .putBack))
        try store.resolveHome(entry, resolution: .noLongerHere)
        try store.changeTripState(trip, to: .finished)
        XCTAssertTrue(item.archived); XCTAssertFalse(returns.active)
        try store.editItem(item, name: "Renamed camera", place: nil, notes: "", aliases: "", photo: nil)
        try store.deleteItem(item)
        XCTAssertTrue(store.items.isEmpty); XCTAssertTrue(store.deadlines.isEmpty)
        XCTAssertNil(entry.item); XCTAssertEqual(entry.name, "Renamed camera"); XCTAssertTrue(entry.unlinked)
        XCTAssertEqual(kit.entries.first?.name, "Renamed camera")
        XCTAssertNil(kit.entries.first?.item)
        XCTAssertFalse(try store.backup().records.contains { ["Belonging", "Deadline", "Movement", "ScanRecord"].contains($0.entity) })
    }

    func testReplayingTheIntroductionAtTheLimitSaysWhy() {
        let free = ProAccess()
        let atLimit = free.allows(.item, count: CreationKind.item.freeLimit)
        XCTAssertEqual(OnboardingView.refusal(rewriting: false, allowed: atLimit), ItemEditor.freePlanFull)
        XCTAssertNil(OnboardingView.refusal(rewriting: true, allowed: atLimit), "Rewriting the thing it just wrote is fine")
        XCTAssertNil(OnboardingView.refusal(rewriting: false, allowed: free.allows(.item, count: CreationKind.item.freeLimit - 1)))
        XCTAssertNil(OnboardingView.refusal(rewriting: false, allowed: true), "Pro allows any number")
    }

    func testBothTypefaceLicencesLoadFromTheBundle() throws {
        XCTAssertEqual(Typeface.all.map(\.name), ["Atkinson Hyperlegible", "Fraunces"])
        for face in Typeface.all {
            let text = try XCTUnwrap(face.licence(), "\(face.name) licence is missing from the bundle")
            XCTAssertTrue(text.contains("SIL OPEN FONT LICENSE Version 1.1"), face.name)
            XCTAssertTrue(face.copyright.hasPrefix("Copyright"), face.name)
        }
    }

    // MARK: Automatic backups (M59)

    /// A backup maker pointed at a fresh folder and a private defaults suite, with its own clock.
    private func backupMaker(pro: Bool = true, folder: URL? = nil, at start: Date = Date(timeIntervalSince1970: 1_800_000_000)) throws -> (maker: AutomaticBackups, clock: Clock, folder: URL) {
        let folder = folder ?? FileManager.default.temporaryDirectory.appendingPathComponent("AutoBackups-\(UUID().uuidString)")
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "AutoBackups.\(UUID().uuidString)"))
        let clock = Clock(now: start)
        return (AutomaticBackups(folder: folder, now: { clock.now }, isPro: pro, defaults: defaults), clock, folder)
    }
    final class Clock { var now: Date; init(now: Date) { self.now = now } }
    private func backupFiles(_ folder: URL) -> [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []).sorted()
    }

    func testAutomaticBackupsRunWeeklyAndNeverTwiceInADay() throws {
        let store = try LocaliserStore(inMemory: true)
        _ = try store.addItem(name: "Passport", place: nil)
        let (maker, clock, folder) = try backupMaker()
        guard case .wrote = maker.runIfDue(store: store) else { return XCTFail("The first backup is due straight away") }
        XCTAssertEqual(backupFiles(folder).count, 1)
        for days in [1.0, 3.0, 6.9] {
            clock.now = Date(timeIntervalSince1970: 1_800_000_000).addingTimeInterval(days * 86_400)
            guard case .skipped = maker.runIfDue(store: store) else { return XCTFail("Not due after \(days) days") }
        }
        clock.now = Date(timeIntervalSince1970: 1_800_000_000).addingTimeInterval(7 * 86_400)
        guard case .wrote = maker.runIfDue(store: store) else { return XCTFail("Due after a week") }
        XCTAssertEqual(backupFiles(folder).count, 2)
        guard case .skipped = maker.runIfDue(store: store) else { return XCTFail("Never twice in a day") }
        XCTAssertEqual(maker.lastBackup, clock.now)
    }

    func testAutomaticBackupsKeepTheNewestFive() throws {
        let store = try LocaliserStore(inMemory: true)
        _ = try store.addItem(name: "Passport", place: nil)
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let (maker, clock, folder) = try backupMaker(at: start)
        for week in 0..<8 {
            clock.now = start.addingTimeInterval(Double(week) * 7 * 86_400)
            guard case .wrote = maker.runIfDue(store: store) else { return XCTFail("Week \(week) should write") }
        }
        let files = backupFiles(folder)
        XCTAssertEqual(files.count, 5)
        XCTAssertEqual(maker.saved().map(\.date), (3..<8).reversed().map { start.addingTimeInterval(Double($0) * 7 * 86_400) }, "The five newest stay, newest first")
        XCTAssertEqual(files, files.sorted(), "Names sort by date")
    }

    func testLapsedProAndTheSwitchStopNewBackupsButKeepOldOnes() throws {
        let store = try LocaliserStore(inMemory: true)
        _ = try store.addItem(name: "Passport", place: nil)
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let (pro, clock, folder) = try backupMaker(at: start)
        guard case .wrote = pro.runIfDue(store: store) else { return XCTFail() }
        let before = backupFiles(folder)
        clock.now = start.addingTimeInterval(30 * 86_400)
        var lapsed = pro; lapsed.isPro = false
        guard case .skipped = lapsed.runIfDue(store: store) else { return XCTFail("Lapsed Pro makes no new backup") }
        XCTAssertEqual(backupFiles(folder), before, "Saved backups are never deleted")
        pro.enabled = false
        guard case .skipped = pro.runIfDue(store: store) else { return XCTFail("Switched off") }
        XCTAssertEqual(backupFiles(folder), before)
    }

    func testASavedBackupRestoresIntoAFreshNotebook() throws {
        let store = try LocaliserStore(inMemory: true)
        _ = try store.addItem(name: "Passport", place: nil)
        let (maker, _, _) = try backupMaker()
        guard case .wrote = maker.runIfDue(store: store) else { return XCTFail() }
        let saved = try XCTUnwrap(maker.saved().first)
        let file = try maker.load(saved)
        let fresh = try LocaliserStore(inMemory: true)
        try fresh.validateBackup(file)
        try fresh.restore(file)
        XCTAssertEqual(fresh.items.map(\.name), ["Passport"])
    }

    func testAFailedWriteLeavesOlderBackupsAlone() throws {
        let store = try LocaliserStore(inMemory: true)
        _ = try store.addItem(name: "Passport", place: nil)
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let (good, clock, folder) = try backupMaker(at: start)
        for week in 0..<5 {
            clock.now = start.addingTimeInterval(Double(week) * 7 * 86_400)
            _ = good.runIfDue(store: store)
        }
        let before = backupFiles(folder)
        XCTAssertEqual(before.count, 5)
        struct DiskFull: Error {}
        var failing = good
        failing.write = { _, _ in throw DiskFull() }
        clock.now = start.addingTimeInterval(6 * 7 * 86_400)
        guard case .failed = failing.runIfDue(store: store) else { return XCTFail("The write fails") }
        XCTAssertEqual(backupFiles(folder), before, "Nothing is pruned when the new one didn't land")
        guard case .skipped = good.runIfDue(store: store) else { return XCTFail("A failed try isn't retried the same day") }
    }
}
