import CoreSpotlight
import UniformTypeIdentifiers

/// Puts item names, aliases and places in Spotlight so a search outside the app finds them.
/// Only names and place paths are indexed; notes, photos and documents are not. Private things stay out.
@MainActor enum Spotlight {
    static let domain = "dev.hereabouts.items"
    private static var pending: Task<Void, Never>?
    private static var lastSignature = 0

    static func index(_ store: LocaliserStore) {
        guard store.isUserLibrary else { return }
        let entries = indexable(store.items).map { (id: $0.id, name: $0.name, aliases: $0.aliases, path: $0.place?.path ?? "") }
        var hasher = Hasher()
        for entry in entries { hasher.combine(entry.id); hasher.combine(entry.name); hasher.combine(entry.aliases); hasher.combine(entry.path) }
        let signature = hasher.finalize()
        guard signature != lastSignature else { return }
        lastSignature = signature
        pending?.cancel()
        pending = Task {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            let items = entries.map { entry in
                let attributes = CSSearchableItemAttributeSet(contentType: .content)
                attributes.title = entry.name
                attributes.contentDescription = entry.path.isEmpty ? String(localized: "No place yet") : entry.path
                attributes.keywords = entry.aliases.split(whereSeparator: \.isNewline).map(String.init)
                return CSSearchableItem(uniqueIdentifier: entry.id.uuidString, domainIdentifier: domain, attributeSet: attributes)
            }
            let index = CSSearchableIndex.default()
            try? await index.deleteSearchableItems(withDomainIdentifiers: [domain])
            if !items.isEmpty { try? await index.indexSearchableItems(items) }
        }
    }

    /// What Spotlight may show: current things, never private ones.
    static func indexable(_ items: [Belonging]) -> [Belonging] { items.filter { !$0.archived && !$0.isDeleted && !$0.isPrivate } }

    static func clear() {
        lastSignature = 0
        CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers: [domain]) { _ in }
    }
}
