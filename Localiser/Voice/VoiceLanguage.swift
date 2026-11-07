import Foundation

/// The words the voice parser needs for one language. Adding a language means adding one of these,
/// its practice sentences, and turning it on in `VoiceCapture.isAvailable(for:)`.
struct VoiceLanguage: Sendable {
    /// The language code it covers, such as "en".
    var code: String
    /// Openings dropped before the thing's name: "I put", "I left".
    var leadIns: [String]
    /// Closings dropped from the end: "for now".
    var trailers: [String]
    /// Words that end the thing's name and start the place: "in", "on", "next to".
    var prepositions: [String]
    /// Words that only split the place: "the top drawer of the desk".
    var placeBreaks: [String]
    /// Words between the name and the place: "is", "are", "'s".
    var linking: [String]
    /// Endings joined to the name that mean "is": "key's in", "keys're on".
    var joinedLinking: [String]
    /// Words that carry no meaning in a name or a place: "the", "my".
    var articles: [String]
    /// The possessive ending: "my car's glovebox" is the glovebox in the car.
    var possessive: String
    /// Turns a plural word into its singular, so "drawers" matches "Drawer".
    var singular: @Sendable (String) -> String

    static let english = VoiceLanguage(
        code: "en",
        leadIns: ["remember that", "note that", "just so you know", "okay", "ok", "so", "um", "uh",
                  "i have just put", "i've just put", "i just put", "i have put", "i've put", "i put", "i'm putting", "i am putting",
                  "i just left", "i have left", "i've left", "i left", "i'm leaving", "i stored", "i've stored", "i keep", "we keep", "i hid", "i've hidden",
                  "i stashed", "i dropped", "i placed", "putting", "put", "leaving", "left", "store", "stored", "keep", "stashed", "placed"],
        trailers: ["for now", "for later", "for safekeeping", "for safe keeping", "just in case", "again", "now", "today", "for the winter", "for the summer"],
        prepositions: ["on top of", "in front of", "next to", "underneath", "inside", "behind", "beside", "between", "under", "below", "above",
                       "into", "onto", "in", "on", "at", "by"],
        placeBreaks: ["of"],
        linking: ["is", "are", "was", "were", "goes", "go", "lives", "live", "sits", "sit", "stays", "stay", "now", "still", "currently", "all", "both"],
        joinedLinking: ["'s", "'re"],
        articles: ["the", "a", "an", "my", "our", "your", "his", "her", "their", "its", "some", "that", "this", "these", "those"],
        possessive: "'s",
        singular: { word in
            if word.count > 4, word.hasSuffix("ives") { return String(word.dropLast(3)) + "fe" }
            if word.count > 4, word.hasSuffix("ves") { return String(word.dropLast(3)) + "f" }
            if word.count > 4, word.hasSuffix("ies") { return String(word.dropLast(3)) + "y" }
            if word.count > 4, ["ches", "shes", "sses", "xes", "zes"].contains(where: word.hasSuffix) { return String(word.dropLast(2)) }
            if word.count > 3, word.hasSuffix("s"), !word.hasSuffix("ss"), !word.hasSuffix("us") { return String(word.dropLast()) }
            return word
        })
}
