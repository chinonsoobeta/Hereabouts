import XCTest
import CoreData
@testable import Localiser

@MainActor final class HomesTests: XCTestCase {
    func testANewNotebookHasOneHomeThatEverythingJoins() throws {
        let store = try LocaliserStore(inMemory: true)
        XCTAssertEqual(store.homes.count, 1)
        let home = try XCTUnwrap(store.currentHome)
        let hall = try store.addPlace(name: "Hall")
        let hook = try store.addPlace(name: "Hook", parent: hall)
        let keys = try store.addItem(name: "Keys", place: hook)
        let loose = try store.addItem(name: "Receipt")
        let kit = try store.addKit(name: "Weekend")
        XCTAssertEqual([hall.home, hook.home, keys.home, loose.home, kit.home], [home, home, home, home, home])
        XCTAssertFalse(store.hasSeveralHomes)
    }

    func testListsShowTheCurrentHomeAndSearchCoversAll() throws {
        let store = try LocaliserStore(inMemory: true)
        let flat = try XCTUnwrap(store.currentHome)
        try store.renameHome(flat, to: "The flat")
        let drawer = try store.addPlace(name: "Drawer")
        try store.addItem(name: "Passport", place: drawer)
        let mums = try store.addHome(name: "Mum's house")
        XCTAssertEqual(store.currentHome, mums)
        XCTAssertTrue(store.placesHere.isEmpty)
        XCTAssertTrue(store.itemsHere.isEmpty)
        let loft = try store.addPlace(name: "Loft")
        let tent = try store.addItem(name: "Tent", place: loft)
        XCTAssertEqual(store.placesHere, [loft])
        XCTAssertEqual(store.itemsHere, [tent])
        XCTAssertEqual(store.items.count, 2, "Search and export read every home")
        store.switchHome(to: flat)
        XCTAssertEqual(store.itemsHere.map(\.name), ["Passport"])
        XCTAssertEqual(UserDefaults.standard.string(forKey: Home.nameKey), "The flat")
        XCTAssertTrue(store.inventoryCSV().contains("\"Mum's house\",\"Loft\""))
    }

    func testMovingAThingOrABoxToAnotherHomeTakesItThere() throws {
        let store = try LocaliserStore(inMemory: true)
        let flat = try XCTUnwrap(store.currentHome)
        let cupboard = try store.addPlace(name: "Cupboard")
        let box = try store.addPlace(name: "Box", parent: cupboard)
        let inner = try store.addPlace(name: "Bag", parent: box)
        let lamp = try store.addItem(name: "Lamp", place: inner)
        let drill = try store.addItem(name: "Drill", place: cupboard)
        let mums = try store.addHome(name: "Mum's house")
        let garage = try store.addPlace(name: "Garage")
        try store.move(drill, to: garage)
        XCTAssertEqual(drill.home, mums)
        try store.editPlace(box, name: "Box", parent: garage)
        XCTAssertEqual([box.home, inner.home, lamp.home], [mums, mums, mums])
        XCTAssertEqual(cupboard.home, flat)
        try store.move(lamp, to: nil)
        XCTAssertEqual(lamp.home, mums, "A thing with no place stays in its home")
    }

    func testTypedPathsAndRecentPlacesStayInTheirHome() throws {
        let store = try LocaliserStore(inMemory: true)
        let flat = try XCTUnwrap(store.currentHome)
        let hall = try store.place(forPath: "Hall > Hook")
        try store.addItem(name: "Keys", place: hall)
        let mums = try store.addHome(name: "Mum's house")
        XCTAssertTrue(store.recentPlaces().isEmpty, "Recent places come from the home you're in")
        let mumsHall = try store.place(forPath: "Hall > Hook")
        XCTAssertNotEqual(mumsHall, hall, "The same path in another home is a different place")
        XCTAssertEqual(mumsHall.home, mums)
        XCTAssertEqual(try store.place(forPath: "Hall > Hook", home: flat), hall)
        try store.addItem(name: "Umbrella", place: mumsHall)
        XCTAssertEqual(store.recentPlaces(), [mumsHall])
    }

    func testMovesRecordWhoMadeThem() throws {
        let store = try LocaliserStore(inMemory: true)
        let shed = try store.addPlace(name: "Shed")
        let drill = try store.addItem(name: "Drill")
        try store.move(drill, to: shed)
        XCTAssertNil(drill.movements.first?.byline, "The phone's owner isn't named")
        store.author = "Sam"
        _ = try store.lend(drill, to: "Alex", askBackOn: nil)
        XCTAssertEqual(drill.movements.first { $0.kind == .lent }?.byline, "Sam")
    }

    func testOnlyAnEmptyHomeCanGoAndNeverTheLast() throws {
        let store = try LocaliserStore(inMemory: true)
        let first = try XCTUnwrap(store.currentHome)
        XCTAssertThrowsError(try store.deleteHome(first)) { XCTAssertEqual($0 as? LocaliserError, .lastHome) }
        let boat = try store.addHome(name: "The boat")
        try store.addItem(name: "Life jacket")
        XCTAssertThrowsError(try store.deleteHome(boat)) { XCTAssertEqual($0 as? LocaliserError, .homeNotEmpty) }
        let spare = try store.addHome(name: "Storage unit")
        try store.deleteHome(spare)
        XCTAssertEqual(store.homes.map(\.name), [first.name, "The boat"])
        XCTAssertEqual(store.currentHome, first)
        XCTAssertThrowsError(try store.addHome(name: "  ")) { XCTAssertEqual($0 as? LocaliserError, .nameRequired) }
        XCTAssertThrowsError(try store.addHome(name: String(repeating: "a", count: Home.maxLength + 1)))
    }

