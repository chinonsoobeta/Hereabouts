import Foundation

/// Splits a spoken sentence such as "the spare key's in the blue tin on the hall shelf" into the thing
/// ("Spare key") and the place, then finds that place among the notebook's places. Rules only; pure.
struct VoiceParser: Sendable {
    /// A place the notebook knows, by its path from the top: ["Hall", "Shelf", "Blue tin"].
    struct Candidate: Sendable, Equatable {
        var id: UUID
        var path: [String]
    }

    struct Result: Sendable, Equatable {
        var name: String
        /// The existing place, when exactly one fits every place word.
        var placeID: UUID?
        /// The place words as said, without "the" or "my", when no existing place fits.
        var unmatchedPlace: String?
        /// For a new place: its name ("Blue tin") and, if the rest was recognised, the place it goes in.
        var newPlaceName: String?
        var newPlaceParent: UUID?
    }

    var language: VoiceLanguage = .english

    /// The thing and the place, or nil when the sentence has no word like "in" or "on" to split at.
    func parse(_ sentence: String, places: [Candidate]) -> Result? {
        guard let (nameWords, placeWords) = split(sentence) else { return nil }
        let name = Self.capitalized(nameWords.joined(separator: " "))
        guard !name.isEmpty else { return nil }
        return result(name: name, placeWords: placeWords, places: places)
    }

    /// Finds the place for words already pulled apart (by the rules, or by the on-device model).
    func result(name: String, placeWords: [String], places: [Candidate]) -> Result {
        let segments = self.segments(placeWords)
        let said = placeWords.filter { !language.articles.contains($0) }.joined(separator: " ")
        if let match = match(segments.flatMap { $0 }, places: places) {
            return Result(name: name, placeID: match)
        }
        // The innermost part is new; the rest may be a place that exists already.
        let inner = segments.first.map { Self.capitalized($0.joined(separator: " ")) }
        let parent = segments.count > 1 ? match(segments.dropFirst().flatMap { $0 }, places: places) : nil
        return Result(name: name, unmatchedPlace: said.isEmpty ? nil : said, newPlaceName: inner, newPlaceParent: parent)
    }

    // MARK: Splitting

