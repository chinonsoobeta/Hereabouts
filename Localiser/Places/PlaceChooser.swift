import SwiftUI

@MainActor extension LocaliserStore {
    /// Splits "Garage › Shelf 2", "Garage > Shelf 2" or "Garage / Shelf 2" into levels.
    static func pathComponents(_ text: String) -> [String] {
        text.components(separatedBy: CharacterSet(charactersIn: "›>/"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    /// Finds or creates each level of a typed path under `parent`, reusing places that already exist.
    @discardableResult
    func place(forPath text: String, under parent: Place? = nil) throws -> Place {
        let parts = Self.pathComponents(text)
        guard !parts.isEmpty else { throw LocaliserError.nameRequired }
        for part in parts { _ = try requiredName(part) }
        var current = parent
        for part in parts {
            if let existing = duplicatePlace(named: part, parent: current) { current = existing }
            else { current = try addPlace(name: part, parent: current) }
        }
        return current!
    }

    /// The deepest level of a typed path that already exists, or `parent` when even the first level is new.
    func deepestExistingPlace(forPath text: String, under parent: Place? = nil) -> Place? {
        var current = parent
        for part in Self.pathComponents(text) {
            guard let existing = duplicatePlace(named: part, parent: current) else { break }
            current = existing
        }
        return current
    }
}

/// A form row that opens the place chooser. Shows the chosen place as a breadcrumb.
struct PlacePicker: View {
    @Environment(LocaliserStore.self) private var store
    @Binding var selection: UUID?
    var excluded: Place? = nil
    var title = "Place"
    /// What "no place" is called here: a thing without a place yet, or a place that isn't inside another.
    var noneTitle = "No place yet"
    var body: some View {
        let _ = store.revision
        NavigationLink {
            PlaceChooser(selection: $selection, excluded: excluded, noneTitle: noneTitle)
        } label: {
            HStack(spacing: 12) {
                Text(title).foregroundStyle(Theme.ink)
                Spacer(minLength: 8)
                if let place = store.places.first(where: { $0.id == selection }) {
                    PlaceBreadcrumb(path: place.path).multilineTextAlignment(.trailing)
                } else {
                    Text(noneTitle).font(.wbCaption).foregroundStyle(Theme.secondary)
                }
            }
        }
        .accessibilityIdentifier("place.picker")
    }
}

/// Pick an existing place, or type a new one (or a whole path) and create it in one step.
struct PlaceChooser: View {
    @Environment(LocaliserStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Binding var selection: UUID?
    var excluded: Place? = nil
    var noneTitle = "No place yet"
    @State private var query = ""
    @State private var error: String?

    private var candidates: [Place] {
        let allowed = store.places.filter { place in excluded.map { !place.isWithin($0) } ?? true }
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return allowed }
        return allowed.filter { $0.path.localizedStandardContains(text) }
    }
    private var typed: [String] { LocaliserStore.pathComponents(query) }
    private var exactMatch: Place? {
        let wanted = typed.joined(separator: " › ")
        return store.places.first { $0.path.localizedCaseInsensitiveCompare(wanted) == .orderedSame }
    }
    private var duplicateName: Place? {
        guard typed.count == 1, exactMatch == nil else { return nil }
        return store.places.first { $0.name.localizedCaseInsensitiveCompare(typed[0]) == .orderedSame }
    }

    var body: some View {
        let _ = store.revision
        SheetList {
            if !typed.isEmpty, exactMatch == nil {
                Section {
                    Button {
                        create()
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Create \u{201C}\(typed.joined(separator: " › "))\u{201D}").font(.wbItem).foregroundStyle(Theme.purpleInk)
                                if typed.count > 1 { Text("Creates any levels that don't exist yet").font(.wbCaption).foregroundStyle(Theme.secondary) }
                            }
                        } icon: { Image(systemName: "plus.circle.fill").foregroundStyle(Theme.purple) }
                    }
                    .accessibilityIdentifier("place.create")
                    if let duplicateName {
                        Label("You already have \u{201C}\(duplicateName.path)\u{201D}. Tap it below if that's the one.", systemImage: "exclamationmark.triangle")
                            .font(.wbCaption).foregroundStyle(Theme.warning)
                    }
                }
            }
            Section {
                row(title: noneTitle, detail: noneTitle == "None" ? "A room or other top-level place" : "Not sure yet", id: nil)
                ForEach(candidates) { place in row(title: place.name, detail: place.parent?.path, id: place.id, depth: depth(of: place)) }
            } footer: {
                if store.places.isEmpty { Text("Type a place above, like Kitchen or Garage › Shelf 2.").foregroundStyle(Theme.secondary) }
            }
        }
        .groundBackground()
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Find or create a place")
        .onSubmit(of: .search) { if !typed.isEmpty { create() } }
        .navigationTitle("Choose a place").navigationBarTitleDisplayMode(.inline)
        .alert("Couldn't create that place", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") { error = nil } } message: { Text(error ?? "") }
    }

    private func depth(of place: Place) -> Int {
        query.isEmpty ? place.path.components(separatedBy: " › ").count - 1 : 0
    }

    private func row(title: String, detail: String?, id: UUID?, depth: Int = 0) -> some View {
        Button { choose(id) } label: {
            HStack(spacing: 10) {
                Image(systemName: id == nil ? "questionmark.circle" : PlaceTile.symbol(for: title)).foregroundStyle(Theme.purpleInk).frame(width: 24).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.wbBody).foregroundStyle(Theme.ink)
                    if let detail, !detail.isEmpty, !query.isEmpty || id == nil { Text(detail).font(.wbCaption).foregroundStyle(Theme.secondary) }
                }
                Spacer(minLength: 8)
                if selection == id { Image(systemName: "checkmark").foregroundStyle(Theme.purple).accessibilityHidden(true) }
            }
            .padding(.leading, CGFloat(min(depth, 4)) * 18)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(id == nil ? noneTitle : (store.places.first { $0.id == id }?.path ?? title))
        .accessibilityAddTraits(selection == id ? .isSelected : [])
    }

    private func choose(_ id: UUID?) { selection = id; dismiss() }

    /// Chooses the typed path, creating any levels that don't exist yet. A path that would end inside the place
    /// being edited is refused before anything is created, so nothing is left behind.
    private func create() {
        do {
            if let excluded, store.deepestExistingPlace(forPath: query)?.isWithin(excluded) == true { throw LocaliserError.placeCycle }
            choose(try store.place(forPath: query, under: nil).id)
        } catch { self.error = error.localizedDescription }
    }
}
