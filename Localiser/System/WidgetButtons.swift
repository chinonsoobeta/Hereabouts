import Foundation

/// What the widget's two buttons open, and where the Lent out widget goes. Plain Foundation only: the app and
/// the widget both compile this file, so the links and the language check can't drift apart. Nothing here reads the notebook.
enum WidgetButtons {
    static let find = URL(string: "hereabouts://find")!
    static let say = URL(string: "hereabouts://say")!
    static let lent = URL(string: "hereabouts://lent")!

    /// Voice memos need a parser for the language. English only for now; see `VoiceLanguage`.
    static func voiceWorks(for locale: Locale = .current) -> Bool { locale.language.languageCode == .english }

    /// Find always; Say it only where voice works.
    static func links(for locale: Locale = .current) -> [URL] { voiceWorks(for: locale) ? [find, say] : [find] }
}
