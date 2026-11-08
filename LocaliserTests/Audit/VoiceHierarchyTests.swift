import XCTest
@testable import Localiser

extension AuditCodexTests {
    func testVoiceDoesNotMatchAReversedPlaceHierarchy() throws {
        let shelf = VoiceParser.Candidate(id: UUID(), path: ["Hall", "Box", "Shelf"])
        let result = try XCTUnwrap(VoiceParser().parse("key in box on shelf in hall", places: [shelf]))
        XCTAssertNotEqual(result.placeID, shelf.id,
                          "The person named a box on a shelf, not a shelf inside a box")
    }
}
