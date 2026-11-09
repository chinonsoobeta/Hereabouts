import AppIntents

/// Opens Hereabouts on the put-away screen, camera first. Siri, Shortcuts and the
/// Control Centre button all run this; the control extension shares this file.
struct PutAwayIntent: AppIntent {
    static var title: LocalizedStringResource { "Put something away" }
    static var description: IntentDescription { IntentDescription("Take a photo to write down a thing and its place.") }
    static var openAppWhenRun: Bool { true }

    @MainActor func perform() async throws -> some IntentResult {
        #if !HEREABOUTS_CONTROLS
        QuickActions.shared.link = .putAway
        #endif
        return .result()
    }
}
