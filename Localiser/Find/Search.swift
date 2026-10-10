import Foundation

enum ItemSearch {
    struct Entry {
        let item: Belonging
        let text: SearchText
        let archived: Bool
        let createdAt: Date
        init(_ item: Belonging) {
            self.item = item; archived = item.archived; createdAt = item.createdAt
            text = SearchText(name: item.name, aliases: item.aliases, place: item.place?.path ?? "", notes: item.notes)
        }
    }

    struct SearchText {
        let name: String
        let aliases: [String]
        let place: String
        let notes: String
        let words: [String]
        let placeWords: [String]
        init(name: String, aliases: String, place: String, notes: String) {
            self.name = normalized(name)
            self.aliases = aliases.components(separatedBy: .newlines).map(normalized)
            self.place = normalized(place); self.notes = normalized(notes)
            words = ([self.name] + self.aliases).flatMap { $0.split(separator: " ").map(String.init) }
            placeWords = self.place.split { $0.isWhitespace || $0 == "›" }.map(String.init)
        }
    }

    static func results(query: String, entries: [Entry], archived: Bool) -> [Belonging] {
        let query = normalized(query)
        let tokens = query.split(separator: " ").map(String.init)
        // The index can briefly hold an item deleted this pass; skip it so views never read a faulted id.
        return entries.filter { $0.archived == archived && !$0.item.isDeleted && $0.item.managedObjectContext != nil }.compactMap { entry -> (Entry, Int)? in
            guard let score = score(normalizedQuery: query, tokens: tokens, text: entry.text) else { return nil }
            return (entry, score)
        }.sorted { $0.1 == $1.1 ? $0.0.createdAt > $1.0.createdAt : $0.1 > $1.1 }.map { $0.0.item }
    }

    static func normalized(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func score(query: String, name: String, aliases: String, place: String, notes: String) -> Int? {
        let query = normalized(query)
        return score(normalizedQuery: query, tokens: query.split(separator: " ").map(String.init), text: SearchText(name: name, aliases: aliases, place: place, notes: notes))
    }

    private static func score(normalizedQuery query: String, tokens: [String], text: SearchText) -> Int? {
        guard !query.isEmpty else { return 0 }
        if text.name == query { return 1000 }
        if text.aliases.contains(query) { return 950 }
        if text.name.hasPrefix(query) { return 900 }
        if text.name.contains(query) { return 800 }
        if text.aliases.contains(where: { $0.contains(query) }) { return 750 }
        if text.place.contains(query) { return 700 }
        if query.count >= 3 && tokens.allSatisfy({ token in text.words.contains { word in
            abs(word.count - token.count) <= 1 && distance(word, token) <= 1
        } }) { return 600 }
        if query.count >= 3 && tokens.allSatisfy({ token in text.placeWords.contains { word in
            abs(word.count - token.count) <= 1 && distance(word, token) <= 1
        } }) { return 500 }
        if text.notes.contains(query) { return 400 }
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
        let separators = [" is in ", " is at ", " are in ", " are at ", " in ", " at "]
        for separator in separators {
            guard let range = sentence.range(of: separator, options: .caseInsensitive) else { continue }
            let name = withoutArticle(String(sentence[..<range.lowerBound]))
            let location = withoutArticle(String(sentence[range.upperBound...]))
            guard !name.isEmpty, !location.isEmpty else { return nil }
            // "the bedroom drawer" matches Bedroom › Drawer; "drawer" matches the one place called Drawer.
            let wanted = words(location)
            let matches = places.filter { words($0.1) == wanted || words($0.1.components(separatedBy: " › ").last ?? "") == wanted }
            return CaptureSuggestion(name: name, placeID: matches.count == 1 ? matches.first?.0 : nil, unrecognizedPlace: matches.count == 1 ? nil : location)
        }
        return nil
    }

    private static let articles: Set<String> = ["a", "an", "the", "my", "our", "your"]

    /// Lower-cased words without articles, so "the Bedroom › Drawer" and "bedroom drawer" compare equal.
    private static func words(_ text: String) -> [String] {
        normalized(text).split { !$0.isLetter && !$0.isNumber }.map(String.init).filter { !articles.contains($0) }
    }

    private static func withoutArticle(_ text: String) -> String {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let space = clean.firstIndex(of: " "), articles.contains(normalized(String(clean[..<space]))) else { return clean }
        return clean[space...].trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
