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
    @State private var addingPlace = false

    private var results: [Belonging] {
        _ = store.revision
        return ItemSearch.results(query: query, entries: store.searchIndex, archived: showArchived)
    }

    private var browsing: Bool { query.isEmpty && !putAway && !showArchived }

    private var dueSoon: [Deadline] {
        guard let horizon = CalendarDay(.now).adding(days: 30) else { return [] }
        return store.deadlines.filter { $0.active && ($0.day.map { $0 <= horizon } ?? false) }.sorted { $0.dayString < $1.dayString }
    }


    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                if store.items.isEmpty {
                    LibraryEmptyState(title: "Find it next time", systemImage: "shippingbox", description: "Save one belonging and where you put it. A name is enough to start.")
                    Button { showAdd = true } label: { Text("Add your first item").fixedSize(horizontal: false, vertical: true) }
                        .buttonStyle(PrimaryButtonStyle())
                } else if browsing {
                    dashboard
                } else {
                    if putAway {
                        Label("Choose an item, then confirm where you put it.", systemImage: "tray.and.arrow.down")
                            .font(.wbBody).foregroundStyle(.white)
                            .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.purpleFill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                    if results.isEmpty { ContentUnavailableView.search(text: query) }
                    else { Text(results.count == 1 ? "1 match" : "\(results.count) matches").font(.wbLabel).textCase(.uppercase).foregroundStyle(Theme.secondary) }
                    ForEach(results) { item in itemCard(item) }
                }
            }
            .padding(.horizontal, 20).padding(.vertical, 12)
        }
        .background(Theme.ground)
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
            ToolbarItem(placement: .topBarTrailing) { Button("Scan", systemImage: "doc.viewfinder") { scanning = true } }
            ToolbarSpacer(.fixed, placement: .topBarTrailing)
            ToolbarItem(placement: .topBarTrailing) { Button("Add item", systemImage: "plus") { showAdd = true }.buttonStyle(.borderedProminent).tint(Theme.purpleFill) }
        }
        .sheet(isPresented: $showAdd) { NavigationStack { ItemEditor() } }
        .sheet(isPresented: $scanning) { NavigationStack { ScanView() } }
        .sheet(isPresented: $settings) { NavigationStack { LibrarySettingsView() } }
        .sheet(isPresented: $addingPlace) { NavigationStack { PlaceEditor() } }
    }

    @ViewBuilder private var dashboard: some View {
        if !dueSoon.isEmpty {
            SectionHeading(title: "Due soon").padding(.top, 4)
            ForEach(dueSoon.prefix(2)) { deadline in
                NavigationLink { DeadlineDetailView(deadline: deadline) } label: { DueCard(deadline: deadline) }.buttonStyle(.plain)
            }
        }
        SectionHeading(title: "Places").padding(.top, 8)
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            ForEach(store.places.filter { $0.parent == nil }.prefix(5)) { place in
                NavigationLink { PlaceDetailView(place: place) } label: { PlaceTile(place: place) }.buttonStyle(.plain)
            }
            Button { addingPlace = true } label: {
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
            }.buttonStyle(.plain)
        }
        SectionHeading(title: "Recently added").padding(.top, 8)
        ForEach(results) { item in itemCard(item) }
    }

    private func itemCard(_ item: Belonging) -> some View {
        NavigationLink { ItemDetailView(item: item, putAway: putAway) } label: {
            HStack(spacing: 12) {
                ItemRow(item: item)
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(Theme.secondary).accessibilityHidden(true)
            }.card()
        }.buttonStyle(.plain)
    }
}

struct PlaceTile: View {
    let place: Place
    var body: some View {
        let count = place.activeItemCount
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: PlaceTile.symbol(for: place.name)).font(.title3).foregroundStyle(Theme.purpleInk).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(place.name).font(.wbItem).foregroundStyle(Theme.ink).lineLimit(2)
                Text(count == 1 ? "1 thing" : "\(count) things").font(.wbCaption).foregroundStyle(Theme.purpleInk)
            }
        }
        .padding(16).frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
        .background(Theme.mist, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .contentShape(Rectangle())
    }

    static func symbol(for name: String) -> String {
        let name = name.lowercased()
        let table: [(String, String)] = [("garage", "car"), ("kitchen", "fork.knife"), ("bed", "bed.double"), ("bath", "shower"), ("office", "desktopcomputer"), ("desk", "desktopcomputer"), ("closet", "hanger"), ("hall", "door.left.hand.closed"), ("living", "sofa"), ("storage", "archivebox"), ("locker", "lock"), ("car", "car"), ("basement", "stairs"), ("attic", "house"), ("drawer", "rectangle.split.1x2"), ("shelf", "books.vertical"), ("box", "shippingbox"), ("bin", "shippingbox")]
        return table.first { name.contains($0.0) }?.1 ?? "square.grid.2x2"
    }
}

extension Place {
    /// Unarchived belongings in this place and every place nested inside it.
    var activeItemCount: Int {
        var seen: Set<UUID> = []
        func count(_ place: Place) -> Int {
            guard seen.insert(place.id).inserted else { return 0 }
            return place.items.filter { !$0.archived }.count + place.children.reduce(0) { $0 + count($1) }
        }
        return count(self)
    }
}

struct DueCard: View {
    let deadline: Deadline
    var embedded = false
    var body: some View {
        let pill = DueLabel.pill(for: deadline.day)
        HStack(spacing: 14) {
            IconTile(systemImage: DueLabel.symbol(for: deadline.kind), photo: deadline.item?.photo, size: 48, tone: pill?.1 ?? .neutral)
            VStack(alignment: .leading, spacing: 2) {
                Text(deadline.item?.name ?? "Item unavailable").font(.wbItem).foregroundStyle(Theme.ink)
                Text(caption).font(.wbCaption).foregroundStyle(Theme.secondary)
            }
            Spacer(minLength: 8)
            if let pill { Pill(text: pill.0, tone: pill.1) }
        }
        .modifier(EmbeddedCard(embedded: embedded))
    }

