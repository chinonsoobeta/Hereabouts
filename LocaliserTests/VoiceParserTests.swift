import XCTest
@testable import Localiser

final class VoiceParserTests: XCTestCase {
    private struct Practice: Decodable {
        struct Sentence: Decodable { var text: String; var name: String; var place: String? }
        var places: [String]
        var sentences: [Sentence]
    }

    private func practice() throws -> (Practice, [VoiceParser.Candidate]) {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "voice-practice", withExtension: "json"))
        let practice = try JSONDecoder().decode(Practice.self, from: Data(contentsOf: url))
        let places = practice.places.map { VoiceParser.Candidate(id: UUID(), path: $0.components(separatedBy: " › ")) }
        return (practice, places)
    }

    func testPracticeSentences() throws {
        let (practice, places) = try practice()
        XCTAssertEqual(practice.sentences.count, 50)
        let parser = VoiceParser()
        var right = 0
        var misses: [String] = []
        for sentence in practice.sentences {
            let result = parser.parse(sentence.text, places: places)
            let place = result?.placeID.flatMap { id in places.first { $0.id == id } }?.path.joined(separator: " › ")
            if result?.name.lowercased() == sentence.name.lowercased() && place == sentence.place { right += 1 }
            else { misses.append("\(sentence.text) → \(result?.name ?? "nil") / \(place ?? "nil")") }
            if sentence.place == nil { XCTAssertNil(place, "An unknown place is never filled in: \(sentence.text)") }
        }
        print("Voice practice: \(right) of \(practice.sentences.count) right.\n" + misses.joined(separator: "\n"))
        XCTAssertGreaterThanOrEqual(Double(right) / Double(practice.sentences.count), 0.9, misses.joined(separator: "\n"))
    }

    func testUnknownPlaceSuggestsANewOneInsideWhatMatched() throws {
        let (_, places) = try practice()
        let shelf = try XCTUnwrap(places.first { $0.path == ["Garage", "Shelf"] })
        let result = try XCTUnwrap(VoiceParser().parse("I put the old phone chargers in the red box on the garage shelf", places: places))
        XCTAssertNil(result.placeID)
        XCTAssertEqual(result.newPlaceName, "Red box")
        XCTAssertEqual(result.newPlaceParent, shelf.id)
        XCTAssertEqual(result.unmatchedPlace, "red box on garage shelf")
    }

    func testNoSplitGivesNothing() {
        XCTAssertNil(VoiceParser().parse("passport", places: []))
        XCTAssertNil(VoiceParser().parse("", places: []))
    }

    func testEnglishOnlyForNow() {
        XCTAssertTrue(VoiceCapture.isAvailable(for: Locale(identifier: "en_US")))
        XCTAssertTrue(VoiceCapture.isAvailable(for: Locale(identifier: "en_GB")))
        XCTAssertFalse(VoiceCapture.isAvailable(for: Locale(identifier: "fr_FR")))
        XCTAssertFalse(VoiceCapture.isAvailable(for: Locale(identifier: "es_ES")))
    }

    func testSayLink() {
        XCTAssertEqual(AppLink(url: URL(string: "hereabouts://say")!), .say)
        XCTAssertEqual(AppLink.say.url.absoluteString, "hereabouts://say")
    }
}
