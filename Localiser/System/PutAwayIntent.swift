import AppIntents

/// Opens Hereabouts on the put-away screen, camera first. The Action button, Siri and the
/// Control Centre button all run this; the control extension shares this file.
struct PutAwayIntent: AppIntent {
    static var title: LocalizedStringResource { "Put something away" }
    static var description: IntentDescription { IntentDescription("Opens the camera to write down a thing and where it goes.") }
    static var openAppWhenRun: Bool { true }

    @MainActor func perform() async throws -> some IntentResult {
        #if !HEREABOUTS_CONTROLS
        QuickActions.shared.link = .putAway
        #endif
        return .result()
    }
}
