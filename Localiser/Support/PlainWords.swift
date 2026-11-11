import Foundation

/// What a screen says when something fails outside the app's own rules: Core Data, the file system, the
/// App Store. Always the app's own words. The system's text ("The operation couldn't be completed. (Cocoa
/// error 134501.)") never reaches a screen.
enum PlainWords: CaseIterable {
    case tryAgain, notRestored, backupNotSaved, spreadsheetNotSaved, backupNotOpened, notBackedUp
    case purchaseNotFinished, storeNotReached, notListening

    var text: String {
        switch self {
        case .tryAgain: String(localized: "Something went wrong. Try again, or close Hereabouts and open it again.")
        // A restore lands in one save, so a failure leaves the notebook as it was.
        case .notRestored: String(localized: "The backup wasn't restored. Your notebook is exactly as it was.")
        case .backupNotSaved: String(localized: "The backup wasn't saved. Try again.")
        case .spreadsheetNotSaved: String(localized: "The spreadsheet wasn't saved. Try again.")
        case .backupNotOpened: String(localized: "Hereabouts couldn't open that backup. Try again, or choose another one.")
        case .notBackedUp: String(localized: "Something in this notebook couldn't be backed up. Nothing has changed.")
        // Says nothing about being charged: a purchase that fails here can still arrive later from the App Store.
        case .purchaseNotFinished: String(localized: "The App Store couldn't finish that. Try again, or try Restore purchases.")
        case .storeNotReached: String(localized: "Couldn't check with the App Store. Try again.")
        case .notListening: String(localized: "Couldn't start listening. Try again, or type instead.")
        }
    }
}

/// The app's own errors: each already says what happened in the app's words.
protocol PlainSpoken: LocalizedError {}
extension LocaliserError: PlainSpoken {}
extension PhotoError: PlainSpoken {}
extension NotebookFile.MoveError: PlainSpoken {}

extension Error {
    /// The sentence a screen shows for this failure: the app's own error says it itself, anything else gets `fallback`.
    func plainMessage(or fallback: PlainWords = .tryAgain) -> String {
        (self as? any PlainSpoken)?.errorDescription ?? fallback.text
    }

    /// The kind of failure, for the support email and the line under "Details for support" on the screen shown
    /// when the notebook won't open. Never used as a message.
    var supportDetail: String {
        let error = self as NSError
        return "\(error.domain) \(error.code)"
    }

    /// The system's own description, for the support email only.
    var systemDescription: String { localizedDescription }
}
