import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Turns what was said into a thing and a place: the rules first, then, on iPhones with Apple
/// Intelligence, the on-device model when the rules find no split. The model is never required.
enum VoiceUnderstanding {
    @MainActor static func understand(_ sentence: String, places: [VoiceParser.Candidate], parser: VoiceParser = VoiceParser()) async -> VoiceParser.Result? {
        if let result = parser.parse(sentence, places: places) { return result }
        #if canImport(FoundationModels)
        guard case .available = SystemLanguageModel.default.availability else { return nil }
        let session = LanguageModelSession(instructions: "Someone said where they put something at home. Give the thing's short name, and the place words exactly as they said them, without \"the\" or \"my\".")
        guard let answer = try? await session.respond(to: sentence, generating: SpokenPutAway.self).content else { return nil }
        let name = answer.thing.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }
        return parser.result(name: VoiceParser.capitalized(name), placeWords: parser.words(answer.place), places: places)
        #else
        return nil
        #endif
    }
}

#if canImport(FoundationModels)
@Generable struct SpokenPutAway {
    @Guide(description: "The thing that was put away, such as \"spare key\"")
    var thing: String
    @Guide(description: "Where it is, such as \"blue tin on the hall shelf\"")
    var place: String
}
#endif
