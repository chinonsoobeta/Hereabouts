import Foundation

/// Dates from pasted order or delivery email text, read the same way as a scanned receipt.
/// The share sheet (B3) reuses this for shared text.
enum OrderEmail {
    /// What a date in an order email is likely to be.
    enum Role: Equatable, Sendable {
        case returnBy, delivered, ordered, other
    }

    struct Found: Identifiable, Sendable {
        let candidate: DateCandidate
        let role: Role
        var id: String { candidate.id }
        /// The return-window start this date could be, for the date editor's window calculator.
        var anchorType: String? { role == .delivered ? "Delivery date" : role == .ordered ? "Purchase date" : nil }
    }

    static let maximumCharacters = 100_000

    /// Return-by dates first, then delivery, then order dates, then anything else; each in the order written.
    static func read(_ text: String) -> [Found] {
        let found = ScanDates.candidates(String(text.prefix(maximumCharacters))).map { Found(candidate: $0, role: role(of: $0)) }
        let rank: [Role: Int] = [.returnBy: 0, .delivered: 1, .ordered: 2, .other: 3]
        return found.enumerated().sorted { (rank[$0.element.role]!, $0.offset) < (rank[$1.element.role]!, $1.offset) }.map(\.element)
    }

    static func role(of candidate: DateCandidate) -> Role {
        let line = candidate.line.lowercased()
        if candidate.hint == .returns { return .returnBy }
        if ["deliver", "arriv"].contains(where: line.contains) { return .delivered }
        if ["order", "purchase", "bought", "placed"].contains(where: line.contains) { return .ordered }
        return .other
    }
}
