import Foundation

/// Name ideas from text in a photo: the label on a box, the brand on a drill.
enum NameSuggestions {
    static func from(_ text: String, limit: Int = 4) -> [String] {
        var seen = Set<String>()
        var names: [String] = []
        for raw in text.components(separatedBy: .newlines) {
            var line = raw.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
            guard (3...40).contains(line.count) else { continue }
            let letters = line.unicodeScalars.filter(CharacterSet.letters.contains).count
            guard Double(letters) / Double(line.count) >= 0.6, ScanDates.candidates(line).isEmpty else { continue }
            if line == line.uppercased() { line = line.capitalized }
            guard seen.insert(line.lowercased()).inserted else { continue }
            names.append(line)
            if names.count == limit { break }
        }
        return names
    }

    /// Reads the photo off the main thread. Nothing leaves the phone.
    static func read(_ photo: Data) async -> [String] {
        await Task.detached(priority: .userInitiated) {
            guard let text = try? ScanReader.read(data: photo, filename: "Photo.jpg", mime: "image/jpeg").text else { return [] }
            return from(text)
        }.value
    }
}

@MainActor extension LocaliserStore {
    /// Places things went into lately, newest first: where a quick put-away most likely goes.
    func recentPlaces(limit: Int = 5) -> [Place] {
        let byPath = Dictionary(places.map { ($0.path, $0) }, uniquingKeysWith: { first, _ in first })
        let moves = items.flatMap(\.movements).map { ($0.date, byPath[$0.toPath]) }
        // Where each thing was first put: before its first move, or where it is now.
        let added: [(Date, Place?)] = items.map { item in
            (item.createdAt, item.movements.min { $0.date < $1.date }.map { byPath[$0.fromPath] } ?? item.place)
        }
        var chosen: [Place] = []
        for (_, place) in (moves + added).sorted(by: { $0.0 > $1.0 }) {
            guard let place, !chosen.contains(place) else { continue }
            chosen.append(place)
            if chosen.count == limit { break }
        }
        return chosen
    }
}
