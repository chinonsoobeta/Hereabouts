import XCTest
import PDFKit
@testable import Localiser

@MainActor final class ShareImportTests: XCTestCase {
    func testSharedTextOffersReturnByFirstAndSavesOntoANewThing() throws {
        let store = try LocaliserStore(inMemory: true)
        let reading = try ShareImport.read(.text("Order placed 2 Oct 2026\nDelivered 4 Oct 2026\nReturn by 3 Nov 2026"))
        XCTAssertNil(reading.scan)
        let first = try XCTUnwrap(reading.found.first)
        XCTAssertEqual(first.candidate.day.stored, "2026-11-03")
        XCTAssertEqual(ShareImport.kind(for: first), .returns)
        let deadline = try store.saveShared(first, kind: .returns, to: nil, newName: "Blue kettle", scan: nil)
        XCTAssertEqual(deadline.item?.name, "Blue kettle")
        XCTAssertEqual(deadline.dayString, "2026-11-03")
        XCTAssertEqual(Int(deadline.leadDays), DeadlineKind.returns.defaultLeadDays)
        XCTAssertTrue(deadline.source.hasPrefix("Shared: Return by"))
    }

    func testASharedPDFReadsOnlyItsFirstFivePagesAndCountsAsAScan() throws {
        let store = try LocaliserStore(inMemory: true)
        let kettle = try store.addItem(name: "Kettle")
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 300, height: 300))
        let data = renderer.pdfData { context in
            for page in 1...7 {
                context.beginPage()
                let line = page == 1 ? "Warranty until 1 Oct 2028" : page == 7 ? "Return by 9 Nov 2026" : "Page \(page)"
                (line as NSString).draw(at: CGPoint(x: 20, y: 20), withAttributes: [.font: UIFont.systemFont(ofSize: 14)])
            }
        }
        let reading = try ShareImport.read(.file(data, filename: "order.pdf", mime: "application/pdf"))
        XCTAssertEqual(reading.found.map(\.candidate.day.stored), ["2028-10-01"], "Page seven isn't read")
        XCTAssertEqual(ShareImport.kind(for: reading.found[0]), .warranty)
        try store.saveShared(reading.found[0], kind: .warranty, to: kettle, newName: "", scan: reading.scan)
        XCTAssertEqual(store.completedScans, 1)
        XCTAssertEqual(store.items.count, 1, "Saved onto the chosen thing")
    }

    func testNothingToFind() throws {
        XCTAssertTrue(try ShareImport.read(.text("Thanks for your order!")).found.isEmpty)
    }
}
