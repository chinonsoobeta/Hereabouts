import XCTest
@testable import Localiser

/// Send feedback is written in the app and sent to support, with no email to write (owner, 13 Nov). Only what the page
/// shows is sent: the name, the message, an email if one is given, and the app and iOS versions. Nothing from the notebook.
/// The name is required and shown on the form, as Apple's optional-disclosure rule for feedback forms asks, so the
/// App Store label stays Data Not Collected (owner, 13 Nov).
@MainActor
final class FeedbackTests: XCTestCase {
    func testANoteCarriesTheMessageTheOptionalEmailAndTheVersions() throws {
        let note = try Feedback.note(name: " Sam Lee ", message: "  The drill shelf idea is great.\n", email: "  sam@example.com ")
        XCTAssertEqual(note.name, "Sam Lee")
        XCTAssertEqual(note.message, "The drill shelf idea is great.")
        XCTAssertEqual(note.email, "sam@example.com")
        XCTAssertEqual(note.version, Support.version)
        XCTAssertEqual(note.system, "iOS \(UIDevice.current.systemVersion)")
        XCTAssertFalse(note.language.isEmpty)
        XCTAssertNil(try Feedback.note(name: "Sam", message: "Hi", email: "  ").email, "The email is optional")
    }

    func testNoNameABlankMessageALongOneOrABadEmailIsNotSent() {
        XCTAssertThrowsError(try Feedback.note(name: "  ", message: "Hi", email: "")) { XCTAssertEqual($0 as? Feedback.Problem, .noName) }
        XCTAssertThrowsError(try Feedback.note(name: String(repeating: "a", count: Feedback.maximumNameLength + 1), message: "Hi", email: "")) { XCTAssertEqual($0 as? Feedback.Problem, .noName) }
        XCTAssertThrowsError(try Feedback.note(name: "Sam", message: " \n ", email: "")) { XCTAssertEqual($0 as? Feedback.Problem, .empty) }
        XCTAssertThrowsError(try Feedback.note(name: "Sam", message: String(repeating: "a", count: Feedback.maximumLength + 1), email: "")) { XCTAssertEqual($0 as? Feedback.Problem, .tooLong) }
        XCTAssertNoThrow(try Feedback.note(name: "Sam", message: String(repeating: "a", count: Feedback.maximumLength), email: ""))
        for bad in ["sam", "sam@", "@example.com", "sam@example", "sam @example.com", "sam@exa mple.com", "sam@@example.com"] {
            XCTAssertThrowsError(try Feedback.note(name: "Sam", message: "Hi", email: bad), bad) { XCTAssertEqual($0 as? Feedback.Problem, .badEmail, bad) }
        }
        XCTAssertNoThrow(try Feedback.note(name: "Sam", message: "Hi", email: "sam.lee+hereabouts@mail.example.co.uk"))
    }

    func testTheRequestIsAJSONPostOfThePageAndNothingElse() throws {
        let store = try LocaliserStore(inMemory: true)
        _ = try store.addItem(name: "Grandad's watch", place: store.addPlace(name: "Bedside drawer"))
        let request = try Feedback.request(for: Feedback.note(name: "Sam", message: "Hi", email: "sam@example.com"))
        XCTAssertEqual(request.url, Support.feedbackURL)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        let body = try XCTUnwrap(request.httpBody)
        let fields = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: String])
        XCTAssertEqual(Set(fields.keys), ["name", "message", "email", "version", "system", "language"])
        XCTAssertEqual(fields["name"], "Sam")
        XCTAssertEqual(fields["message"], "Hi")
        XCTAssertEqual(fields["email"], "sam@example.com")
        let text = try XCTUnwrap(String(data: body, encoding: .utf8))
        XCTAssertFalse(text.contains("watch") || text.contains("Bedside"), "Nothing from the notebook")
        let anonymous = try Feedback.request(for: Feedback.note(name: "Sam", message: "Hi", email: ""))
        let anonymousFields = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(anonymous.httpBody)) as? [String: String])
        XCTAssertNil(anonymousFields["email"], "No email, no email field")
    }

    func testTheFeedbackAddressIsTheSitesOwn() {
        XCTAssertEqual(Support.feedbackURL.scheme, "https")
        XCTAssertEqual(Support.feedbackURL.host(), "feedback.hereaboutsapp.com")
    }

    func testSendingSucceedsOnlyWhenSupportGotIt() async throws {
        let note = try Feedback.note(name: "Sam", message: "Hi", email: "")
        func reply(_ status: Int) -> Feedback.Transport {
            { request in (Data(), HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!) }
        }
        try await Feedback.send(note, transport: reply(204))
        try await Feedback.send(note, transport: reply(200))
        for status in [400, 404, 413, 429, 500, 502] {
            do { try await Feedback.send(note, transport: reply(status)); XCTFail("\(status) isn't sent") }
            catch { XCTAssertEqual(error as? Feedback.Problem, .notSent, "\(status)") }
        }
        for code in [URLError.Code.notConnectedToInternet, .timedOut, .networkConnectionLost, .cannotFindHost, .dataNotAllowed] {
            do { try await Feedback.send(note, transport: { _ in throw URLError(code) }); XCTFail("\(code)") }
            catch { XCTAssertEqual(error as? Feedback.Problem, .offline, "\(code)") }
        }
        do { try await Feedback.send(note, transport: { _ in throw URLError(.badServerResponse) }); XCTFail() }
        catch { XCTAssertEqual(error as? Feedback.Problem, .notSent) }
    }

    /// Each failure is said in the app's own words, and a failed send says how else to reach support.
    /// Feedback can leave the phone now, so no wording in any language may promise that nothing does (M65, 13 Nov).
    func testNoWordingSaysNothingLeavesThePhone() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let catalog = try String(contentsOf: root.appendingPathComponent("Localiser/Localizable.xcstrings"), encoding: .utf8)
        for promise in ["Nothing leaves", "Nada sale de", "Rien ne quitte", "Nada sai de"] {
            XCTAssertFalse(catalog.contains(promise), promise)
        }
    }

    func testEveryProblemIsInTheAppsOwnWords() {
        for problem in Feedback.Problem.allCases {
            let text = problem.plainMessage()
            XCTAssertFalse(text.isEmpty)
            if problem != .tooLong { XCTAssertNil(text.rangeOfCharacter(from: .decimalDigits), "No codes: \(text)") }
            for word in ["error", "server", "HTTP", "Cocoa"] { XCTAssertFalse(text.localizedCaseInsensitiveContains(word), text) }
        }
        XCTAssertEqual(Feedback.Problem.offline.plainMessage(), "Couldn't send. Check your connection and try again.")
        XCTAssertTrue(Feedback.Problem.notSent.plainMessage().contains(Support.email))
    }
}
