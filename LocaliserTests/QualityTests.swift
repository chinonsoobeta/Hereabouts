import XCTest
import CoreData
@testable import Localiser

/// Scores the voice parser and search against the fixtures in `Quality/` (see its README), and times search.
@MainActor final class QualityTests: XCTestCase {
    private struct CaptureFixture: Decodable {
        struct Sentence: Decodable { var text: String; var name: String; var place: String? }
        var threshold: Double
        var places: [String]
        var sentences: [Sentence]
    }

    private struct SearchFixture: Decodable {
        struct Thing: Decodable { var name: String; var aliases: String; var place: String; var notes: String }
        struct Pair: Decodable { var query: String; var expect: String }
        var threshold: Double
        var topN: Int
        var things: [Thing]
        var pairs: [Pair]
    }

    private func fixture<T: Decodable>(_ name: String, as type: T.Type) throws -> T {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: name, withExtension: "json"), "Missing fixture \(name).json")
        return try JSONDecoder().decode(T.self, from: Data(contentsOf: url))
    }

    func testCaptureSentencesThroughTheVoiceParser() throws {
        let fixture = try fixture("quality-capture", as: CaptureFixture.self)
        XCTAssertFalse(fixture.sentences.isEmpty)
        let places = fixture.places.map { VoiceParser.Candidate(id: UUID(), path: $0.components(separatedBy: " › ")) }
        let parser = VoiceParser()
        var right = 0
        var misses: [String] = []
        for sentence in fixture.sentences {
            let result = parser.parse(sentence.text, places: places)
            let place = result?.placeID.flatMap { id in places.first { $0.id == id } }?.path.joined(separator: " › ")
            if result?.name.lowercased() == sentence.name.lowercased() && place == sentence.place { right += 1 }
            else { misses.append("  \(sentence.text) -> \(result?.name ?? "nothing") / \(place ?? "no place"), wanted \(sentence.name) / \(sentence.place ?? "no place")") }
        }
        let score = Double(right) / Double(fixture.sentences.count)
        print("Quality capture: \(right) of \(fixture.sentences.count) right (\(Int(score * 100))%, needs \(Int(fixture.threshold * 100))%)" + (misses.isEmpty ? "" : "\n" + misses.joined(separator: "\n")))
        XCTAssertGreaterThanOrEqual(score, fixture.threshold, misses.joined(separator: "\n"))
    }

    func testSearchPairsFindTheExpectedThing() throws {
        let fixture = try fixture("quality-search", as: SearchFixture.self)
        XCTAssertFalse(fixture.pairs.isEmpty)
        let store = try LocaliserStore(inMemory: true)
        for thing in fixture.things {
            let place = thing.place.isEmpty ? nil : try store.place(forPath: thing.place)
            try store.addItem(name: thing.name, place: place, notes: thing.notes, aliases: thing.aliases)
        }
        var hits = 0
        var misses: [String] = []
        for pair in fixture.pairs {
            let found = ItemSearch.results(query: pair.query, entries: store.searchIndex, archived: false).prefix(fixture.topN).map(\.name)
            if found.contains(pair.expect) { hits += 1 }
            else { misses.append("  \"\(pair.query)\" -> \(found.isEmpty ? "nothing" : found.joined(separator: ", ")), wanted \(pair.expect)") }
        }
        let score = Double(hits) / Double(fixture.pairs.count)
        print("Quality search: \(hits) of \(fixture.pairs.count) found in the first \(fixture.topN) (\(Int(score * 100))%, needs \(Int(fixture.threshold * 100))%)" + (misses.isEmpty ? "" : "\n" + misses.joined(separator: "\n")))
        XCTAssertGreaterThanOrEqual(score, fixture.threshold, misses.joined(separator: "\n"))
    }

    func testSearchSpeedOverAThousandThings() throws {
        let store = try LocaliserStore(inMemory: true)
        let rooms = ["Kitchen", "Garage", "Attic", "Study", "Cellar"]
        let places = try rooms.map { try store.addPlace(name: $0) }
        let words = ["drill", "kettle", "lantern", "passport", "charger", "blanket", "tripod", "ladder", "teapot", "compass"]
        for number in 0..<1_000 {
            let item = NSEntityDescription.insertNewObject(forEntityName: "Belonging", into: store.context) as! Belonging
            item.id = UUID(); item.name = "\(words[number % words.count]) \(number)"; item.notes = ""; item.aliases = ""
            item.createdAt = .now; item.confirmedAt = .now; item.archived = false; item.place = places[number % places.count]; item.home = store.currentHome
        }
        try store.save()
        XCTAssertEqual(store.searchIndex.count, 1_000)
        XCTAssertEqual(ItemSearch.results(query: "lantern 502", entries: store.searchIndex, archived: false).first?.name, "lantern 502")
        measure {
            for query in ["lantern", "kettle 7", "garage ladder", "tripod 99", "pasport"] {
                _ = ItemSearch.results(query: query, entries: store.searchIndex, archived: false)
            }
        }
    }
}
