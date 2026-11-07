import XCTest
import CoreData
@testable import Localiser

@MainActor
final class ModelV7Tests: XCTestCase {
    func testV6LibrariesMigrateWithTheirThingsIntact() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("v6.sqlite")
        let modelURL = try XCTUnwrap(Bundle.main.url(forResource: "LocaliserV6", withExtension: "mom", subdirectory: "Localiser.momd"))
        let model = try XCTUnwrap(NSManagedObjectModel(contentsOf: modelURL))
        let old = NSPersistentContainer(name: "Localiser", managedObjectModel: model)
        let description = NSPersistentStoreDescription(url: url)
        description.shouldAddStoreAsynchronously = false
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        old.persistentStoreDescriptions = [description]
        var loadError: Error?
        old.loadPersistentStores { _, error in loadError = error }
        if let loadError { throw loadError }
        let created = Date(timeIntervalSince1970: 1_750_000_000)
        let place = NSEntityDescription.insertNewObject(forEntityName: "Place", into: old.viewContext)
        place.setValue(UUID(), forKey: "id"); place.setValue("Hall", forKey: "name")
        let keys = NSEntityDescription.insertNewObject(forEntityName: "Belonging", into: old.viewContext)
        keys.setValue(UUID(), forKey: "id"); keys.setValue("Keys", forKey: "name"); keys.setValue(created, forKey: "createdAt")
        keys.setValue(created, forKey: "confirmedAt"); keys.setValue(Data([7]), forKey: "photo"); keys.setValue(place, forKey: "place")
        let movement = NSEntityDescription.insertNewObject(forEntityName: "Movement", into: old.viewContext)
        movement.setValue(UUID(), forKey: "id"); movement.setValue(created, forKey: "date"); movement.setValue("Hall", forKey: "toPath"); movement.setValue(keys, forKey: "item")
        try old.viewContext.save()
        old.viewContext.reset()
        for persistentStore in old.persistentStoreCoordinator.persistentStores { try old.persistentStoreCoordinator.remove(persistentStore) }

        let migrated = try LocaliserStore(url: url)
        defer { for persistentStore in migrated.container.persistentStoreCoordinator.persistentStores { try? migrated.container.persistentStoreCoordinator.remove(persistentStore) } }
        let item = try XCTUnwrap(migrated.items.first)
        XCTAssertEqual(item.name, "Keys")
        XCTAssertEqual(item.place?.name, "Hall")
        XCTAssertEqual(item.photo, Data([7]))
        XCTAssertEqual(item.confirmedAt, created)
        XCTAssertFalse(item.isPrivate)
        XCTAssertFalse(item.isLent)
        XCTAssertFalse(item.isMissing)
        XCTAssertEqual(item.movements.first?.kind, .moved)
    }

    func testVersionOneBackupsRestoreIntoV7() throws {
        let source = try LocaliserStore(inMemory: true)
        _ = try source.addItem(name: "Drill", place: try source.addPlace(name: "Shed"))
        var file = try source.backup()
        file.version = 1
        for index in file.records.indices { for key in ["isPrivate", "missingSince", "lentTo", "lentAt", "kindRaw"] { file.records[index].attributes[key] = nil } }
        let target = try LocaliserStore(inMemory: true)
        try target.restore(try LibraryBackup.decoded(file.encoded()))
        let item = try XCTUnwrap(target.items.first)
        XCTAssertEqual(item.place?.name, "Shed")
        XCTAssertFalse(item.isPrivate)
        XCTAssertEqual(item.lentTo, "")
    }

    func testNewFieldsSurviveABackup() throws {
        let source = try LocaliserStore(inMemory: true)
        let item = try source.addItem(name: "Ladder", place: try source.addPlace(name: "Garage"))
        let lentAt = Date(timeIntervalSince1970: 1_760_000_000), missing = Date(timeIntervalSince1970: 1_760_100_000)
        item.isPrivate = true; item.lentTo = "Sam"; item.lentAt = lentAt; item.missingSince = missing
        item.movements.first?.kindRaw = Movement.Kind.lent.rawValue
        try source.save()
        let file = try LibraryBackup.decoded(source.backup().encoded())
        XCTAssertEqual(file.version, LibraryBackup.currentVersion)
        let target = try LocaliserStore(inMemory: true)
        try target.restore(file)
        let restored = try XCTUnwrap(target.items.first)
        XCTAssertTrue(restored.isPrivate)
        XCTAssertEqual(restored.lentTo, "Sam")
        XCTAssertEqual(restored.lentAt, lentAt)
        XCTAssertEqual(restored.missingSince, missing)
        XCTAssertEqual(restored.movements.first?.kind, item.movements.first?.kind)
    }

    func testAskBackIsTheOnlyKindOfDate() {
        XCTAssertEqual(DeadlineKind.allCases, [.askBack])
        XCTAssertEqual(DeadlineKind.askBack.title, "Ask for it back")
    }
}
