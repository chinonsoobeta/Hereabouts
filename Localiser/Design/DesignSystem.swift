import SwiftUI
import UIKit

// Tokens and building blocks from the Wherebox design canvas ("Wherebox · look and feel").
// Every colour has a dark-mode partner chosen to keep text pairs at 4.5:1 or better.
enum Theme {
    private static func adaptive(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light) })
    }
    /// Wherebox purple. Tint for links, icons and active tab.
    static let purple = adaptive(0x6B4FBB, 0xC2A6FA)
    /// Solid fill behind white text: buttons, progress card, add button.
    static let purpleFill = adaptive(0x6B4FBB, 0x7C5CC9)
    /// Purple ink: text on lavender tints.
    static let purpleInk = adaptive(0x5B3FA6, 0xD3C4F7)
    static let lilac = adaptive(0xD9CEF0, 0x3A3050)
    static let mist = adaptive(0xEDE7F6, 0x2C2340)
    static let ground = adaptive(0xF7F4FB, 0x17121F)
    static let card = adaptive(0xFFFFFF, 0x221B2E)
    static let ink = adaptive(0x2A2140, 0xF1ECF9)
    static let secondary = adaptive(0x5A5270, 0xBDB5CC)
    static let apricot = adaptive(0xFCE9DC, 0x3D2A1E)
    static let apricotInk = adaptive(0x9A4A17, 0xF6B98A)
    static let sage = adaptive(0xDCEFE4, 0x1E3328)
    static let sageInk = adaptive(0x2F6B4A, 0x8FD1A8)
    static let warning = adaptive(0x8C4705, 0xFCBA6B)
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}

// Display type is Bricolage Grotesque and body type is Figtree. Both scale with Dynamic Type.
// If the font files are not bundled, Font.custom falls back to the system face at the same size and weight.
extension Font {
    static let wbDisplay = Font.custom("Bricolage Grotesque", size: 34, relativeTo: .largeTitle).weight(.bold)
    static let wbTitle = Font.custom("Bricolage Grotesque", size: 20, relativeTo: .title3).weight(.medium)
    static let wbBody = Font.custom("Figtree", size: 16, relativeTo: .body)
    static let wbItem = Font.custom("Figtree", size: 16, relativeTo: .body).weight(.semibold)
    static let wbCaption = Font.custom("Figtree", size: 13, relativeTo: .footnote).weight(.medium)
    static let wbLabel = Font.custom("Figtree", size: 13, relativeTo: .footnote).weight(.semibold)

    static func appearanceFont(_ name: String, size: CGFloat, weight: UIFont.Weight, style: UIFont.TextStyle) -> UIFont {
        let base = UIFont(name: name, size: size) ?? .systemFont(ofSize: size, weight: weight)
        return UIFontMetrics(forTextStyle: style).scaledFont(for: base)
    }
}

enum Appearance {
    @MainActor static func apply() {
        let bar = UINavigationBar.appearance()
        bar.largeTitleTextAttributes = [.font: Font.appearanceFont("BricolageGrotesque-Bold", size: 34, weight: .bold, style: .largeTitle), .foregroundColor: UIColor(Theme.ink)]
        bar.titleTextAttributes = [.font: Font.appearanceFont("BricolageGrotesque-Medium", size: 17, weight: .semibold, style: .headline), .foregroundColor: UIColor(Theme.ink)]
    }
}

struct CardBackground: ViewModifier {
    var padding: CGFloat = 14
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Theme.ink.opacity(0.06), radius: 1, y: 1)
            .shadow(color: Theme.ink.opacity(0.05), radius: 10, y: 6)
    }
}

/// A List row rendered as a floating card on the ground colour.
struct CardRow: ViewModifier {
    func body(content: Content) -> some View {
        content
            .modifier(CardBackground())
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 5, leading: 20, bottom: 5, trailing: 20))
    }
}

