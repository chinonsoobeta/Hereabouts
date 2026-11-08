import XCTest
@testable import Localiser

/// Adversarial audit, Claude's half (M64). Each test fails on the code as audited and passes once its finding is fixed.
/// Findings and severities are in Docs/AUDIT_CLAUDE.md.
@MainActor
final class AuditClaudeTests: XCTestCase {
    /// Finding 1. Deleting a place says "Everything inside moves to" its parent. A thing packed for a trip from that place
    /// does move up, but the trip forgets where it lives, so "Put back" on coming home leaves it with no place at all.
    func testPuttingBackAPackedThingAfterItsPlaceIsDeletedKeepsAPlace() throws {
        let store = try LocaliserStore(inMemory: true)
        let hall = try store.addPlace(name: "Hall")
        let drawer = try store.addPlace(name: "Drawer", parent: hall)
        let charger = try store.addItem(name: "Charger", place: drawer)
        let today = CalendarDay(.now)
        let trip = try store.addTrip(TripDetails(name: "Weekend", start: today, end: try XCTUnwrap(today.adding(days: 2))))
        try store.addTripEntry(trip, name: "", item: charger)
        let entry = try XCTUnwrap(trip.entries.first { $0.item == charger })
        try store.pack(entry, count: 1)
        try store.changeTripState(trip, to: .comingHome)

        try store.deletePlace(drawer, clearContents: true)
        XCTAssertEqual(charger.place, hall, "Deleting the drawer moves what's inside up to the hall")

        try store.resolveHome(entry, resolution: .putBack)
        XCTAssertEqual(charger.place, hall, "Put back left the charger with no place")
    }

    /// Finding 2. Siri and Shortcuts find a private thing only by its name, so its place or notes don't give it away.
    /// A blank search skips that rule and lists private things to anyone picking a thing in Shortcuts.
    func testABlankSiriSearchDoesNotListPrivateThings() throws {
        let store = try LocaliserStore(inMemory: true)
        _ = try store.addItem(name: "Torch")
        let ring = try store.addItem(name: "Grandma's ring", isPrivate: true)
        for blank in ["", " ", "\n"] {
            XCTAssertFalse(ThingQuery.matches(blank, in: store).contains(ring), "A blank search (\(blank.debugDescription)) listed a private thing")
        }
        XCTAssertTrue(ThingQuery.matches("ring", in: store).contains(ring), "Asking by name still finds it")
    }

    /// Finding 3. A weekly backup made while the phone's clock was ahead (set by hand, or a dead battery's wrong date)
    /// stores that future date. Once the clock is right again, no automatic backup is due until the clock catches up,
    /// which can be months or years, and nothing tells the person.
    func testAutomaticBackupsAreDueAgainOnceTheClockIsCorrected() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("AuditBackups-\(UUID().uuidString)")
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let yearAhead = now.addingTimeInterval(365 * 86_400).timeIntervalSince1970

        let afterBackup = try XCTUnwrap(UserDefaults(suiteName: "Audit.\(UUID().uuidString)"))
        afterBackup.set(yearAhead, forKey: AutomaticBackups.lastKey)
        XCTAssertTrue(AutomaticBackups(folder: folder, now: { now }, isPro: true, defaults: afterBackup).isDue(),
                      "A last backup dated a year ahead stops automatic backups for a year")

        let afterAttempt = try XCTUnwrap(UserDefaults(suiteName: "Audit.\(UUID().uuidString)"))
        afterAttempt.set(yearAhead, forKey: AutomaticBackups.attemptKey)
        XCTAssertTrue(AutomaticBackups(folder: folder, now: { now }, isPro: true, defaults: afterAttempt).isDue(),
                      "A failed try dated a year ahead stops automatic backups for a year")
    }
}
