import XCTest
@testable import Localiser

@MainActor
final class PrivateThingsTests: XCTestCase {
    func testPrivateThingsStayOutOfSpotlight() throws {
        let store = try LocaliserStore(inMemory: true)
        let kettle = try store.addItem(name: "Kettle")
        let passport = try store.addItem(name: "Passport", isPrivate: true)
        XCTAssertEqual(Spotlight.indexable(store.items).map(\.id), [kettle.id])
        try store.editItem(kettle, name: "Kettle", place: nil, notes: "", aliases: "", photo: nil, isPrivate: true)
        XCTAssertTrue(Spotlight.indexable(store.items).isEmpty, "Switching to private leaves the index")
        try store.editItem(passport, name: "Passport", place: nil, notes: "", aliases: "", photo: nil)
        XCTAssertTrue(passport.isPrivate, "An edit that doesn't mention privacy leaves it alone")
    }

    func testSiriDoesNotSayWhereAPrivateThingIs() throws {
        let store = try LocaliserStore(inMemory: true)
        let drawer = try store.addPlace(name: "Drawer")
        let passport = try store.addItem(name: "Passport", place: drawer, isPrivate: true)
        let answer = FindThingIntent.answer(for: passport)
        XCTAssertEqual(answer, "That one's private. Open Hereabouts to see it.")
        XCTAssertFalse(answer.contains("Drawer"))
        XCTAssertEqual(ThingEntity(passport).path, "Private")
    }

    func testRemindersCalendarAndSiriLeaveThePrivateNameOut() throws {
        let store = try LocaliserStore(inMemory: true)
        let ring = try store.addItem(name: "Ring", isPrivate: true)
        let day = try XCTUnwrap(CalendarDay(.now).adding(days: 3))
        _ = try store.setDeadline(item: ring, kind: .warranty, day: day, source: "", leadDays: 1, hour: 9, enabled: true, confirmed: true)
        let deadline = try XCTUnwrap(store.deadlines.first)
        let input = try XCTUnwrap(deadline.reminderInput)
        XCTAssertEqual(input.itemName, "")
        let planned = try XCTUnwrap(ReminderPlan.candidates([input], now: .now).first)
        XCTAssertTrue(planned.content(showingNames: true).body.hasPrefix("A saved thing"))
        XCTAssertEqual(CalendarExport.plan(for: deadline)?.title, "Warranty ends")
        let spoken = WhatsDueIntent.answer(for: store.deadlines)
        XCTAssertFalse(spoken.contains("Ring"), spoken)
        XCTAssertTrue(store.inventoryCSV().contains("\"Ring\""), "Exports still include it")
        XCTAssertTrue(store.inventoryCSV().hasPrefix("\"id\",\"name\",\"home\",\"place\",\"notes\",\"other names\",\"archived\",\"private\""))
    }
}
