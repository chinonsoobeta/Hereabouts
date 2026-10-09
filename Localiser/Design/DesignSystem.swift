import SwiftUI
import UIKit

// Paper and ink tokens from the binding notebook direction (plan section 10.2).
enum Theme {
    private static func adaptive(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light) })
    }
    static let paper = adaptive(0xF6F1E9, 0x17131F)
    static let lilacPaper = adaptive(0xECE5F3, 0x2A2340)
    static let highlighter = adaptive(0xE6DBF7, 0x3A3150)
    static let ink = adaptive(0x241B3D, 0xF1EBF7)
    static let purpleInk = adaptive(0x5B3DB8, 0xB59CF5)
    static let deepInk = adaptive(0x3B2A7A, 0xB59CF5)
    static let pencil = adaptive(0x655C7A, 0xB5ABC9)
    static let rule = adaptive(0xD9D0E6, 0x3A3150)
    static let leader = adaptive(0xB4A9C7, 0x5A4F78)
    static let amber = adaptive(0x9A4A14, 0xE8A772)
    static let green = adaptive(0x2E6B3F, 0x8BD1A0)

    // Existing component roles use the new palette during the sequential screen restyle.
    static let purple = purpleInk
    // Existing solid buttons and progress cards have white text in both appearances.
    static let purpleFill = Color(uiColor: UIColor(hex: 0x5B3DB8))
    static let lilac = lilacPaper
    static let mist = highlighter
    static let ground = paper
    static let card = paper
    static let secondary = pencil
    static let apricot = lilacPaper
    static let apricotInk = amber
    static let sage = lilacPaper
    static let sageInk = green
    static let warning = amber
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}

// Bundled faces, scaled against semantic text styles for Dynamic Type.
extension Font {
    private static func notebook(_ name: String, size: CGFloat, relativeTo style: Font.TextStyle, serif: Bool = false) -> Font {
        let face = UIFont(name: name, size: size) != nil ? name : (serif ? "Georgia" : UIFont.systemFont(ofSize: size).fontName)
        return .custom(face, size: size, relativeTo: style)
    }
    static let wbDisplay = notebook("Fraunces-Regular", size: 36, relativeTo: .largeTitle, serif: true).weight(.medium)
    static let wbTitle = notebook("Fraunces-Regular", size: 24, relativeTo: .title2, serif: true).weight(.medium)
    static let wbBody = notebook("AtkinsonHyperlegible-Regular", size: 17, relativeTo: .body)
    static let wbItem = notebook("Fraunces-Regular", size: 19, relativeTo: .body, serif: true).weight(.medium)
    static let wbCaption = notebook("AtkinsonHyperlegible-Regular", size: 13, relativeTo: .footnote).weight(.medium)
    static let wbLabel = notebook("AtkinsonHyperlegible-Bold", size: 11, relativeTo: .footnote)

    static func appearanceFont(_ name: String, size: CGFloat, weight: UIFont.Weight, style: UIFont.TextStyle) -> UIFont {
        let base = UIFont(name: name, size: size) ?? UIFont(name: "Georgia", size: size) ?? .systemFont(ofSize: size, weight: weight)
        let descriptor = base.fontDescriptor.addingAttributes([.traits: [UIFontDescriptor.TraitKey.weight: weight]])
        return UIFontMetrics(forTextStyle: style).scaledFont(for: UIFont(descriptor: descriptor, size: size))
    }
}

enum Appearance {
    @MainActor static func apply() {
        let bar = UINavigationBar.appearance()
        bar.largeTitleTextAttributes = [.font: Font.appearanceFont("Fraunces-Regular", size: 36, weight: .medium, style: .largeTitle), .foregroundColor: UIColor(Theme.ink)]
        bar.titleTextAttributes = [.font: Font.appearanceFont("Fraunces-Regular", size: 20, weight: .medium, style: .headline), .foregroundColor: UIColor(Theme.ink)]
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
        case 1: return ("Tomorrow", .due)
        case 2...3: return ("In \(days) days", .due)
        default: return ("In \(days) days", .neutral)
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
