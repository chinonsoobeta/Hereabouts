import XCTest
@testable import Localiser

@MainActor
final class AppLinkTests: XCTestCase {
    func testLinksRoundTrip() throws {
        let id = UUID()
        for link in [AppLink.find, .new, .putAway, .due, .item(id)] { XCTAssertEqual(AppLink(url: link.url), link) }
        XCTAssertEqual(AppLink(url: URL(string: "hereabouts://due")!), .due)
        XCTAssertNil(AppLink(url: URL(string: "hereabouts://item/not-an-id")!))
        XCTAssertNil(AppLink(url: URL(string: "https://find")!))
        XCTAssertNil(AppLink(url: URL(string: "hereabouts://elsewhere")!))
    }

    func testAppIconShortcutsAreFixedLinks() throws {
        let items = try XCTUnwrap(Bundle.main.object(forInfoDictionaryKey: "UIApplicationShortcutItems") as? [[String: Any]])
        let links = items.compactMap { ($0["UIApplicationShortcutItemType"] as? String).flatMap(URL.init(string:)).flatMap(AppLink.init(url:)) }
        XCTAssertEqual(links, [.find, .putAway, .due])
        XCTAssertTrue(QuickActions.shared.handle(UIApplicationShortcutItem(type: "hereabouts://due", localizedTitle: "What's due")))
        XCTAssertEqual(QuickActions.shared.link, .due)
        XCTAssertFalse(QuickActions.shared.handle(UIApplicationShortcutItem(type: "recent.thing", localizedTitle: "Passport")))
        QuickActions.shared.link = nil
    }

    func testSendWhereItIs() throws {
        let store = try LocaliserStore(inMemory: true)
        let bowl = try store.addPlace(name: "Key bowl", parent: try store.addPlace(name: "Hall"))
        let key = try store.addItem(name: "Spare key", place: bowl)
        XCTAssertEqual(key.whereItIsSentence, "Spare key is in Hall › Key bowl.")
        let drill = try store.addItem(name: "Drill", place: bowl)
        drill.lentTo = "Sam"
        XCTAssertEqual(drill.whereItIsSentence, "Drill is with Sam.")
        XCTAssertNil(try store.addItem(name: "Torch").whereItIsSentence)
    }
}
