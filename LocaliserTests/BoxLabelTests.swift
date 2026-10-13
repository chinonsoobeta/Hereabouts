import XCTest
import PDFKit
import CoreImage
@testable import Localiser

@MainActor
final class BoxLabelTests: XCTestCase {
    func testPlaceLinksParse() {
        let id = UUID()
        XCTAssertEqual(AppLink(url: AppLink.place(id).url), .place(id))
        XCTAssertNil(AppLink(url: URL(string: "hereabouts://place/garage")!))
    }

    func testEightLabelsToAPage() throws {
        let store = try LocaliserStore(inMemory: true)
        let places = try (1...9).map { try store.addPlace(name: "Box \($0)") }
        for (count, pages) in [(1, 1), (8, 1), (9, 2)] {
            let data = BoxLabels.pdf(for: Array(places.prefix(count)), paper: .a4, listContents: false)
            XCTAssertEqual(PDFDocument(data: data)?.pageCount, pages, "\(count) labels")
        }
        let letter = try XCTUnwrap(PDFDocument(data: BoxLabels.pdf(for: [places[0]], paper: .letter, listContents: true))?.page(at: 0))
        XCTAssertEqual(letter.bounds(for: .mediaBox).size, CGSize(width: 612, height: 792))
    }

    func testLabelsShowNamesAndLeavePrivateThingsOff() throws {
        let store = try LocaliserStore(inMemory: true)
        let box = try store.addPlace(name: "Kitchen box", parent: try store.addPlace(name: "Loft"))
        try store.addItem(name: "Teapot", place: box)
        try store.addItem(name: "Jewellery", place: box, isPrivate: true)
        let text = try XCTUnwrap(PDFDocument(data: BoxLabels.pdf(for: [box], paper: .a4, listContents: true))?.string)
        XCTAssertTrue(text.contains("Kitchen box"), text)
        XCTAssertTrue(text.contains("Loft › Kitchen box"), text)
        XCTAssertTrue(text.contains("Teapot"), text)
        XCTAssertFalse(text.contains("Jewellery"), text)
        let plain = try XCTUnwrap(PDFDocument(data: BoxLabels.pdf(for: [box], paper: .a4, listContents: false))?.string)
        XCTAssertFalse(plain.contains("Teapot"), "Contents are off by default")
    }

    func testPaperFollowsTheRegionAndTheCodeHoldsOnlyTheLink() throws {
        XCTAssertEqual(BoxLabels.Paper.usual(for: Locale.Region("US")), .letter)
        XCTAssertEqual(BoxLabels.Paper.usual(for: Locale.Region("GB")), .a4)
        let id = UUID()
        let image = try XCTUnwrap(BoxLabels.qrCode(for: AppLink.place(id).url, size: 300)?.cgImage)
        let detector = try XCTUnwrap(CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: nil))
        let feature = try XCTUnwrap(detector.features(in: CIImage(cgImage: image)).first as? CIQRCodeFeature)
        XCTAssertEqual(feature.messageString, "hereabouts://place/\(id.uuidString)")
    }
}
