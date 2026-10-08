import XCTest
import CoreData
import UIKit
import PDFKit
import StoreKit
import StoreKitTest
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
        _ = try XCTUnwrap(pro.product, "StoreKit did not load the local test product; do not enter an Apple account.")
        XCTAssertFalse(pro.unlocked)
        XCTAssertTrue(pro.allows(.item, count: 49)); XCTAssertFalse(pro.allows(.item, count: 50))
        XCTAssertTrue(pro.allows(.kit, count: 0)); XCTAssertFalse(pro.allows(.kit, count: 1))
        XCTAssertTrue(pro.allows(.scan, count: 2)); XCTAssertFalse(pro.allows(.scan, count: 3))
        let store = try LocaliserStore(inMemory: true)
        let item = try store.addItem(name: "Keep after refund")
        await pro.purchase()
        XCTAssertTrue(pro.unlocked, pro.message ?? "No purchase message")
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
        XCTAssertEqual(try store.backup().records.count, 1)
        try store.editItem(item, name: "Editable after refund", place: nil, notes: "", aliases: "", photo: nil)
        XCTAssertEqual(item.name, "Editable after refund")
    }

    func testCanceledFailedAndPendingPurchasesDoNotUnlock() async throws {
        if #unavailable(iOS 27) { throw XCTSkip("iOS 26.5's local StoreKit test service rejects configuration (SKInternalErrorDomain 3). Verify this test on iOS 27; signed-device sandbox purchase testing remains required.") }
        let file = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "Localiser", withExtension: "storekit"))
        let session = try SKTestSession(contentsOf: file)
        session.resetToDefaultState(); session.disableDialogs = true; session.clearTransactions()
        defer { session.clearTransactions(); session.resetToDefaultState() }
        let pro = ProAccess(); await pro.loadProduct()
        _ = try XCTUnwrap(pro.product, "StoreKit did not load the local test product; do not enter an Apple account.")
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
        XCTAssertEqual(pro.message, "Purchase awaiting approval. Free features remain available.")
    }

    func testBackupRoundTripPreservesFilesDatesHistoryAndPacking() throws {
        let source = try LocaliserStore(inMemory: true)
        let room = try source.addPlace(name: "Bedroom")
        let drawer = try source.addPlace(name: "Drawer", parent: room)
        let item = try source.addItem(name: "Passport", place: room, notes: "Travel", aliases: "ID", photo: Data([1, 2]))
        try source.move(item, to: drawer)
        let day = try XCTUnwrap(CalendarDay(stored: "2028-07-14"))
        let scan = ScanDraft(data: Data([3, 4]), filename: "Receipt.png", mime: "image/png", preview: nil, text: "Expiry 2028-07-14", candidates: ScanDates.candidates("Expiry 2028-07-14"))
        try source.setDeadline(item: item, kind: .expiry, day: day, source: "Confirmed", leadDays: 180, hour: 9, enabled: true, confirmed: true, scan: scan, retainSource: true)
        let kit = try source.addKit(name: "Travel")
        try source.setKitEntry(kit: kit, name: "", item: item, unit: 1, perNight: false, condition: .always)
        let trip = try source.addTrip(TripDetails(name: "Trip", start: day, end: day), kit: kit)
        try source.pack(try XCTUnwrap(trip.entries.first), count: 1)
        try source.checkTask(try XCTUnwrap(trip.tasks.first), checked: true)
        let scanID = try XCTUnwrap(item.scans.first?.id)
        let file = try LibraryBackup.decoded(source.backup(attachmentIDs: [item.id, scanID]).encoded())
        XCTAssertEqual(Set(file.records.map(\.entity)).count, 11)
        let restored = try LocaliserStore(inMemory: true)
        try restored.restore(file)
        XCTAssertEqual(restored.items.first?.id, item.id)
        XCTAssertEqual(restored.items.first?.place?.path, "Bedroom › Drawer")
        XCTAssertEqual(restored.items.first?.photo, Data([1, 2]))
        XCTAssertEqual(restored.items.first?.scans.first?.data, Data([3, 4]))
        XCTAssertEqual(restored.items.first?.movements.count, 1)
        XCTAssertEqual(restored.deadlines.first?.dayString, day.stored)
        XCTAssertEqual(restored.completedScans, 1)
        XCTAssertEqual(restored.trips.first?.entries.first?.packedCount, 1)
        XCTAssertEqual(restored.trips.first?.tasks.filter(\.checked).count, 1)
        XCTAssertEqual(restored.items.first?.packedTrips.first?.id, trip.id)
        XCTAssertFalse(restored.syncEnabled)
        XCTAssertNil(restored.container.persistentStoreDescriptions.first?.cloudKitContainerOptions)
        let dateOnly = try source.backup()
        XCTAssertFalse(dateOnly.records.contains { $0.attributes.values.contains { if case .data = $0 { true } else { false } } })
        try restored.resetLibrary()
        XCTAssertTrue(try restored.backup().records.isEmpty)
        try restored.restore(dateOnly)
        XCTAssertNil(restored.items.first?.photo)
        XCTAssertNil(restored.items.first?.scans.first?.data)
        XCTAssertEqual(restored.completedScans, 1)
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
        XCTAssertTrue(try target.backup().records.isEmpty)
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
        bad = good; bad.version = 2
        XCTAssertThrowsError(try target.restore(bad))
        XCTAssertThrowsError(try LibraryBackup.decoded(Data("broken".utf8)))
        let existing = try target.addItem(name: "Keep me")
        XCTAssertThrowsError(try target.restore(good)) { XCTAssertEqual($0 as? LocaliserError, .libraryNotEmpty) }
        XCTAssertEqual(target.items.map(\.id), [existing.id])
    }

    func testCSVQuotesMultilineTextAndNeutralizesFormulaPrefixes() throws {
        let store = try LocaliserStore(inMemory: true)
        try store.addItem(name: "=SUM(1,2)", notes: "A \"quote\"\nand comma,", aliases: " @command")
        let csv = store.inventoryCSV()
        XCTAssertTrue(csv.contains("\"'=SUM(1,2)\""))
        XCTAssertTrue(csv.contains("\"A \"\"quote\"\"\nand comma,\""))
        XCTAssertTrue(csv.contains("\"' @command\""))
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

    func testConfirmationAndKeepingPreserveOtherDates() throws {
        let store = try LocaliserStore(inMemory: true)
        let item = try store.addItem(name: "Coat")
        let day = try XCTUnwrap(CalendarDay(stored: "2027-06-01"))
        XCTAssertThrowsError(try store.setDeadline(item: item, kind: .returns, day: day, source: "", leadDays: 3, hour: 9, enabled: true, confirmed: false))
        XCTAssertTrue(store.deadlines.isEmpty)
        let returns = try store.setDeadline(item: item, kind: .returns, day: day, source: "Receipt terms", leadDays: 3, hour: 9, enabled: true, confirmed: true)
        let warranty = try store.setDeadline(item: item, kind: .warranty, day: day, source: "", leadDays: 30, hour: 9, enabled: true, confirmed: true)
        let expiry = try store.setDeadline(item: item, kind: .expiry, day: day, source: "", leadDays: 180, hour: 9, enabled: true, confirmed: true)
        try store.decide(returns, .returning)
        XCTAssertTrue(returns.active)
        try store.decide(returns, .keeping)
        XCTAssertFalse(returns.active)
        XCTAssertTrue(warranty.active); XCTAssertTrue(expiry.active)
        XCTAssertThrowsError(try store.setDeadline(item: item, kind: .returns, day: day, source: "", leadDays: 3, hour: 9, enabled: true, confirmed: true, existing: returns))
        try store.setDeadline(item: item, kind: .returns, day: day, source: "", leadDays: 3, hour: 9, enabled: true, confirmed: true, existing: returns, reopen: true)
        XCTAssertTrue(returns.active)
        try store.decide(returns, .returned)
        XCTAssertTrue(item.archived)
        XCTAssertFalse(warranty.active); XCTAssertFalse(expiry.active)
    }

    func testReminderDatesRespectCalendarDaysDSTAndClosedReturns() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/Vancouver"))
        let day = try XCTUnwrap(CalendarDay(stored: "2026-03-09"))
        let now = try XCTUnwrap(CalendarDay(stored: "2026-03-01")?.date(calendar: calendar))
        let id = UUID()
        var input = ReminderInput(id: id, day: day, kind: .returns, leadDays: 2, hour: 9, enabled: true, archived: false, decision: .open)
        let requests = ReminderPlan.candidates([input], now: now, calendar: calendar)
        XCTAssertEqual(requests.count, 2)
        XCTAssertEqual(CalendarDay(requests[0].fireDate, calendar: calendar).stored, "2026-03-07")
        XCTAssertEqual(calendar.component(.hour, from: requests[0].fireDate), 9)
        XCTAssertEqual(requests[1].fireDate.timeIntervalSince(requests[0].fireDate), 47 * 3600)
        input.decision = .keeping
        XCTAssertTrue(ReminderPlan.candidates([input], now: now, calendar: calendar).isEmpty)
        input.kind = .warranty
        XCTAssertEqual(ReminderPlan.candidates([input], now: now, calendar: calendar).count, 2)
        input.enabled = false
        XCTAssertTrue(ReminderPlan.candidates([input], now: now, calendar: calendar).isEmpty)
        XCTAssertNil(CalendarDay(stored: "2026-02-30"))
        let many = (0..<70).map { _ in ReminderInput(id: UUID(), day: day, kind: .returns, leadDays: 0, hour: 9, enabled: true, archived: false, decision: .open) }
        XCTAssertEqual(ReminderPlan.candidates(many, now: now, calendar: calendar).count, 70)
    }

    func testScanAmbiguityInvalidDatesAndPrivacyOnConfirmation() throws {
        let candidates = ScanDates.candidates("Expiry 04/05/26\nWarranty ends 2027-02-30\nReturn by 14 January 2028")
        XCTAssertEqual(candidates.count, 3)
        XCTAssertEqual(Set(candidates.prefix(2).map { $0.day.stored }), ["2026-04-05", "2026-05-04"])
        XCTAssertTrue(candidates[0].ambiguous)
        XCTAssertEqual(candidates.last?.hint, .returns)
        let store = try LocaliserStore(inMemory: true)
        let item = try store.addItem(name: "Document")
        let scan = ScanDraft(data: Data([1, 2, 3]), filename: "ID-12345.pdf", mime: "application/pdf", preview: nil, text: "ID 12345 Expiry 04/05/26", candidates: candidates)
        let day = candidates[0].day
        XCTAssertThrowsError(try store.setDeadline(item: item, kind: .expiry, day: day, source: "", leadDays: 180, hour: 9, enabled: true, confirmed: false, scan: scan))
        XCTAssertEqual(store.completedScans, 0); XCTAssertTrue(item.scans.isEmpty)
        try store.setDeadline(item: item, kind: .expiry, day: day, source: "Confirmed from scan", leadDays: 180, hour: 9, enabled: true, confirmed: true, scan: scan)
        XCTAssertEqual(store.completedScans, 1)
        XCTAssertNil(item.scans.first?.data); XCTAssertEqual(item.scans.first?.filename, "Date-only scan")
        try store.setDeadline(item: item, kind: .expiry, day: day, source: "", leadDays: 180, hour: 9, enabled: true, confirmed: true, scan: scan, retainSource: true)
        let retained = try XCTUnwrap(item.scans.first { $0.data != nil })
        XCTAssertEqual(retained.data, scan.data)
        try store.removeScanSource(retained)
        XCTAssertNil(retained.data); XCTAssertEqual(store.completedScans, 2)
        let blank = ScanDraft(data: Data([0]), filename: "Blank.jpg", mime: "image/jpeg", preview: nil, text: "", candidates: [])
        try store.setDeadline(item: item, kind: .expiry, day: day, source: "", leadDays: 180, hour: 9, enabled: true, confirmed: true, scan: blank)
        XCTAssertEqual(store.completedScans, 2)
    }

    func testOnDeviceOCRReadsPrintedExpiryAndPDFLimits() async throws {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1200, height: 300), format: format)
        let image = renderer.image { context in
            UIColor.white.setFill(); context.fill(CGRect(x: 0, y: 0, width: 1200, height: 300))
            ("Expiry 2028-07-14" as NSString).draw(at: CGPoint(x: 40, y: 100), withAttributes: [.font: UIFont.systemFont(ofSize: 70), .foregroundColor: UIColor.black])
        }
        let data = try XCTUnwrap(image.pngData())
        let result = try await Task.detached { try ScanReader.read(data: data, filename: "Photo.jpg", mime: "image/jpeg") }.value
        XCTAssertTrue(result.candidates.contains { $0.day.stored == "2028-07-14" && $0.hint == .expiry })
        XCTAssertEqual(result.mime, "image/png")
        let pdf = PDFDocument()
        for index in 0..<11 { pdf.insert(try XCTUnwrap(PDFPage(image: image)), at: index) }
        let pdfData = try XCTUnwrap(pdf.dataRepresentation())
        XCTAssertThrowsError(try ScanReader.read(data: pdfData, filename: "Too many.pdf", mime: "application/pdf"))
        XCTAssertThrowsError(try ScanReader.read(data: Data([0, 1]), filename: "Broken.pdf", mime: "application/pdf"))
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

    func testReturnedPackedItemCanBeResolvedWithoutPuttingItBack() throws {
        let store = try LocaliserStore(inMemory: true)
        let item = try store.addItem(name: "Camera")
        let kit = try store.addKit(name: "Travel")
        try store.setKitEntry(kit: kit, name: "", item: item, unit: 1, perNight: false, condition: .always)
        let trip = try store.addTrip(TripDetails(name: "Trip", start: CalendarDay(.now), end: CalendarDay(.now)), kit: kit)
        let entry = try XCTUnwrap(trip.entries.first)
        try store.pack(entry, count: 1)
        let returns = try store.setDeadline(item: item, kind: .returns, day: CalendarDay(.now), source: "", leadDays: 3, hour: 9, enabled: true, confirmed: true)
        try store.decide(returns, .returned)
        try store.changeTripState(trip, to: .comingHome)
        XCTAssertThrowsError(try store.resolveHome(entry, resolution: .putBack))
        try store.resolveHome(entry, resolution: .noLongerHere)
        try store.changeTripState(trip, to: .finished)
        XCTAssertTrue(item.archived); XCTAssertFalse(returns.active)
        try store.editItem(item, name: "Renamed camera", place: nil, notes: "", aliases: "", photo: nil)
        try store.deleteItem(item)
        XCTAssertTrue(store.items.isEmpty); XCTAssertTrue(store.deadlines.isEmpty)
        XCTAssertNil(entry.item); XCTAssertEqual(entry.name, "Renamed camera")
        XCTAssertEqual(kit.entries.first?.name, "Renamed camera")
        XCTAssertNil(kit.entries.first?.item)
        XCTAssertFalse(try store.backup().records.contains { ["Belonging", "Deadline", "Movement", "ScanRecord"].contains($0.entity) })
    }
}
