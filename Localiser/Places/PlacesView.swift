import SwiftUI

struct PlacesView: View {
    @Environment(LocaliserStore.self) private var store
    @State private var adding = false
    var body: some View {
        List {
            if store.places.isEmpty { LibraryEmptyState(title: "Where do you keep things?", systemImage: "shippingbox", description: "Add a room, drawer, shelf, or box. You can put one place inside another.") }
            ForEach(store.places) { place in
                NavigationLink { PlaceDetailView(place: place) } label: {
                    VStack(alignment: .leading) { Text(place.path); Text("\(place.items.filter { !$0.archived }.count) items · \(place.children.count) places").font(.caption).foregroundStyle(Theme.secondary) }
                }
            }
        }
        .scrollContentBackground(.hidden).background(Theme.ground).navigationTitle("Places")
        .toolbar { Button("Add place", systemImage: "plus") { adding = true } }
        .sheet(isPresented: $adding) { NavigationStack { PlaceEditor() } }
    }
}

struct PlaceEditor: View {
    @Environment(LocaliserStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var place: Place?
    @State private var name: String
    @State private var parentID: UUID?
    @State private var error: String?
    init(place: Place? = nil, parent: Place? = nil) {
        self.place = place
        _name = State(initialValue: place?.name ?? "")
        _parentID = State(initialValue: place?.parent?.id ?? parent?.id)
    }
    var body: some View {
        Form {
            TextField("Place name", text: $name).accessibilityIdentifier("place.name")
            PlacePicker(selection: $parentID, excluded: place)
        }
        .navigationTitle(place == nil ? "Add place" : "Edit place").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("Save") {
                do {
                    let parent = store.places.first { $0.id == parentID }
                    if let place { try store.editPlace(place, name: name, parent: parent) }
                    else { try store.addPlace(name: name, parent: parent) }
                    dismiss()
                } catch { self.error = error.localizedDescription }
            }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
        }
        .alert("Could not save", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") { error = nil } } message: { Text(error ?? "") }
    }
}

struct PlaceDetailView: View {
    @Environment(LocaliserStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let place: Place
    @State private var editing = false
    @State private var adding = false
    @State private var deleting = false
    @State private var error: String?
    var body: some View {
        let _ = store.revision
        List {
            Text(place.path).foregroundStyle(Theme.secondary)
            Section("Places inside") {
                ForEach(place.children.sorted { $0.name < $1.name }) { child in NavigationLink(child.name) { PlaceDetailView(place: child) } }
                Button("Add a place inside") { adding = true }
            }
            Section("Belongings") {
                ForEach(place.items.filter { !$0.archived }.sorted { $0.name < $1.name }) { item in NavigationLink { ItemDetailView(item: item) } label: { ItemRow(item: item) } }
            }
            Section { Button("Delete place", role: .destructive) { deleting = true } }
        }
        .navigationTitle(place.name).navigationBarTitleDisplayMode(.inline)
        .toolbar { Button("Edit") { editing = true } }
        .sheet(isPresented: $editing) { NavigationStack { PlaceEditor(place: place) } }
        .sheet(isPresented: $adding) { NavigationStack { PlaceEditor(parent: place) } }
        .confirmationDialog("Delete this place? Its items will have unspecified locations, and its child places will move to the top level.", isPresented: $deleting, titleVisibility: .visible) {
            Button("Clear locations and delete", role: .destructive) {
                do { try store.deletePlace(place, clearContents: true); dismiss() } catch { self.error = error.localizedDescription }
            }
        }
        .alert("Could not delete", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") { error = nil } } message: { Text(error ?? "") }
    }
}
