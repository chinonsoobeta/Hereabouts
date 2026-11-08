import XCTest
@testable import Localiser

extension AuditCodexTests {
    func testRestoreDoesNotAllocateOneThingToOverlappingTrips() throws {
        let source = try LocaliserStore(inMemory: true)
        let item = try source.addItem(name: "Camera")
        let firstDay = try XCTUnwrap(CalendarDay(stored: "2030-06-01"))
        let secondDay = try XCTUnwrap(CalendarDay(stored: "2030-07-01"))
        let first = try source.addTrip(TripDetails(name: "June", start: firstDay, end: firstDay))
        let second = try source.addTrip(TripDetails(name: "July", start: secondDay, end: secondDay))
        for trip in [first, second] {
            try source.addTripEntry(trip, name: "", item: item)
            try source.pack(try XCTUnwrap(trip.entries.first), count: 1)
        }
        var file = try source.backup()
        let index = try XCTUnwrap(file.records.firstIndex { $0.id == second.id })
        file.records[index].attributes["startDay"] = .string(firstDay.stored)
        file.records[index].attributes["endDay"] = .string(firstDay.stored)
        let target = try LocaliserStore(inMemory: true)
        do { try target.restore(try LibraryBackup.decoded(file.encoded())) }
        catch let error as LocaliserError {
            if case .invalidBackup = error { return }
            throw error
        }
        let restored = try XCTUnwrap(target.items.first { $0.id == item.id })
        let allocations = restored.packedTrips
        XCTAssertFalse(allocations.enumerated().contains { index, trip in
            allocations.dropFirst(index + 1).contains { trip.overlaps($0) }
        }, "A restore must not bypass the packing conflict check used by ordinary packing and trip edits")
    }
}
