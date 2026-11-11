import XCTest
@testable import Localiser

/// The system's own error text ("The operation couldn't be completed. (Cocoa error 134501.)") never reaches a
/// screen. The app's own errors keep their words; anything else gets one of the app's sentences.
final class PlainWordsTests: XCTestCase {
    private static var root: URL { URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent() }

    private static let systemErrors: [Error] = [
        NSError(domain: NSCocoaErrorDomain, code: 134501),
        NSError(domain: NSCocoaErrorDomain, code: NSFileReadNoSuchFileError),
        CocoaError(.fileWriteOutOfSpace),
        URLError(.notConnectedToInternet),
        NSError(domain: "SKInternalErrorDomain", code: 3),
        DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Unexpected end of file")),
    ]

    func testSystemErrorsGetTheAppsOwnWords() {
        for words in PlainWords.allCases {
            XCTAssertFalse(words.text.isEmpty)
            XCTAssertNil(words.text.rangeOfCharacter(from: .decimalDigits), "No error codes: \(words.text)")
            for word in ["error", "Cocoa", "operation", "domain"] {
                XCTAssertFalse(words.text.localizedCaseInsensitiveContains(word), words.text)
            }
            for error in Self.systemErrors {
                XCTAssertEqual(error.plainMessage(or: words), words.text, "\(error)")
            }
        }
        for error in Self.systemErrors { XCTAssertEqual(error.plainMessage(), PlainWords.tryAgain.text) }
    }

    func testTheAppsOwnErrorsKeepTheirWords() {
        XCTAssertEqual(LocaliserError.nameRequired.plainMessage(), "Enter a name.")
        XCTAssertEqual(LocaliserError.occupiedPlace.plainMessage(or: .notRestored), "Move what's inside somewhere else first.")
        XCTAssertEqual(LocaliserError.invalidBackup(LibraryBackup.damaged).plainMessage(or: .backupNotOpened), "This backup is damaged. Choose another one.")
        XCTAssertEqual(PhotoError.tooLarge.plainMessage(), "Choose a photo under 20 MB or 25 megapixels.")
        XCTAssertEqual(NotebookFile.MoveError.countsDiffer("Thing").plainMessage(), "Some Thing entries were missing from the copy. Your original notebook was kept.")
    }

    /// What the launch failure screen and the support email give support to go on: the kind of failure, not a sentence.
    func testSupportDetailNamesTheFailure() {
        XCTAssertEqual(NSError(domain: NSCocoaErrorDomain, code: 134110).supportDetail, "NSCocoaErrorDomain 134110")
        XCTAssertFalse(LocaliserError.schemaUnavailable.supportDetail.isEmpty)
    }

    /// `localizedDescription` is how the system's text reaches a screen. It is read in one place only, for support.
    func testNoScreenReadsTheSystemsErrorText() throws {
        var found: [String] = []
        for folder in ["Localiser", "HereaboutsWidget", "HereaboutsControls"] {
            let files = try XCTUnwrap(FileManager.default.enumerator(at: Self.root.appendingPathComponent(folder), includingPropertiesForKeys: nil))
            for case let file as URL in files where file.pathExtension == "swift" && file.lastPathComponent != "PlainWords.swift" {
                for (index, line) in try String(contentsOf: file, encoding: .utf8).components(separatedBy: "\n").enumerated() where line.contains("localizedDescription") {
                    found.append("\(folder)/\(file.lastPathComponent):\(index + 1)")
                }
            }
        }
        XCTAssertEqual(found, [], "Use plainMessage() instead")
    }
}