    func words(_ text: String, keepCase: Bool = false) -> [String] {
        let cleaned = text.replacingOccurrences(of: "\u{2019}", with: "'")
        let lowered = keepCase ? cleaned : cleaned.lowercased()
        return lowered.split { !($0.isLetter || $0.isNumber || $0 == "'" || $0 == "-") }
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "'-")) }
            .filter { !$0.isEmpty }
    }

    /// The name words and the place words.
    func split(_ sentence: String) -> ([String], [String])? {
        let original = words(sentence, keepCase: true)
        var tokens = original.map { $0.lowercased() }
        let start = tokens.count - dropLeadIns(tokens).count
        tokens = dropLeadIns(tokens)
        tokens = dropTrailers(tokens)
        let cased = Array(original[start..<(start + tokens.count)])
        // The first preposition after at least one word of name.
        var index = 1
        while index < tokens.count {
            if let length = preposition(at: index, in: tokens) {
                let place = Array(tokens[(index + length)...])
                let name = cleanName(Array(cased[..<index]))
                guard !name.isEmpty, !place.isEmpty else { return nil }
                return (name, place)
            }
            index += 1
        }
        return nil
    }

    private func dropLeadIns(_ tokens: [String]) -> [String] {
        var tokens = tokens
        let leads = language.leadIns.map { $0.split(separator: " ").map(String.init) }.sorted { $0.count > $1.count }
        var changed = true
        while changed {
            changed = false
            for lead in leads where tokens.count > lead.count && Array(tokens.prefix(lead.count)) == lead {
                tokens.removeFirst(lead.count); changed = true; break
            }
        }
        return tokens
    }

    private func dropTrailers(_ tokens: [String]) -> [String] {
        var tokens = tokens
        let trails = language.trailers.map { $0.split(separator: " ").map(String.init) }.sorted { $0.count > $1.count }
        var changed = true
        while changed {
            changed = false
            for trail in trails where tokens.count > trail.count + 2 && Array(tokens.suffix(trail.count)) == trail {
                tokens.removeLast(trail.count); changed = true; break
            }
        }
        return tokens
    }

    /// How many words the preposition at `index` takes up, or nil if none starts there.
    private func preposition(at index: Int, in tokens: [String]) -> Int? {
        for phrase in language.prepositions.map({ $0.split(separator: " ").map(String.init) }).sorted(by: { $0.count > $1.count }) {
            guard index + phrase.count <= tokens.count, Array(tokens[index..<(index + phrase.count)]) == phrase else { continue }
            return phrase.count
        }
        return nil
    }

    private func cleanName(_ words: [String]) -> [String] {
        var words = words
        while let last = words.last?.lowercased(), language.linking.contains(last) { words.removeLast() }
        if var last = words.last {
            for ending in language.joinedLinking where last.lowercased().hasSuffix(ending) && last.count > ending.count {
                last = String(last.dropLast(ending.count)); break
            }
            words[words.count - 1] = last
        }
        while let first = words.first?.lowercased(), language.articles.contains(first) || language.linking.contains(first) { words.removeFirst() }
        return words
    }

    /// The place words broken at prepositions and possessives, innermost first:
    /// "blue tin on the hall shelf" → [blue tin], [hall shelf]; "my car's glovebox" → [glovebox], [car].
    func segments(_ words: [String]) -> [[String]] {
        var chunks: [[String]] = [[]]
        var index = 0
        while index < words.count {
            if let length = preposition(at: index, in: words) { chunks.append([]); index += length; continue }
            if language.placeBreaks.contains(words[index]) { chunks.append([]); index += 1; continue }
            if !language.articles.contains(words[index]) && !language.linking.contains(words[index]) { chunks[chunks.count - 1].append(words[index]) }
            index += 1
        }
        // Spoken order is already innermost first; a possessive turns that round within a chunk.
        var result: [[String]] = []
        for chunk in chunks {
            if let owner = chunk.lastIndex(where: { $0.hasSuffix(language.possessive) && $0.count > language.possessive.count }), owner < chunk.count - 1 {
                result.append(Array(chunk[(owner + 1)...]))
                var outer = Array(chunk[...owner])
                outer[owner] = String(outer[owner].dropLast(language.possessive.count))
                result.append(outer)
            } else { result.append(chunk) }
        }
        return result.filter { !$0.isEmpty }
    }

    // MARK: Matching

    /// The one place whose own name is among the words and whose path covers all of them.
    func match(_ words: [String], places: [Candidate]) -> UUID? {
        let wanted = Set(words.map(normal))
        guard !wanted.isEmpty else { return nil }
        let fits = places.compactMap { place -> (UUID, Int)? in
            guard let own = place.path.last else { return nil }
            let ownWords = Set(self.words(own).filter { !language.articles.contains($0) && !language.prepositions.contains($0) }.map(normal))
            let pathWords = Set(place.path.flatMap { self.words($0) }.map(normal))
            guard !ownWords.isEmpty, ownWords.isSubset(of: wanted), wanted.isSubset(of: pathWords) else { return nil }
            return (place.id, pathWords.count - wanted.count)
        }
        guard let best = fits.map(\.1).min() else { return nil }
        let closest = fits.filter { $0.1 == best }
        return closest.count == 1 ? closest[0].0 : nil
    }

    private func normal(_ word: String) -> String {
        var word = word
        if word.hasSuffix(language.possessive), word.count > language.possessive.count { word = String(word.dropLast(language.possessive.count)) }
        return language.singular(word)
    }

    static func capitalized(_ text: String) -> String {
        guard let first = text.first else { return text }
        return first.uppercased() + text.dropFirst()
    }
}
