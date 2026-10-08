import SwiftUI
import PhotosUI

struct FindView: View {
    @Environment(LocaliserStore.self) private var store
    @State private var query = ""
    @State private var showAdd = false
    @State private var scanning = false
    @State private var showArchived = false
    @State private var putAway = false
    @State private var settings = false

    private var results: [Belonging] {
        _ = store.revision
        return ItemSearch.results(query: query, entries: store.searchIndex, archived: showArchived)
    }

    var body: some View {
        List {
            if store.items.isEmpty {
                Section { LibraryEmptyState(title: "Find it next time", systemImage: "shippingbox", description: "Save one belonging and where you put it. A name is enough to start.")
                    Button { showAdd = true } label: { Text("Add your first item").font(.body).fixedSize(horizontal: false, vertical: true) }
                }
            } else {
                if putAway { Text("Choose an item, then confirm where you put it.").foregroundStyle(Theme.secondary) }
                if results.isEmpty { ContentUnavailableView.search(text: query) }
                ForEach(results) { item in
                    NavigationLink { ItemDetailView(item: item, putAway: putAway) } label: { ItemRow(item: item) }
                }
            }
        }
        .scrollContentBackground(.hidden).background(Theme.ground)
        .navigationTitle("Localiser")
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    Toggle("Archived items", isOn: $showArchived)
                    Toggle("Put-away mode", isOn: $putAway)
                    Button("Settings and backup") { settings = true }
                } label: { Image(systemName: "line.3.horizontal.decrease") }
                .accessibilityLabel("Find options")
            }
            ToolbarItem(placement: .topBarTrailing) { Button("Add item", systemImage: "plus") { showAdd = true } }
            ToolbarItem(placement: .topBarTrailing) { Button("Scan", systemImage: "doc.viewfinder") { scanning = true } }
        }
        .sheet(isPresented: $showAdd) { NavigationStack { ItemEditor() } }
        .sheet(isPresented: $scanning) { NavigationStack { ScanView() } }
        .sheet(isPresented: $settings) { NavigationStack { LibrarySettingsView() } }
    }
}

struct ItemRow: View {
    @Environment(LocaliserStore.self) private var store
    let item: Belonging
    var body: some View {
        let _ = store.revision
        HStack(spacing: 12) {
            if let data = item.photo, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill().frame(width: 44, height: 44).clipShape(RoundedRectangle(cornerRadius: 10)).accessibilityHidden(true)
            } else { Image(systemName: "shippingbox").foregroundStyle(Theme.purple).frame(width: 44).accessibilityHidden(true) }
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name).font(.headline)
                Text((item.packedTrips.isEmpty ? "" : "Home: ") + (item.place?.path ?? "Location unspecified")).font(.subheadline).foregroundStyle(Theme.secondary)
                if !item.packedTrips.isEmpty { Text("Packed for \(item.packedTrips.map(\.name).joined(separator: ", "))").font(.caption).foregroundStyle(Theme.purple) }
            }
        }.padding(.vertical, 4)
    }
}

struct ItemEditor: View {
    @Environment(LocaliserStore.self) private var store
    @Environment(ProAccess.self) private var pro
    @Environment(\.dismiss) private var dismiss
    let item: Belonging?
    @State private var name: String
    @State private var notes: String
    @State private var aliases: String
    @State private var placeID: UUID?
    @State private var photo: Data?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var error: String?
    @State private var suggestion: ItemSearch.CaptureSuggestion?
    @State private var upgrade = false
    @FocusState private var nameFocused: Bool

    init(item: Belonging? = nil) {
        self.item = item
        _name = State(initialValue: item?.name ?? ""); _notes = State(initialValue: item?.notes ?? "")
        _aliases = State(initialValue: item?.aliases ?? ""); _placeID = State(initialValue: item?.place?.id)
        _photo = State(initialValue: item?.photo)
    }

