import SwiftUI

struct PlacesView: View {
    @Environment(LocaliserStore.self) private var store
    @State private var adding = false
    @State private var error: String?
    private let starters = ["Kitchen", "Bedroom", "Garage", "Hall cupboard", "Office", "Loft"]
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if store.places.isEmpty {
                    LibraryEmptyState(title: "Where do you keep things?", systemImage: "shippingbox", description: "Add a room, then the drawers, shelves and boxes inside it.")
                    Text("Quick start").font(.wbLabel).foregroundStyle(Theme.secondary).textCase(.uppercase)
                    FlowLayout(spacing: 8) {
                        ForEach(starters, id: \.self) { name in
                            Button { addStarter(name) } label: { Label(name, systemImage: "plus").font(.wbItem) }
                                .buttonStyle(SoftButtonStyle(compact: true))
                        }
                    }
                    Button("Add a place") { adding = true }.buttonStyle(PrimaryButtonStyle())
                } else {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        ForEach(store.places.filter { $0.parent == nil }) { place in
                            NavigationLink { PlaceDetailView(place: place) } label: { PlaceTile(place: place) }.buttonStyle(.plain)
                        }
                        NewPlaceTile { adding = true }
                    }
                }
            }
            .padding(.horizontal, 20).padding(.vertical, 12)
        }
        .background(Theme.ground).navigationTitle("Places")
        .toolbar { Button("Add place", systemImage: "plus") { adding = true } }
        .sheet(isPresented: $adding) { NavigationStack { PlaceEditor() } }
        .alert("Couldn't add that place", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") { error = nil } } message: { Text(error ?? "") }
    }

    private func addStarter(_ name: String) {
        do { try store.addPlace(name: name) } catch { self.error = error.localizedDescription }
    }
}

/// The dashed "New place" tile used on Find and Places.
struct NewPlaceTile: View {
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 14) {
                Image(systemName: "plus").font(.title3.weight(.semibold)).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("New place").font(.wbItem)
                    Text("Room, shelf or box").font(.wbCaption).foregroundStyle(Theme.secondary)
                }
            }
            .foregroundStyle(Theme.purpleInk)
            .padding(16).frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Theme.purple.opacity(0.6), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Wraps chips onto as many lines as they need.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, line: CGFloat = 0, widest: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > width { y += line + spacing; x = 0; line = 0 }
            x += size.width + spacing; line = max(line, size.height); widest = max(widest, x - spacing)
        }
        return CGSize(width: min(widest, width), height: y + line)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, line: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX { y += line + spacing; x = bounds.minX; line = 0 }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing; line = max(line, size.height)
        }
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
    private var parent: Place? { store.places.first { $0.id == parentID } }
    private var duplicate: Place? { store.duplicatePlace(named: name, parent: parent, excluding: place) }
    var body: some View {
        Form {
            Section {
                TextField("Name, like Kitchen or Top drawer", text: $name).accessibilityIdentifier("place.name")
                if let duplicate {
                    Label("\u{201C}\(duplicate.path)\u{201D} already exists. You can still save another one.", systemImage: "exclamationmark.triangle")
                        .font(.wbCaption).foregroundStyle(Theme.warning)
                }
            }
            Section {
                PlacePicker(selection: $parentID, excluded: place, title: "Inside")
            } footer: { Text("Leave as Unspecified for a room or other top-level place.").foregroundStyle(Theme.secondary) }
        }
        .groundBackground()
        .navigationTitle(place == nil ? "New place" : "Edit place").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("Save") {
                do {
                    if let place { try store.editPlace(place, name: name, parent: parent) }
                    else { try store.addPlace(name: name, parent: parent) }
                    dismiss()
                } catch { self.error = error.localizedDescription }
            }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
        }
        .alert("Couldn't save", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") { error = nil } } message: { Text(error ?? "") }
    }
}

struct PlaceDetailView: View {
    @Environment(LocaliserStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let place: Place
    @State private var editing = false
    @State private var adding = false
    @State private var addingItem = false
    @State private var deleting = false
    @State private var error: String?
    private var available: Bool { place.managedObjectContext != nil && !place.isDeleted }

    /// Every unarchived item here or in any place inside, nearest first.
    private var nestedItems: [Belonging] {
        store.items.filter { !$0.archived && ($0.place.map { $0.isWithin(place) } ?? false) }
            .sorted { ($0.place == place ? 0 : 1, $0.name) < ($1.place == place ? 0 : 1, $1.name) }
    }

    var body: some View {
        let _ = store.revision
        List {
            if available {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(place.name).font(.wbDisplay).foregroundStyle(Theme.ink)
                        if place.parent != nil { PlaceBreadcrumb(path: place.path) }
                        let count = place.activeItemCount
                        Text(count == 1 ? "1 thing" : "\(count) things").font(.wbCaption).foregroundStyle(Theme.purpleInk)
                    }.plainRow()
                    HStack(spacing: 10) {
                        Button("Add item", systemImage: "plus") { addingItem = true }.buttonStyle(SoftButtonStyle(compact: true))
                        Button("Add place", systemImage: "square.stack") { adding = true }.buttonStyle(SoftButtonStyle(compact: true))
                    }.plainRow()
                }
                if !place.children.isEmpty {
                    Section("Places inside") {
                        ForEach(place.children.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }) { child in
                            NavigationLink { PlaceDetailView(place: child) } label: {
                                HStack {
                                    Label { Text(child.name) } icon: { Image(systemName: PlaceTile.symbol(for: child.name)).foregroundStyle(Theme.purple) }
                                    Spacer()
                                    Text("\(child.activeItemCount)").font(.wbCaption).foregroundStyle(Theme.secondary)
                                }
                            }
                        }
                    }
                }
                Section {
                    if nestedItems.isEmpty {
                        Text("Nothing here yet.").foregroundStyle(Theme.secondary)
                    }
                    ForEach(nestedItems) { item in
                        NavigationLink { ItemDetailView(item: item) } label: { ItemRow(item: item) }
                    }
                } header: { Text("Things here").foregroundStyle(Theme.secondary) }
                  footer: { if !place.children.isEmpty && !nestedItems.isEmpty { Text("Includes things in the places inside.").foregroundStyle(Theme.secondary) } }
                Section { Button("Delete place", role: .destructive) { deleting = true } }
            } else { ContentUnavailableView("Place deleted", systemImage: "trash") }
        }
        .groundBackground()
        .navigationTitle(available ? place.name : "").navigationBarTitleDisplayMode(.inline)
        .toolbar { if available { Button("Edit") { editing = true } } }
        .sheet(isPresented: $editing) { NavigationStack { PlaceEditor(place: place) } }
        .sheet(isPresented: $adding) { NavigationStack { PlaceEditor(parent: place) } }
        .sheet(isPresented: $addingItem) { NavigationStack { ItemEditor(place: place) } }
        .onChange(of: store.revision) { _, _ in if !available { dismiss() } }
        .confirmationDialog("Delete \u{201C}\(available ? place.name : "")\u{201D}?", isPresented: $deleting, titleVisibility: .visible) {
            Button("Delete place", role: .destructive) {
                do { try store.deletePlace(place, clearContents: true); dismiss() } catch { self.error = error.localizedDescription }
            }
        } message: {
            Text("Things stored directly here will have no place set. Places inside move up to the top level. Nothing else is deleted.")
        }
        .alert("Couldn't delete", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") { error = nil } } message: { Text(error ?? "") }
    }
}
