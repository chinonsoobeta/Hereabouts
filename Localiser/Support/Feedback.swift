import Foundation
import UIKit

/// Settings › Send feedback: a note written in the app and posted to feedback.hereaboutsapp.com, which emails it to
/// support (owner, 13 Nov). Only what the page shows is sent, and nothing from the notebook. The name is required and
/// sits first on the form, as Apple's rule for optional feedback forms asks, so the App Store label stays
/// Data Not Collected. The site's side is `Server/feedback`, which checks the same limits.
enum Feedback {
    /// Counted in characters, as the site counts them.
    static let maximumLength = 4000
    static let maximumNameLength = 100

    struct Note: Encodable, Equatable, Sendable {
        var name: String
        var message: String
        /// Left out of the request when not given.
        var email: String?
        var version: String
        var system: String
        var language: String
    }

    /// What's on the page, kept by the window so a fold or an iPad resize doesn't lose it (`WindowState.feedback`).
    struct Draft: Equatable {
        var name = ""
        var message = ""
        var email = ""
        /// Showing the thanks. Leaving the page then starts the next note empty.
        var sent = false
    }

    enum Problem: Error, CaseIterable, Equatable, PlainSpoken {
        case noName, empty, tooLong, badEmail, offline, notSent
        var errorDescription: String? {
            switch self {
            case .noName: String(localized: "Add your name.")
            case .empty: String(localized: "Write your feedback first.")
            case .tooLong: String(localized: "Keep it to \(Feedback.maximumLength.formatted()) characters or fewer.")
            case .badEmail: String(localized: "Check the email address, or leave it blank.")
            case .offline: String(localized: "Couldn't send. Check your connection and try again.")
            case .notSent: String(localized: "Couldn't send right now. Try again later, or email \(Support.email).")
            }
        }
    }

    /// The note for what's on the page, trimmed, or the problem to show instead.
    @MainActor static func note(name: String, message: String, email: String) throws -> Note {
        let who = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !who.isEmpty, who.count <= maximumNameLength, !who.contains(where: \.isNewline) else { throw Problem.noName }
        let text = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw Problem.empty }
        guard text.count <= maximumLength else { throw Problem.tooLong }
        let address = email.trimmingCharacters(in: .whitespacesAndNewlines)
        // One @, a dot after it, no spaces: the same check the site makes.
        if !address.isEmpty, address.count > 254 || address.wholeMatch(of: /[^\s@]+@[^\s@]+\.[^\s@]+/) == nil { throw Problem.badEmail }
        return Note(name: who, message: text, email: address.isEmpty ? nil : address, version: Support.version,
                    system: "iOS \(UIDevice.current.systemVersion)", language: Locale.preferredLanguages.first ?? Locale.current.identifier)
    }

    static func request(for note: Note) throws -> URLRequest {
        var request = URLRequest(url: Support.feedbackURL, timeoutInterval: 20)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(note)
        return request
    }

    typealias Transport = @Sendable (URLRequest) async throws -> (Data, URLResponse)

    /// No cookies and no cache: the note goes, and nothing about it is kept on the phone.
    private static let session = URLSession(configuration: .ephemeral)
    static var liveTransport: Transport {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--feedback-stand-in") { return { try await StandIn.shared.send($0) } }
        #endif
        return { try await session.data(for: $0) }
    }

    private static let offlineCodes: Set<URLError.Code> = [.notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotFindHost,
                                                           .cannotConnectToHost, .dnsLookupFailed, .dataNotAllowed, .internationalRoamingOff]

    /// Sent once the site says support got it (a 2xx); anything else is a problem in the app's words.
    static func send(_ note: Note, transport: Transport = liveTransport) async throws {
        let response: URLResponse
        do { (_, response) = try await transport(request(for: note)) }
        catch let error as URLError where offlineCodes.contains(error.code) { throw Problem.offline }
        catch { throw Problem.notSent }
        guard let status = (response as? HTTPURLResponse)?.statusCode, (200..<300).contains(status) else { throw Problem.notSent }
    }

    #if DEBUG
    /// UI tests: the first send fails as if offline, and the rest arrive.
    private actor StandIn {
        static let shared = StandIn()
        private var sends = 0
        func send(_ request: URLRequest) throws -> (Data, URLResponse) {
            sends += 1
            if sends == 1 { throw URLError(.notConnectedToInternet) }
            return (Data(), HTTPURLResponse(url: request.url ?? Support.feedbackURL, statusCode: 204, httpVersion: nil, headerFields: nil)!)
        }
    }
    #endif
}
