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
    static let leader = adaptive(0xB4A9C7, 0x4A4062)
    static let amber = adaptive(0x9A4A14, 0xF0A86E)
    /// The boxed note on Find (keeping up, stocktake): lilac by day, near-black by night.
    static let noteBox = adaptive(0xECE5F3, 0x211B2E)
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
    static let wbPrice = notebook("Fraunces-Regular", size: 64, relativeTo: .largeTitle, serif: true).weight(.medium)
    static let wbQuote = notebook("Fraunces-Italic", size: 18, relativeTo: .body, serif: true)

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
            .background(Theme.paper)
            .overlay(alignment: .bottom) { Rectangle().fill(Theme.rule).frame(height: 1) }
    }
}

/// A ruled row on the notebook paper.
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

struct Stamp: View {
    enum Tone { case neutral, due, done, purple }
    let text: String
    var tone: Tone = .neutral
    private var ink: Color {
        switch tone {
        case .due: Theme.amber
        case .done: Theme.green
        case .purple: Theme.purpleInk
        case .neutral: Theme.ink
        }
    }
    var body: some View {
        Text(text.uppercased())
            .font(.wbLabel).tracking(1.54)
            .foregroundStyle(ink)
            .padding(.horizontal, 9).padding(.vertical, 5)
            .overlay { RoundedRectangle(cornerRadius: 3).stroke(ink, lineWidth: 1.5) }
            .overlay { RoundedRectangle(cornerRadius: 4).stroke(ink, lineWidth: 1).padding(-2) }
            .rotationEffect(.degrees(-3))
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel(text)
    }
}

/// Name and place/count share a baseline at ordinary sizes and stack at accessibility sizes.
struct NotebookLine: View {
    @Environment(\.dynamicTypeSize) private var textSize
    let name: String
    let detail: String
    var query = ""
    /// Ink rather than pencil for the detail, where it is the answer (the Pro allowance table).
    var strongDetail = false
    var body: some View {
        if textSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 6) { nameText; detailText }
        } else {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    nameText.fixedSize(horizontal: true, vertical: true)
                    DottedLeader().stroke(Theme.leader, style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [1, 4]))
                        .frame(minWidth: 16, maxWidth: .infinity).frame(height: 2).accessibilityHidden(true)
                    detailText.fixedSize(horizontal: true, vertical: true)
                }
                VStack(alignment: .leading, spacing: 6) { nameText; detailText }
            }
        }
    }
    private var nameText: some View { Text(highlighted(name)).font(.wbItem).foregroundStyle(Theme.ink).fixedSize(horizontal: false, vertical: true) }
    private var detailText: some View { Text(highlighted(detail)).font(.wbCaption).foregroundStyle(strongDetail ? Theme.ink : Theme.pencil).fixedSize(horizontal: false, vertical: true) }
    private func highlighted(_ text: String) -> AttributedString {
        var result = AttributedString(text)
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return result }
        var cursor = text.startIndex
        while cursor < text.endIndex, let match = text.range(of: term, options: [.caseInsensitive, .diacriticInsensitive], range: cursor..<text.endIndex) {
            if let lower = AttributedString.Index(match.lowerBound, within: result), let upper = AttributedString.Index(match.upperBound, within: result) {
                result[lower..<upper].backgroundColor = Theme.highlighter
            }
            cursor = match.upperBound
        }
        return result
    }
}

struct StickyNote<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content.fixedSize(horizontal: false, vertical: true)
            .padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.lilacPaper, in: RoundedRectangle(cornerRadius: 6))
            .overlay(alignment: .top) {
                Rectangle().fill(Theme.paper.opacity(0.85))
                    .overlay { Rectangle().stroke(Theme.rule, lineWidth: 1) }
                    .frame(width: 46, height: 14).offset(y: -7).accessibilityHidden(true)
            }
            .rotationEffect(.degrees(-0.8))
            .padding(.vertical, 8)
    }
}

private struct DottedLeader: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in p.move(to: CGPoint(x: rect.minX, y: rect.midY)); p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY)) }
    }
}

struct PenCheckbox: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let checked: Bool
    var body: some View {
        PenTick().trim(from: 0, to: checked ? 1 : 0)
            .stroke(Theme.purpleInk, style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
            .padding(4).frame(width: 26, height: 26)
            .overlay { RoundedRectangle(cornerRadius: 3).stroke(Theme.ink, lineWidth: 1.5) }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: checked)
            .accessibilityHidden(true)
    }
}

private struct PenTick: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.width * 0.08, y: rect.height * 0.52))
            p.addLine(to: CGPoint(x: rect.width * 0.36, y: rect.height * 0.86))
            p.addLine(to: CGPoint(x: rect.width * 0.94, y: rect.height * 0.12))
        }
    }
}

struct IconTile: View {
    let systemImage: String
    var photo: Data? = nil
    var size: CGFloat = 48
    var tone: Stamp.Tone = .neutral
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
            .font(.wbBody.weight(.bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 52)
            .padding(.horizontal, 20)
            .background(Theme.purpleFill.opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.45), in: RoundedRectangle(cornerRadius: 10))
    }
}

struct SoftButtonStyle: ButtonStyle {
    var compact = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.wbBody.weight(.bold))
            .foregroundStyle(Theme.purpleInk)
            .frame(maxWidth: compact ? nil : .infinity, minHeight: compact ? 44 : 52)
            .padding(.horizontal, compact ? 16 : 20)
            .background(Theme.mist.opacity(configuration.isPressed ? 0.7 : 1), in: RoundedRectangle(cornerRadius: 6))
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
            Text("No place yet").font(.wbCaption).foregroundStyle(Theme.secondary)
        }
    }
}

enum DueLabel {
    /// Days from today until the given calendar day; negative when missed.
    static func days(until day: CalendarDay?, now: Date = .now) -> Int? {
        guard let target = day?.date(), let today = CalendarDay(now).date() else { return nil }
        return Calendar(identifier: .gregorian).dateComponents([.day], from: today, to: target).day
    }

    static func pill(for day: CalendarDay?) -> (String, Stamp.Tone)? {
        guard let days = days(until: day) else { return nil }
        switch days {
        case -1: return ("Yesterday", .due)
        case ..<0: return ("\(-days) days ago", .due)
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
    /// "Sun 11 Oct" this year, "3 Mar 2027" in another.
    var formatted: String {
        guard let date = date() else { return stored }
        return date.isThisYear ? date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()) : date.formatted(.dateTime.day().month(.abbreviated).year())
    }
}

extension Date {
    var isThisYear: Bool { Calendar.current.isDate(self, equalTo: .now, toGranularity: .year) }
    /// "14 March", with the year when it isn't this one.
    var dayAndMonth: String { isThisYear ? formatted(.dateTime.day().month(.wide)) : formatted(.dateTime.day().month(.wide).year()) }
}
