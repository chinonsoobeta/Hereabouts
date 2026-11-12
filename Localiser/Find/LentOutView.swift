import SwiftUI

/// Who has what, from every home, with when to ask for it back. Its own tab, left of Settings (owner, 12 Nov).
struct LentOutView: View {
    @Environment(LocaliserStore.self) private var store
    @Environment(WindowState.self) private var ui

    var body: some View {
        let _ = store.revision
        let lent = store.lentItems
        let canLend = !LendChooser.offered(in: store).isEmpty
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if lent.isEmpty {
                    LibraryEmptyState(title: String(localized: "Nothing lent out"), systemImage: "arrow.uturn.right", description: String(localized: "When you lend something, it shows here with who has it and when to ask for it back."))
                    if canLend { Button("Lend something") { ui.choosingLend = true }.buttonStyle(PrimaryButtonStyle()) }
                } else {
                    ForEach(lent) { item in
                        NavigationLink(value: LentRoute.item(item.id)) { ItemRow(item: item, showsAskBack: true).card() }
                            .buttonStyle(.plain).hoverEffect().thingDraggable(item)
                    }
                }
            }
            .padding(.horizontal, 20).padding(.vertical, 12)
        }
        .background(Theme.ground).navigationTitle("Lent out")
        .toolbar { if canLend { Button("Lend something", systemImage: "plus") { ui.choosingLend = true } } }
    }
}

/// "Lend something": a thing in this home that isn't lent out already. Picking one opens Lend it for it.
struct LendChooser: View {
    @Environment(LocaliserStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let chosen: (UUID) -> Void
    @State private var query = ""

    /// What can be lent from here: this home's things that aren't lent out or archived, by name.
    static func offered(in store: LocaliserStore) -> [Belonging] {
        store.itemsHere.filter { !$0.isLent && !$0.archived && !$0.isDeleted }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        let _ = store.revision
        let offered = Self.offered(in: store)
        let shown = query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? offered
            : ItemSearch.results(query: query, entries: store.searchIndex, archived: false).filter(offered.contains)
        SheetList {
            ForEach(shown) { item in
                Button { chosen(item.id) } label: { ItemRow(item: item).contentShape(Rectangle()) }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("lend.thing")
            }
        }
        .groundBackground()
        .overlay { if shown.isEmpty { ContentUnavailableView.search(text: query) } }
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Find a thing")
        .navigationTitle("Lend something").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
    }
}
