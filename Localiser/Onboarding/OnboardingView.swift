import SwiftUI

/// Three short screens on first launch. Replayable from Settings.
struct OnboardingView: View {
    static let seenKey = "onboardingSeen"
    var onFinish: () -> Void
    @State private var page = 0
    private let pages: [(symbol: String, title: String, text: String)] = [
        ("magnifyingglass", "Find it next time", "Note where things go as you put them away. Search by any name you might remember later, like \u{201C}passport\u{201D} or \u{201C}the blue drill\u{201D}."),
        ("calendar.badge.clock", "Never miss a return", "Add a return date, warranty or expiry, or scan the receipt. Hereabouts reminds you before it's too late and can add it to your Calendar."),
        ("lock.shield", "Yours, on this phone", "No account and no tracking. Your library stays on this device. Export a backup to Files whenever you like, from Settings.")
    ]
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("Skip") { onFinish() }.font(.wbItem).foregroundStyle(Theme.purpleInk).padding(.horizontal, 20).frame(minHeight: 44)
            }
            TabView(selection: $page) {
                ForEach(pages.indices, id: \.self) { index in
                    let content = pages[index]
                    ScrollView {
                        VStack(spacing: 20) {
                            Image(systemName: content.symbol)
                                .font(.system(size: 52, weight: .medium))
                                .foregroundStyle(Theme.purpleInk)
                                .frame(width: 120, height: 120)
                                .background(Theme.mist, in: RoundedRectangle(cornerRadius: 34, style: .continuous))
                                .accessibilityHidden(true)
                            Text(content.title).font(.wbDisplay).foregroundStyle(Theme.ink).multilineTextAlignment(.center)
                                .accessibilityAddTraits(.isHeader)
                            Text(content.text).font(.wbBody).foregroundStyle(Theme.secondary).multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.horizontal, 28).padding(.top, 40)
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            Button(page == pages.count - 1 ? "Get started" : "Next") {
                if page == pages.count - 1 { onFinish() } else { withAnimation { page += 1 } }
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(20)
        }
        .background(Theme.ground)
    }
}
