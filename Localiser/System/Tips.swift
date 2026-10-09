import TipKit

/// One-time hints shown where a feature lives. Each appears once and then stays dismissed.
enum HereaboutsTips {
    static func configure() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-test-library") { Tips.hideAllTipsForTesting() }
        #endif
        try? Tips.configure([.displayFrequency(.daily)])
    }
}

struct ScanTip: Tip {
    @Parameter static var itemCount: Int = 0
    var title: Text { Text("Scan a receipt") }
    var message: Text? { Text("Hereabouts finds the return or expiry date for you. The receipt is read on your iPhone.") }
    var image: Image? { Image(systemName: "doc.viewfinder") }
    var rules: [Rule] { #Rule(Self.$itemCount) { $0 >= 1 } }
}

struct PutAwayTip: Tip {
    var title: Text { Text("Putting lots away?") }
    var message: Text? { Text("Turn on Put-away mode here to move several things to one place quickly.") }
    var rules: [Rule] { #Rule(ScanTip.$itemCount) { $0 >= 5 } }
}

struct MoveTip: Tip {
    var title: Text { Text("Moved it?") }
    var message: Text? { Text("Tap Move whenever you put it somewhere new, so you'll find it next time.") }
}

struct CalendarTip: Tip {
    var title: Text { Text("Add dates to Calendar") }
    var message: Text? { Text("Touch and hold a date to add it, or use the menu to add them all.") }
    var image: Image? { Image(systemName: "calendar.badge.plus") }
}

struct LeavingTip: Tip {
    var title: Text { Text("Tick things off as you pack") }
    var message: Text? { Text("When you tap I'm leaving, Hereabouts tells you if anything's still missing.") }
}
