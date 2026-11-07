import SwiftUI
import TipKit

/// One-time hints shown where a feature lives. Each appears once and then stays dismissed.
enum HereaboutsTips {
    static func configure() {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--show-tips") { Tips.showAllTipsForTesting() }
        else if arguments.contains("--ui-test-library") { Tips.hideAllTipsForTesting() }
        #endif
        try? Tips.configure([.displayFrequency(.daily)])
    }
}

struct PutAwayTip: Tip {
    @Parameter static var itemCount: Int = 0
    var title: Text { Text("Putting lots away?") }
    var message: Text? { Text("Turn on Put-away mode here to move several things to one place quickly.") }
    var rules: [Rule] { #Rule(Self.$itemCount) { $0 >= 5 } }
}

struct MoveTip: Tip {
    var title: Text { Text("Moved it?") }
    var message: Text? { Text("Tap Move whenever you put it somewhere new, so you'll find it next time.") }
}

struct LeavingTip: Tip {
    var title: Text { Text("Tick things off as you pack") }
    var message: Text? { Text("When you tap I'm leaving, Hereabouts tells you if anything's still missing.") }
}

/// Tips read like a note stuck in the margin: lilac paper, a serif title, ink text and a plain close.
struct NotebookTipStyle: TipViewStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                configuration.title.font(.wbItem).foregroundStyle(Theme.ink)
                configuration.message?.font(.wbBody).foregroundStyle(Theme.ink)
                ForEach(configuration.actions) { action in
                    Button(action: action.handler) { action.label().font(.wbBody.weight(.bold)).foregroundStyle(Theme.purpleInk) }
                        .frame(minHeight: 44)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button { configuration.tip.invalidate(reason: .tipClosed) } label: {
                Image(systemName: "xmark").font(.footnote.weight(.bold)).foregroundStyle(Theme.pencil).frame(width: 44, height: 44)
            }
            .accessibilityLabel("Close tip")
        }
        .padding(.leading, 16).padding(.vertical, 8)
    }
}