extension View {
    func card(padding: CGFloat = 14) -> some View { modifier(CardBackground(padding: padding)) }
    func cardRow() -> some View { modifier(CardRow()) }
    /// Clears the system grouped background so screens sit on the Wherebox ground colour.
    func groundBackground() -> some View { scrollContentBackground(.hidden).background(Theme.ground) }
    /// A List row with no card, aligned to the card gutter.
    func plainRow() -> some View {
        listRowBackground(Color.clear).listRowSeparator(.hidden).listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
    }
}

struct SectionHeading: View {
    let title: String
    var body: some View {
        Text(title).font(.wbTitle).foregroundStyle(Theme.ink).accessibilityAddTraits(.isHeader)
    }
}

struct Pill: View {
    enum Tone { case neutral, due, done }
    let text: String
    var tone: Tone = .neutral
    var body: some View {
        Text(text)
            .font(.wbLabel)
            .foregroundStyle(tone == .due ? Theme.apricotInk : tone == .done ? Theme.sageInk : Theme.purpleInk)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(tone == .due ? Theme.apricot : tone == .done ? Theme.sage : Theme.mist, in: Capsule())
            .fixedSize()
    }
}

struct IconTile: View {
    let systemImage: String
    var photo: Data? = nil
    var size: CGFloat = 48
    var tone: Pill.Tone = .neutral
    var body: some View {
        Group {
            if let photo, let image = UIImage(data: photo) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Image(systemName: systemImage)
                    .font(.system(size: size * 0.42, weight: .medium))
                    .foregroundStyle(tone == .due ? Theme.apricotInk : tone == .done ? Theme.sageInk : Theme.purpleInk)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(tone == .due ? Theme.apricot : tone == .done ? Theme.sage : Theme.mist)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.29, style: .continuous))
        .accessibilityHidden(true)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.wbItem)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 52)
            .padding(.horizontal, 20)
            .background(Theme.purpleFill.opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.45), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct SoftButtonStyle: ButtonStyle {
    var compact = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.wbItem)
            .foregroundStyle(Theme.purpleInk)
            .frame(maxWidth: compact ? nil : .infinity, minHeight: compact ? 44 : 52)
            .padding(.horizontal, compact ? 16 : 20)
            .background(Theme.mist.opacity(configuration.isPressed ? 0.7 : 1), in: RoundedRectangle(cornerRadius: compact ? 14 : 16, style: .continuous))
    }
}

/// "Garage › Back wall › Rack 2", with the final container emphasised as on the canvas.
struct PlaceBreadcrumb: View {
    let path: String?
    var body: some View {
        if let path, !path.isEmpty {
            let parts = path.components(separatedBy: " › ")
            (Text(parts.dropLast().map { $0 + " › " }.joined()).foregroundStyle(Theme.secondary) + Text(parts.last ?? "").foregroundStyle(Theme.ink).fontWeight(.semibold))
                .font(.wbCaption)
                .accessibilityLabel(path)
        } else {
            Text("Location unspecified").font(.wbCaption).foregroundStyle(Theme.secondary)
        }
    }
}

enum DueLabel {
    /// Days from today until the given calendar day; negative when missed.
    static func days(until day: CalendarDay?, now: Date = .now) -> Int? {
        guard let target = day?.date(), let today = CalendarDay(now).date() else { return nil }
        return Calendar(identifier: .gregorian).dateComponents([.day], from: today, to: target).day
    }

    static func pill(for day: CalendarDay?) -> (String, Pill.Tone)? {
        guard let days = days(until: day) else { return nil }
        switch days {
        case ..<0: return ("Missed", .due)
        case 0: return ("Today", .due)
        case 1: return ("1 day", .due)
        case 2...3: return ("\(days) days", .due)
        default: return ("\(days) days", .neutral)
        }
    }

    static func symbol(for kind: DeadlineKind?) -> String {
        switch kind {
        case .returns: "arrow.uturn.backward"
        case .warranty: "checkmark.shield"
        case .expiry: "hourglass"
        case nil: "calendar"
        }
    }
}

extension CalendarDay {
    var formatted: String { date().map { $0.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()) } ?? stored }
}
