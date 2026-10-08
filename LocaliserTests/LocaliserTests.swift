import XCTest
import CoreData
import UIKit
import PDFKit
@testable import Localiser

@MainActor
final class LocaliserTests: XCTestCase {
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
        let reopened = try LocaliserStore(url: url)
        defer {
            for persistentStore in reopened.container.persistentStoreCoordinator.persistentStores {
                try? reopened.container.persistentStoreCoordinator.remove(persistentStore)
            }
        }
        XCTAssertEqual(reopened.items.first?.name, "Passport")
        XCTAssertEqual(reopened.items.first?.place?.path, "Office › Drawer")
        XCTAssertEqual(reopened.items.first?.id, item.id)
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
}
