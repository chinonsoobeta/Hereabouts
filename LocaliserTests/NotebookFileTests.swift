import XCTest
import CoreData
@testable import Localiser

@MainActor final class NotebookFileTests: XCTestCase {
    private var folder: URL!
    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("NotebookFile-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: folder) }

    private func ledger() -> HistoryLedger {
        let name = "NotebookFileTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        addTeardownBlock { defaults.removePersistentDomain(forName: name) }
        return HistoryLedger(defaults: defaults)
    }

    func testMovingANotebookKeepsEveryRecordAndPhoto() throws {
        let source = folder.appendingPathComponent("Old/Localiser.sqlite")
        let destination = folder.appendingPathComponent("Group/Localiser.sqlite")
        let big = Data((0..<300_000).map { UInt8($0 % 251) })
        do {
            let store = try LocaliserStore(url: source)
            let shelf = try store.addPlace(name: "Shelf")
            try store.addItem(name: "Camera", place: shelf, photo: big)
            try store.addItem(name: "Lens", place: shelf)
            try store.addKit(name: "Weekend")
        }
        XCTAssertEqual(try NotebookFile.move(from: source, to: destination), .moved)
        let moved = try LocaliserStore(url: destination)
        XCTAssertEqual(Set(moved.items.map(\.name)), ["Camera", "Lens"])
        XCTAssertEqual(moved.items.first { $0.name == "Camera" }?.photo, big)
        XCTAssertEqual(moved.kits.count, 1)
        XCTAssertEqual(moved.homes.count, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path), "The original stays until a later launch")
    }

    func testMovingTwiceIsHarmless() throws {
        let source = folder.appendingPathComponent("Old/Localiser.sqlite")
        let destination = folder.appendingPathComponent("Group/Localiser.sqlite")
        XCTAssertEqual(try NotebookFile.move(from: source, to: destination), .nothingToMove)
        do { let store = try LocaliserStore(url: source); try store.addItem(name: "Keys") }
        XCTAssertEqual(try NotebookFile.move(from: source, to: destination), .moved)
        do { let store = try LocaliserStore(url: destination); try store.addItem(name: "Wallet") }
        XCTAssertEqual(try NotebookFile.move(from: source, to: destination), .alreadyThere)
        XCTAssertEqual(try LocaliserStore(url: destination).items.count, 2, "A second move never overwrites the copy")
        try NotebookFile.removeOriginal(at: source)
        XCTAssertFalse(FileManager.default.fileExists(atPath: source.path))
    }

    func testAChangeFromASecondStoreShowsUp() throws {
        let file = folder.appendingPathComponent("Shared/Localiser.sqlite")
        let app = try LocaliserStore(url: file)
        let ledger = ledger()
        try app.mergeOutsideChanges(ledger: ledger)
        let widget = try LocaliserStore(url: file)
        widget.context.transactionAuthor = "share"
        try widget.addItem(name: "Receipt for kettle")
        XCTAssertEqual(try app.mergeOutsideChanges(ledger: ledger), 1)
        XCTAssertTrue(app.items.contains { $0.name == "Receipt for kettle" })
        XCTAssertEqual(try app.mergeOutsideChanges(ledger: ledger), 0, "Read once")
        try app.addItem(name: "Kettle")
        XCTAssertEqual(try app.mergeOutsideChanges(ledger: ledger), 0, "Its own saves aren't outside changes")
    }

    func testLaunchesMoveTheNotebookOnceThenRemoveTheOriginal() throws {
        let legacy = folder.appendingPathComponent("Old/Localiser.sqlite")
        let group = folder.appendingPathComponent("Group/Localiser.sqlite")
        let defaults = ledger().defaults
        do { let store = try LocaliserStore(url: legacy); try store.addItem(name: "Passport") }
        XCTAssertEqual(NotebookFile.location(legacy: legacy, group: nil, defaults: defaults), legacy, "No App Group yet: nothing moves")
        XCTAssertEqual(NotebookFile.location(legacy: legacy, group: group, defaults: defaults), group)
        XCTAssertTrue(FileManager.default.fileExists(atPath: legacy.path), "Kept for the first launch")
        XCTAssertEqual(try LocaliserStore(url: group).items.map(\.name), ["Passport"])
        XCTAssertEqual(NotebookFile.location(legacy: legacy, group: group, defaults: defaults), group)
        XCTAssertFalse(FileManager.default.fileExists(atPath: legacy.path), "Gone on the next launch")
        XCTAssertNil(NotebookFile.appGroup, "Empty until enrolment")
    }

    func testHistoryIsTrimmedOnlyBehindEveryReader() {
        let ledger = ledger()
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let week = Calendar.current.date(byAdding: .day, value: -7, to: now)!
        XCTAssertEqual(LocaliserStore.historyCutoff(now: now, ledger: ledger), week)
        ledger.defaults.set(["app": now, "widget": now.addingTimeInterval(-30 * 86_400)], forKey: "historyReadDates")
        XCTAssertEqual(LocaliserStore.historyCutoff(now: now, ledger: ledger), now.addingTimeInterval(-30 * 86_400), "A widget a month behind holds the trim back")
    }
}
