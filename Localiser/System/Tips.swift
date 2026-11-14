import SwiftUI

/// One-time hints, each a card in the list where its feature lives: a button that does it, and Dismiss.
/// Never a bubble hanging from the top of the screen, which reads like a notification (owner, 14 November).
/// Either button puts the card away for good.
enum Hint: String, CaseIterable {
    case putAway, move, leaving

    var key: String { "hintDismissed." + rawValue }
    func isShown(in defaults: UserDefaults = .standard) -> Bool { !Self.hiddenForTesting && !defaults.bool(forKey: key) }
    func dismiss(in defaults: UserDefaults = .standard) { defaults.set(true, forKey: key) }

    /// Put-away mode is worth a mention once there are a few things to put away, and not while it's on.
    static func suggestsPutAway(itemCount: Int, putAwayOn: Bool, in defaults: UserDefaults = .standard) -> Bool {
        itemCount >= 5 && !putAwayOn && putAway.isShown(in: defaults)
    }

    /// "Tap Move" only makes sense beside a Move button: a thing with a place, not archived, outside put-away mode.
    static func suggestsMove(hasPlace: Bool, archived: Bool, putAwayOn: Bool, in defaults: UserDefaults = .standard) -> Bool {
        hasPlace && !archived && !putAwayOn && move.isShown(in: defaults)
    }

    /// UI tests of other screens run without hints, so their layouts stay put. `--show-tips` brings them back, fresh.
    static func configureForTesting() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--show-tips") { allCases.forEach { UserDefaults.standard.removeObject(forKey: $0.key) } }
        #endif
    }

    static var hiddenForTesting: Bool { SiriTip.hiddenForTesting }
}

/// A hint as a note in the list: a serif title, a line of ink, then its buttons.
struct HintCard: View {
    let hint: Hint
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    var actionTitle: LocalizedStringKey?
    var action: (() -> Void)?
    let dismiss: () -> Void
    @Environment(\.dynamicTypeSize) private var textSize

    var body: some View {
        let buttons = textSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 0)) : AnyLayout(HStackLayout(spacing: 20))
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.wbItem).foregroundStyle(Theme.ink).accessibilityAddTraits(.isHeader)
            Text(message).font(.wbBody).foregroundStyle(Theme.ink).fixedSize(horizontal: false, vertical: true)
            buttons {
                if let actionTitle, let action {
                    Button { withAnimation { hint.dismiss(); action() } } label: { tappable(Text(actionTitle).font(.wbBody.weight(.bold)).foregroundStyle(Theme.purpleInk)) }
                        .buttonStyle(.plain).accessibilityIdentifier("hint.\(hint.rawValue).action")
                }
                Button { withAnimation { hint.dismiss(); dismiss() } } label: { tappable(Text("Dismiss").font(.wbBody).foregroundStyle(Theme.ink)) }
                    .buttonStyle(.plain).accessibilityIdentifier("hint.\(hint.rawValue).dismiss")
            }
        }
        .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.noteBox, in: RoundedRectangle(cornerRadius: 6))
        .overlay { RoundedRectangle(cornerRadius: 6).stroke(Theme.ink, lineWidth: 1.5) }
        .accessibilityElement(children: .contain)
    }

    /// The whole 44-point row is the button, not just its word.
    private func tappable(_ label: some View) -> some View {
        label.frame(minWidth: 44, minHeight: 44, alignment: .leading).contentShape(Rectangle())
    }
}

/// The Siri tips on the Find tab, one per phrase. Each is shown until it is dismissed, then stays gone.
enum SiriTip: String, CaseIterable {
    case whereIs, writeDown
    var key: String { "siriTipDismissed." + rawValue }
    func isShown(in defaults: UserDefaults = .standard) -> Bool { !defaults.bool(forKey: key) }
    func dismiss(in defaults: UserDefaults = .standard) { defaults.set(true, forKey: key) }
    /// UI tests of the screens themselves run without tips, whose extra rows would move what the tests tap.
    static var hiddenForTesting: Bool {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.contains("--ui-test-library") && !arguments.contains("--show-tips")
        #else
        return false
        #endif
    }
}
