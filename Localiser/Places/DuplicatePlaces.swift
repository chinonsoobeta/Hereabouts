import Foundation

/// Two phones set up apart each make their own Kitchen. After they sync, the app offers to fold the
/// empty copies into one. Places with things in them are never merged on their own.
@MainActor extension LocaliserStore {
    /// Places with no things anywhere inside them that share a name, a level and a home with another place.
    var sparePlaces: [Place] {
        var spares: [Place] = []
        for group in Dictionary(grouping: places, by: duplicateKey).values where group.count > 1 {
            let keeper = keeper(of: group)
            spares += group.filter { $0 != keeper && $0.holdsNoThings }
        }
        return spares.sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
    }

    /// Folds each spare into the place it copies: anything inside moves across, then the spare goes.
    /// Repeats, since moving a spare's drawers can leave the keeper with two of its own.
    func mergeSparePlaces() throws {
        var rounds = 0
        while let spare = sparePlaces.first, rounds < 1_000 {
            rounds += 1
            let group = places.filter { duplicateKey($0) == duplicateKey(spare) }
            let keeper = keeper(of: group)
            for child in spare.children { child.parent = keeper }
            context.delete(spare)
            try save()
        }
    }

    private func duplicateKey(_ place: Place) -> String {
        "\(place.home?.id.uuidString ?? "")/\(place.parent?.id.uuidString ?? "")/\(place.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())"
    }

    /// The copy to keep: the one holding the most, then the one with most inside it, then a steady order.
    private func keeper(of group: [Place]) -> Place {
        group.max { a, b in
            let (ta, tb) = (a.subtree.reduce(0) { $0 + $1.items.count }, b.subtree.reduce(0) { $0 + $1.items.count })
            if ta != tb { return ta < tb }
            if a.subtree.count != b.subtree.count { return a.subtree.count < b.subtree.count }
            return a.id.uuidString > b.id.uuidString
        }!
    }
}

extension Place {
    /// Nothing written down here or in anything inside it, archived things included.
    var holdsNoThings: Bool { subtree.allSatisfy(\.items.isEmpty) }
}