    private var caption: String {
        let day = deadline.day?.formatted ?? "Date unavailable"
        switch deadline.kind {
        case .returns: return deadline.decision == .returning ? "Returning · drop off by \(day)" : "Return by \(day)"
        case .warranty: return "Warranty ends \(day)"
        case .expiry: return "Expires \(day)"
        case nil: return day
        }
    }
}

private struct EmbeddedCard: ViewModifier {
    let embedded: Bool
    func body(content: Content) -> some View { if embedded { content.contentShape(Rectangle()) } else { content.card() } }
}

struct ItemRow: View {
    @Environment(LocaliserStore.self) private var store
    let item: Belonging
    var body: some View {
        let _ = store.revision
        HStack(spacing: 14) {
            IconTile(systemImage: "shippingbox", photo: item.photo, size: 48)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.name).font(.wbItem).foregroundStyle(Theme.ink)
                HStack(spacing: 0) {
                    if !item.packedTrips.isEmpty { Text("Home: ").font(.wbCaption).foregroundStyle(Theme.secondary) }
                    PlaceBreadcrumb(path: item.place?.path)
                }
                if !item.packedTrips.isEmpty { Text("Packed for \(item.packedTrips.map(\.name).joined(separator: ", "))").font(.wbCaption).foregroundStyle(Theme.purpleInk) }
            }
            Spacer(minLength: 0)
        }.padding(.vertical, 2)
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
            Section {
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    if let photo, let image = UIImage(data: photo) {
                        Image(uiImage: image).resizable().scaledToFill().frame(maxWidth: .infinity).frame(height: 168).clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                            .accessibilityLabel(photoTitle)
                    } else {
                        VStack(spacing: 6) {
                            Image(systemName: "camera").font(.title2).accessibilityHidden(true)
                            Text("Snap a photo").font(.wbItem)
                            Text("Optional, but it helps you spot it").font(.wbCaption)
                        }
                        .foregroundStyle(Theme.purpleInk).frame(maxWidth: .infinity, minHeight: 148)
                        .background(Theme.mist, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Theme.purple.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])))
                        .accessibilityElement(children: .combine).accessibilityLabel(photoTitle)
                    }
                }.buttonStyle(.plain)
                if photo != nil { Button("Remove photo", role: .destructive) { self.photo = nil }.listRowBackground(Color.clear) }
            }.listRowBackground(Color.clear).listRowInsets(EdgeInsets())
            Section {
                TextField("Name", text: $name).focused($nameFocused).accessibilityIdentifier("item.name")
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
            } header: { Text("What is it?").font(.wbLabel).foregroundStyle(Theme.ink).textCase(nil) }
            Section {
                PlacePicker(selection: $placeID)
            } header: { Text("Where does it live?").font(.wbLabel).foregroundStyle(Theme.ink).textCase(nil) }
            Section {
                TextField("Notes", text: $notes, axis: .vertical)
                TextField("Aliases (one per line)", text: $aliases, axis: .vertical)
            } header: { Text("Optional details").font(.wbLabel).foregroundStyle(Theme.ink).textCase(nil) }
        }
        .groundBackground()
        .safeAreaInset(edge: .bottom) {
            Button(item == nil ? "Save item" : "Save changes") { save() }
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityIdentifier("item.save")
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .padding(.horizontal, 20).padding(.vertical, 12)
                .background(Theme.ground)
        }
        .navigationTitle(item == nil ? "New item" : "Edit item").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
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
                    VStack(alignment: .leading, spacing: 14) {
                        if let data = item.photo, let image = UIImage(data: data) {
                            Image(uiImage: image).resizable().scaledToFill().frame(maxWidth: .infinity).frame(height: 220)
                                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous)).accessibilityHidden(true)
                        }
                        HStack(spacing: 8) {
                            if item.archived { Pill(text: "Archived") }
                            else if !item.packedTrips.isEmpty { Pill(text: "Packed", tone: .due) }
                            else { Pill(text: "At home", tone: .done) }
                            if let moved = item.movements.map(\.date).max() { Text("Moved \(moved.formatted(.dateTime.month(.abbreviated).day()))").font(.wbCaption).foregroundStyle(Theme.secondary) }
                        }
                        Text(item.name).font(.wbDisplay).foregroundStyle(Theme.ink).fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 10) {
                            Image(systemName: "mappin.and.ellipse").foregroundStyle(Theme.purple).accessibilityHidden(true)
                            PlaceBreadcrumb(path: item.place?.path)
                        }
                        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.mist, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        if !item.notes.isEmpty { Text(item.notes) }
                        if !item.aliases.isEmpty { Text("Also called: \(item.aliases.replacingOccurrences(of: "\n", with: ", "))").font(.wbCaption).foregroundStyle(Theme.secondary) }
                    }.plainRow()
                }
                Section {
                    PlacePicker(selection: $destination)
                    Button(putAway ? "Confirm put away here" : "Found here / move here") {
                        do { try store.move(item, to: store.places.first { $0.id == destination }) } catch { self.error = error.localizedDescription }
                    }.buttonStyle(PrimaryButtonStyle()).listRowBackground(Color.clear).listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 0, trailing: 0))
                } header: { Text(putAway ? "Put away" : "Location").foregroundStyle(Theme.secondary) }
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
        .groundBackground()
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
