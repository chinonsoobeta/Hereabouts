import XCTest
@testable import Localiser

final class OrderEmailTests: XCTestCase {
    func testUSOrderEmail() {
        let text = """
        Thanks for your order!
        Order placed: October 3, 2026
        Arriving Oct 7, 2026
        You can return this item until November 6, 2026.
        """
        let found = OrderEmail.read(text)
        XCTAssertEqual(found.map(\.candidate.day.stored), ["2026-11-06", "2026-10-07", "2026-10-03"])
        XCTAssertEqual(found.map(\.role), [.returnBy, .delivered, .ordered])
        XCTAssertEqual(found[1].anchorType, "Delivery date")
        XCTAssertEqual(found[2].anchorType, "Purchase date")
        XCTAssertNil(found[0].anchorType)
        XCTAssertFalse(found.contains { $0.candidate.ambiguous })
    }

    func testUKOrderEmail() {
        let text = """
        Your order has been delivered
        Delivered: Tuesday, 7 October 2026
        Return by 6 Nov. 2026 for a full refund.
        Order date 3/10/2026
        """
        let found = OrderEmail.read(text)
        XCTAssertEqual(found.first?.candidate.day.stored, "2026-11-06")
        XCTAssertEqual(found.first?.role, .returnBy)
        XCTAssertEqual(found.first { $0.role == .delivered }?.candidate.day.stored, "2026-10-07")
        // 3/10/2026 could be 10 March or 3 October: both are offered and flagged.
        let ordered = found.filter { $0.role == .ordered }
        XCTAssertEqual(Set(ordered.map(\.candidate.day.stored)), ["2026-03-10", "2026-10-03"])
        XCTAssertTrue(ordered.allSatisfy(\.candidate.ambiguous))
    }

    func testTextWithoutADate() {
        XCTAssertTrue(OrderEmail.read("Thanks for shopping with us. Your parcel is on its way.").isEmpty)
        XCTAssertTrue(OrderEmail.read("").isEmpty)
    }

    func testVeryLongTextIsCut() {
        let text = String(repeating: "a", count: OrderEmail.maximumCharacters) + "\nReturn by 6 November 2026"
        XCTAssertTrue(OrderEmail.read(text).isEmpty)
    }
}