    var body: some View {
        let photoTitle = photo == nil ? "Add photo" : "Replace photo"
        Form {
            Section("Belonging") {
                TextField("Name", text: $name).focused($nameFocused).accessibilityIdentifier("item.name")
                PlacePicker(selection: $placeID)
                if item == nil {
                    Button("Suggest name and place from sentence") {
                        suggestion = ItemSearch.suggestion(name, places: store.places.map { ($0.id, $0.path) })
                        if suggestion == nil { error = "Try a sentence such as ‘Passport is in Bedroom › Drawer’. Review the suggestion before saving." }
                    }.font(.subheadline)
                    if let suggestion {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Suggested name: \(suggestion.name)")
                            Text(suggestion.placeID.flatMap { id in store.places.first { $0.id == id }?.path } ?? "Confirm a place: \(suggestion.unrecognizedPlace ?? "Unknown")")
                            Button("Use suggestion") { name = suggestion.name; placeID = suggestion.placeID; self.suggestion = nil }
                        }
                    }
                }
            }
            Section("Optional details") {
                TextField("Notes", text: $notes, axis: .vertical)
                TextField("Aliases (one per line)", text: $aliases, axis: .vertical)
                PhotosPicker(selection: $selectedPhoto, matching: .images) { Label(photoTitle, systemImage: "photo") }
                if let photo, let image = UIImage(data: photo) {
                    Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 180)
                    Button("Remove photo", role: .destructive) { self.photo = nil }
                }
            }
        }
        .navigationTitle(item == nil ? "Add item" : "Edit item").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("Save") { save() }.accessibilityIdentifier("item.save").disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
        }
        .onAppear { nameFocused = item == nil }
        .sheet(isPresented: $upgrade) { NavigationStack { ProView() } }
        .onChange(of: selectedPhoto) { _, newValue in
            Task {
                do {
                    guard let data = try await newValue?.loadTransferable(type: Data.self), let image = UIImage(data: data) else { throw CocoaError(.fileReadCorruptFile) }
                    let scale = min(1, 1600 / max(image.size.width, image.size.height))
                    let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
                    let format = UIGraphicsImageRendererFormat(); format.scale = 1
                    photo = UIGraphicsImageRenderer(size: size, format: format).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }.jpegData(compressionQuality: 0.8)
                } catch { self.error = error.localizedDescription }
            }
        }
        .alert("Could not save", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") { error = nil } } message: { Text(error ?? "") }
    }

    private func save() {
        if item == nil && !pro.allows(.item, count: store.items.count) { upgrade = true; return }
        do {
            let place = store.places.first { $0.id == placeID }
            if let item { try store.editItem(item, name: name, place: place, notes: notes, aliases: aliases, photo: photo) }
            else { try store.addItem(name: name, place: place, notes: notes, aliases: aliases, photo: photo) }
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}

struct PlacePicker: View {
    @Environment(LocaliserStore.self) private var store
    @Binding var selection: UUID?
    var excluded: Place? = nil
    var body: some View {
        Picker("Place", selection: $selection) {
            Text("Unspecified").tag(nil as UUID?)
            ForEach(store.places.filter { place in excluded.map { !place.isWithin($0) } ?? true }) { place in Text(place.path).tag(Optional(place.id)) }
        }
    }
}

struct ItemDetailView: View {
    @Environment(LocaliserStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let item: Belonging
    var putAway = false
    @State private var editing = false
    @State private var addingDate = false
    @State private var destination: UUID?
    @State private var error: String?
    @State private var deleting = false
    private var available: Bool { item.managedObjectContext != nil && !item.isDeleted }

    var body: some View {
        let _ = store.revision
        List {
            if available {
                Section {
                    ItemRow(item: item)
                    if !item.notes.isEmpty { Text(item.notes) }
                    if !item.aliases.isEmpty { Text("Also called: \(item.aliases.replacingOccurrences(of: "\n", with: ", "))").foregroundStyle(Theme.secondary) }
                }
                Section(putAway ? "Put away" : "Location") {
                    PlacePicker(selection: $destination)
                    Button(putAway ? "Confirm put away here" : "Found here / move here") {
                        do { try store.move(item, to: store.places.first { $0.id == destination }) } catch { self.error = error.localizedDescription }
                    }
                }
                if !item.packedTrips.isEmpty {
                    Section("Packed trips") { ForEach(item.packedTrips) { trip in NavigationLink(trip.name) { TripDetailView(trip: trip) } } }
                }
                Section("Dates") {
                    ForEach(item.deadlines.sorted { $0.dayString < $1.dayString }) { deadline in
                        NavigationLink { DeadlineDetailView(deadline: deadline) } label: { DeadlineRow(deadline: deadline) }
                    }
                    Button("Add date") { addingDate = true }
                }
                if !item.scans.isEmpty {
                    Section("Scans") {
                        ForEach(item.scans.sorted { $0.createdAt > $1.createdAt }) { scan in
                            NavigationLink { StoredScanView(scan: scan) } label: {
                                VStack(alignment: .leading) { Text(scan.filename); Text(scan.createdAt, format: .dateTime.year().month().day()).font(.caption).foregroundStyle(Theme.secondary) }
                            }
                        }
                    }
                }
                if !item.movements.isEmpty {
                    Section("Location history") {
                        ForEach(item.movements.sorted { $0.date > $1.date }) { movement in
                            VStack(alignment: .leading) {
                                Text("\(movement.fromPath) → \(movement.toPath)")
                                Text(movement.date, format: .dateTime.month().day().hour().minute()).font(.caption).foregroundStyle(Theme.secondary)
                            }
                        }
                    }
                }
                Section { Button(item.archived ? "Restore item" : "Archive item") {
                    do { try store.setArchived(item, !item.archived) } catch { self.error = error.localizedDescription }
                }; Button("Delete item permanently", role: .destructive) { deleting = true } }
            } else { ContentUnavailableView("Item deleted", systemImage: "trash") }
        }
        .navigationTitle(available ? item.name : "Item deleted").navigationBarTitleDisplayMode(.inline)
        .toolbar { if available { Button("Edit") { editing = true } } }
        .sheet(isPresented: $editing) { NavigationStack { ItemEditor(item: item) } }
        .sheet(isPresented: $addingDate) { NavigationStack { DeadlineEditor(item: item) } }
        .onAppear { if available { destination = item.place?.id } }
        .onChange(of: store.revision) { _, _ in if available { destination = item.place?.id } else { dismiss() } }
        .confirmationDialog("Delete this item, its dates, scans and location history? Existing kit and trip rows will remain as unlinked checklist rows.", isPresented: $deleting, titleVisibility: .visible) {
            Button("Delete item permanently", role: .destructive) {
                do { try store.deleteItem(item); dismiss() } catch { self.error = error.localizedDescription }
            }
        }
        .alert("Could not update", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") { error = nil } } message: { Text(error ?? "") }
    }
}