    func testFreePlanHoldsTwoHomes() {
        let pro = ProAccess()
        XCTAssertTrue(pro.allows(.home, count: 1))
        XCTAssertFalse(pro.allows(.home, count: 2))
    }

    func testTwoHomesSurviveABackupAndOlderBackupsLandInOneHome() throws {
        let source = try LocaliserStore(inMemory: true)
        try source.addItem(name: "Kettle", place: try source.addPlace(name: "Kitchen"))
        try source.addHome(name: "The boat")
        try source.addItem(name: "Rope", place: try source.addPlace(name: "Deck"))
        let file = try LibraryBackup.decoded(source.backup().encoded())
        XCTAssertEqual(file.version, 3)
        let target = try LocaliserStore(inMemory: true)
        try target.restore(file)
        XCTAssertEqual(target.homes.count, 2, "The fresh notebook's empty home gives way")
        XCTAssertEqual(target.items.first { $0.name == "Rope" }?.home?.name, "The boat")
        XCTAssertEqual(target.places.first { $0.name == "Kitchen" }?.home, target.items.first { $0.name == "Kettle" }?.home)

        var older = file
        older.version = 2
        older.records.removeAll { $0.entity == "Home" }
        for index in older.records.indices { older.records[index].relationships["home"] = nil; older.records[index].attributes["by"] = nil }
        let fresh = try LocaliserStore(inMemory: true)
        try fresh.restore(try LibraryBackup.decoded(older.encoded()))
        XCTAssertEqual(fresh.homes.count, 1)
        XCTAssertTrue(fresh.items.allSatisfy { $0.home == fresh.currentHome })
        XCTAssertTrue(fresh.places.allSatisfy { $0.home == fresh.currentHome })
    }

    func testEraseLeavesOneEmptyHome() throws {
        let store = try LocaliserStore(inMemory: true)
        try store.addHome(name: "The boat")
        try store.addItem(name: "Rope")
        try store.resetLibrary()
        XCTAssertEqual(store.homes.count, 1)
        XCTAssertTrue(store.items.isEmpty)
    }

    func testV7LibrariesMigrateIntoOneHome() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("v7.sqlite")
        let modelURL = try XCTUnwrap(Bundle.main.url(forResource: "LocaliserV7", withExtension: "mom", subdirectory: "Localiser.momd"))
        let old = NSPersistentContainer(name: "Localiser", managedObjectModel: try XCTUnwrap(NSManagedObjectModel(contentsOf: modelURL)))
        let description = NSPersistentStoreDescription(url: url)
        description.shouldAddStoreAsynchronously = false
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        old.persistentStoreDescriptions = [description]
        var loadError: Error?
        old.loadPersistentStores { _, error in loadError = error }
        if let loadError { throw loadError }
        let context = old.viewContext
        func insert(_ entity: String, _ values: [String: Any]) -> NSManagedObject {
            let object = NSEntityDescription.insertNewObject(forEntityName: entity, into: context)
            object.setValue(UUID(), forKey: "id")
            for (key, value) in values { object.setValue(value, forKey: key) }
            return object
        }
        let shed = insert("Place", ["name": "Shed"])
        let shelf = insert("Place", ["name": "Shelf", "parent": shed])
        insert("Belonging", ["name": "Saw", "createdAt": Date(), "place": shelf])
        insert("Belonging", ["name": "Loose", "createdAt": Date()])
        insert("Kit", ["name": "Camping"])
        insert("TripRecord", ["name": "Coast", "startDay": "2026-10-01", "endDay": "2026-10-03"])
        let move = insert("Movement", ["date": Date(), "toPath": "Shed"])
        _ = move
        try context.save()
        context.reset()
        for persistentStore in old.persistentStoreCoordinator.persistentStores { try old.persistentStoreCoordinator.remove(persistentStore) }

        UserDefaults.standard.set("The cottage", forKey: Home.nameKey)
        defer { UserDefaults.standard.removeObject(forKey: Home.nameKey) }
        let migrated = try LocaliserStore(url: url)
        defer { for persistentStore in migrated.container.persistentStoreCoordinator.persistentStores { try? migrated.container.persistentStoreCoordinator.remove(persistentStore) } }
        XCTAssertEqual(migrated.homes.map(\.name), ["The cottage"])
        let home = migrated.homes[0]
        XCTAssertTrue(migrated.places.allSatisfy { $0.home == home })
        XCTAssertTrue(migrated.items.allSatisfy { $0.home == home })
        XCTAssertEqual(migrated.kits.first?.home, home)
        XCTAssertEqual(migrated.trips.first?.home, home)
        let movements = try migrated.context.fetch(NSFetchRequest<Movement>(entityName: "Movement"))
        XCTAssertEqual(movements.first?.by, "")
    }
}
