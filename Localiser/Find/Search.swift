import Foundation

enum ItemSearch {
    static func normalized(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func score(query: String, name: String, aliases: String, place: String, notes: String) -> Int? {
        let query = normalized(query)
        guard !query.isEmpty else { return 0 }
        let name = normalized(name)
        let aliases = aliases.components(separatedBy: .newlines).map(normalized)
        if name == query { return 1000 }
        if aliases.contains(query) { return 950 }
        if name.hasPrefix(query) { return 900 }
        if name.contains(query) { return 800 }
        if aliases.contains(where: { $0.contains(query) }) { return 750 }
        if normalized(place).contains(query) { return 700 }
        let tokens = query.split(separator: " ").map(String.init)
        let words = ([name] + aliases).flatMap { $0.split(separator: " ").map(String.init) }
        if query.count >= 3 && tokens.allSatisfy({ token in words.contains { word in
            abs(word.count - token.count) <= 1 && distance(word, token) <= 1
        } }) { return 600 }
        if normalized(notes).contains(query) { return 400 }
        return nil
    }

    static func distance(_ a: String, _ b: String) -> Int {
        let left = Array(a), right = Array(b)
        var previous = Array(0...right.count)
        for (i, character) in left.enumerated() {
            var row = [i + 1]
            for (j, other) in right.enumerated() {
                row.append(min(row[j] + 1, previous[j + 1] + 1, previous[j] + (character == other ? 0 : 1)))
            }
            previous = row
        }
        return previous.last ?? 0
    }

    struct CaptureSuggestion: Equatable { var name: String; var placeID: UUID?; var unrecognizedPlace: String? }

    static func suggestion(_ sentence: String, places: [(UUID, String)]) -> CaptureSuggestion? {
        let separators = [" is in ", " is at ", " in ", " at "]
        for separator in separators {
            guard let range = sentence.range(of: separator, options: .caseInsensitive) else { continue }
            let name = String(sentence[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            let location = String(sentence[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty, !location.isEmpty else { return nil }
            let matches = places.filter { normalized($0.1) == normalized(location) }
            return CaptureSuggestion(name: name, placeID: matches.count == 1 ? matches.first?.0 : nil, unrecognizedPlace: matches.count == 1 ? nil : location)
        }
        return nil
    }
}

