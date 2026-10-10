import SwiftUI
import PhotosUI
import TipKit

struct FindView: View {
    @Environment(LocaliserStore.self) private var store
    @State private var query = ""
    @State private var showAdd = false
    @State private var scanning = false
    @State private var showArchived = false
    @State private var putAway = false
    @State private var settings = false
    @State private var addingPlace = false
    @State private var openedItem: Belonging?
    @AppStorage(Home.nameKey) private var homeName = ""

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
                    LibraryEmptyState(title: "Find it next time", systemImage: "magnifyingglass", description: "Save something and where you put it. A name is enough to start, like \u{201C}Spare keys\u{201D} in \u{201C}Kitchen › Top drawer\u{201D}.")
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
        .navigationTitle("Hereabouts")
        .navigationSubtitle("\(homeName.isEmpty ? Home.defaultName : homeName) · \(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)))")
        .navigationDestination(item: $openedItem) { item in ItemDetailView(item: item) }
        .onChange(of: store.openedItem, initial: true) { _, id in
            guard let id else { return }
            openedItem = store.items.first { $0.id == id }
            store.openedItem = nil
        }
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Where is…")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { Button("Settings", systemImage: "gear") { settings = true } }
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    Toggle("Show archived items", systemImage: "archivebox", isOn: $showArchived)
                    Toggle("Put-away mode", systemImage: "tray.and.arrow.down", isOn: $putAway)
                } label: { Image(systemName: "line.3.horizontal.decrease") }
                .accessibilityLabel("Find options")
                .popoverTip(PutAwayTip())
            }
            ToolbarItem(placement: .topBarTrailing) { Button("Scan", systemImage: "doc.viewfinder") { scanning = true }.popoverTip(ScanTip()) }
            ToolbarSpacer(.fixed, placement: .topBarTrailing)
            ToolbarItem(placement: .topBarTrailing) { Button("Add item", systemImage: "plus") { showAdd = true }.buttonStyle(.borderedProminent).tint(Theme.purpleFill) }
        }
        .onChange(of: store.items.count, initial: true) { _, count in ScanTip.itemCount = count }
        .sheet(isPresented: $showAdd) { NavigationStack { ItemEditor() } }
        .sheet(isPresented: $scanning) { NavigationStack { ScanView() } }
        .sheet(isPresented: $settings) { NavigationStack { LibrarySettingsView() } }
        .sheet(isPresented: $addingPlace) { NavigationStack { PlaceEditor() } }
    }

    @ViewBuilder private var dashboard: some View {
        if !dueSoon.isEmpty {
            HStack {
                SectionHeading(title: "Due")
                Spacer()
                NavigationLink("All dates") { DueView() }.font(.wbLabel).foregroundStyle(Theme.purpleInk)
            }.padding(.top, 4)
            ForEach(dueSoon.prefix(2)) { deadline in
                NavigationLink { DeadlineDetailView(deadline: deadline) } label: { DueCard(deadline: deadline) }.buttonStyle(.plain)
            }
        }
        HStack {
            SectionHeading(title: "Places")
            Spacer()
            if store.places.contains(where: { $0.parent == nil }) { NavigationLink("All places") { PlacesView() }.font(.wbLabel).foregroundStyle(Theme.purpleInk) }
        }.padding(.top, 8)
        VStack(spacing: 0) {
            ForEach(store.places.filter { $0.parent == nil }.prefix(3)) { place in
                NavigationLink { PlaceDetailView(place: place) } label: { PlaceTile(place: place) }.buttonStyle(.plain)
            }
            NewPlaceTile { addingPlace = true }
        }
        SectionHeading(title: "Put away lately").padding(.top, 8)
        ForEach(results.sorted { ($0.movements.map(\.date).max() ?? $0.createdAt) > ($1.movements.map(\.date).max() ?? $1.createdAt) }.prefix(3)) { item in itemCard(item) }
    }

    private func itemCard(_ item: Belonging) -> some View {
        NavigationLink { ItemDetailView(item: item, putAway: putAway) } label: {
            HStack(spacing: 12) {
                ItemRow(item: item, query: query)
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(Theme.secondary).accessibilityHidden(true)
            }.card()
        }.buttonStyle(.plain)
    }
}

struct PlaceTile: View {
    let place: Place
    var body: some View {
        let count = place.activeItemCount
        NotebookLine(name: place.name, detail: count == 1 ? "1 thing" : "\(count) things")
            .padding(.vertical, 14).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .overlay(alignment: .bottom) { Rectangle().fill(Theme.rule).frame(height: 1) }
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
                NotebookLine(name: deadline.item?.name ?? "Thing unavailable", detail: caption)
            }
            Spacer(minLength: 8)
            if let pill { Stamp(text: pill.0, tone: pill.1) }
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
    var query = ""
    var body: some View {
        let _ = store.revision
        HStack(spacing: 14) {
            IconTile(systemImage: "shippingbox", photo: item.photo, size: 48)
            VStack(alignment: .leading, spacing: 3) {
                NotebookLine(name: item.name, detail: item.place.map { "lives in " + $0.path } ?? "Place not written down", query: query)
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
    @State private var choosingPhoto = false
    @State private var takingPhoto = false
    @State private var error: String?
    @State private var suggestion: ItemSearch.CaptureSuggestion?
    @State private var upgrade = false
    @FocusState private var nameFocused: Bool

    init(item: Belonging? = nil, place: Place? = nil) {
        self.item = item
        _name = State(initialValue: item?.name ?? ""); _notes = State(initialValue: item?.notes ?? "")
        _aliases = State(initialValue: item?.aliases ?? ""); _placeID = State(initialValue: item?.place?.id ?? place?.id)
        _photo = State(initialValue: item?.photo)
    }

    var body: some View {
        Form {
            Section {
                Menu {
                    if CameraPicker.isAvailable { Button("Take photo", systemImage: "camera") { takingPhoto = true } }
                    Button("Choose from library", systemImage: "photo.on.rectangle") { choosingPhoto = true }
                    if photo != nil { Button("Remove photo", systemImage: "trash", role: .destructive) { photo = nil } }
                } label: {
                    if let photo, let image = UIImage(data: photo) {
                        Image(uiImage: image).resizable().scaledToFill().frame(maxWidth: .infinity).frame(height: 168).clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                            .overlay(alignment: .bottomTrailing) {
                                Label("Change", systemImage: "camera").font(.wbLabel).foregroundStyle(Theme.purpleInk)
                                    .padding(.horizontal, 12).padding(.vertical, 8).background(Theme.card, in: Capsule()).padding(10)
                            }
                    } else {
                        VStack(spacing: 6) {
                            Image(systemName: "camera").font(.title2).accessibilityHidden(true)
                            Text("Add a photo").font(.wbItem)
                            Text("Optional, but it helps you spot it").font(.wbCaption)
                        }
                        .foregroundStyle(Theme.purpleInk).frame(maxWidth: .infinity, minHeight: 148)
                        .background(Theme.mist, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Theme.purple.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])))
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(photo == nil ? "Add photo" : "Change photo")
            }.listRowBackground(Color.clear).listRowInsets(EdgeInsets())
            Section {
                TextField("Name", text: $name).focused($nameFocused).submitLabel(.done).onSubmit { nameFocused = false }.accessibilityIdentifier("item.name")
                if name.count > TextLimit.name - 20 { counter(name, TextLimit.name) }
                if item == nil && name.split(separator: " ").count >= 3 && suggestion == nil {
                    Button("Split into name and place", systemImage: "wand.and.stars") {
                        suggestion = ItemSearch.suggestion(name, places: store.places.map { ($0.id, $0.path) })
                        if suggestion == nil { error = "Try a sentence such as \u{201C}passport in the bedroom drawer\u{201D}. You'll see the suggestion before anything changes." }
                    }.font(.subheadline)
                }
                if item == nil {
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
                TextField("Notes", text: $notes, axis: .vertical).lineLimit(2...8)
                if notes.count > TextLimit.notes - 500 { counter(notes, TextLimit.notes) }
                TextField("Other names, one per line", text: $aliases, axis: .vertical).lineLimit(1...6)
                if aliases.count > TextLimit.aliases - 200 { counter(aliases, TextLimit.aliases) }
            } header: { Text("Optional details").font(.wbLabel).foregroundStyle(Theme.ink).textCase(nil) }
              footer: { Text("Other names help search. Add what you might type later, like \u{201C}ID\u{201D} for a passport.").foregroundStyle(Theme.secondary) }
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
            ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { nameFocused = false; UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) } }
        }
        .onAppear { nameFocused = item == nil }
        .sheet(isPresented: $upgrade) { NavigationStack { ProView() } }
        .photosPicker(isPresented: $choosingPhoto, selection: $selectedPhoto, matching: .images)
        .fullScreenCover(isPresented: $takingPhoto) { CameraPicker { photo = PhotoResize.jpeg($0) }.ignoresSafeArea() }
        .onChange(of: selectedPhoto) { _, newValue in
            guard let newValue else { return }
            Task {
                do {
                    guard let data = try await newValue.loadTransferable(type: Data.self), let image = UIImage(data: data) else { throw CocoaError(.fileReadCorruptFile) }
                    photo = PhotoResize.jpeg(image)
                } catch { self.error = "That photo couldn't be opened. Try another one." }
                selectedPhoto = nil
            }
        }
        .alert("Could not save", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") { error = nil } } message: { Text(error ?? "") }
    }

    private func counter(_ text: String, _ limit: Int) -> some View {
        Text("\(text.count.formatted()) of \(limit.formatted()) characters").font(.wbCaption)
            .foregroundStyle(text.count > limit ? Theme.warning : Theme.secondary)
    }

    private func save() {
        if item == nil && !pro.allows(.item, count: store.activeItemCount) { upgrade = true; return }
        do {
            let place = store.places.first { $0.id == placeID }
            if let item { try store.editItem(item, name: name, place: place, notes: notes, aliases: aliases, photo: photo) }
            else { try store.addItem(name: name, place: place, notes: notes, aliases: aliases, photo: photo) }
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}

struct ItemDetailView: View {
    @Environment(LocaliserStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let item: Belonging
    var putAway = false
    @State private var editing = false
    @State private var addingDate = false
    @State private var moving = false
    @State private var confirmedPutAway = false
    @State private var upgrade = false
    @State private var error: String?
    @State private var deleting = false
    @Environment(ProAccess.self) private var pro
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
                            if item.archived { Stamp(text: "Archived") }
                            else if !item.packedTrips.isEmpty { Stamp(text: "Packed", tone: .due) }
                            else { Stamp(text: "At home", tone: .done) }
                        }
                        Text(item.name).font(.wbDisplay).foregroundStyle(Theme.ink).fixedSize(horizontal: false, vertical: true)
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "mappin.and.ellipse").foregroundStyle(Theme.purple).accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 4) {
                                    PlaceBreadcrumb(path: item.place?.path)
                                    if let moved = item.movements.map(\.date).max() {
                                        Text(Date.now.timeIntervalSince(moved) < 60 ? "Moved just now" : "Moved \(moved.formatted(.relative(presentation: .named)))").font(.wbCaption).foregroundStyle(Theme.secondary)
                                    }
                                }
                            }
                            .accessibilityElement(children: .combine)
                            HStack(spacing: 10) {
                                Button(item.place == nil ? "Set place…" : "Move…") { moving = true }
                                    .buttonStyle(SoftButtonStyle(compact: true))
                                    .accessibilityIdentifier("item.move")
                                    .popoverTip(MoveTip())
                                if putAway {
                                    Button("Confirm put away here") {
                                        do { try store.move(item, to: item.place); confirmedPutAway = true } catch { self.error = error.localizedDescription }
                                    }.buttonStyle(SoftButtonStyle(compact: true))
                                }
                            }
                            if confirmedPutAway { Label("Put away. Nice.", systemImage: "checkmark.circle").font(.wbCaption).foregroundStyle(Theme.sageInk) }
                        }
                        .card()
                        if !item.notes.isEmpty { Text(item.notes) }
                        if !item.aliases.isEmpty { Text("Also called: \(item.aliases.replacingOccurrences(of: "\n", with: ", "))").font(.wbCaption).foregroundStyle(Theme.secondary) }
                    }.plainRow()
                }
                if !item.packedTrips.isEmpty {
                    Section("Packed trips") { ForEach(item.packedTrips) { trip in NavigationLink(trip.name) { TripDetailView(trip: trip) } } }
                }
                Section("Dates") {
                    ForEach(item.deadlines.sorted { $0.dayString < $1.dayString }) { deadline in
                        NavigationLink { DeadlineDetailView(deadline: deadline) } label: { DeadlineRow(deadline: deadline, showsItem: false) }
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
                Section {
                    Button(item.archived ? "Restore item" : "Archive item", systemImage: item.archived ? "tray.and.arrow.up" : "archivebox") { toggleArchive() }
                        .buttonStyle(SoftButtonStyle())
                } footer: {
                    Text(item.archived ? "Restored items show up in search again." : "Archive things you've given away or no longer own. They leave search and don't count toward the free plan, but their history is kept.")
                        .foregroundStyle(Theme.secondary)
                }
                .listRowBackground(Color.clear).listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            } else { ContentUnavailableView("Item deleted", systemImage: "trash") }
        }
        .groundBackground()
        .navigationTitle(available ? item.name : "Item deleted").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if available {
                ToolbarItem(placement: .topBarTrailing) { Button("Edit") { editing = true } }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Move…", systemImage: "arrow.right.circle") { moving = true }
                        Button("Add date", systemImage: "calendar.badge.plus") { addingDate = true }
                        Button(item.archived ? "Restore item" : "Archive item", systemImage: "archivebox") { toggleArchive() }
                        Divider()
                        Button("Delete item permanently", systemImage: "trash", role: .destructive) { deleting = true }
                    } label: { Image(systemName: "ellipsis") }
                    .accessibilityLabel("Item options")
                }
            }
        }
        .sheet(isPresented: $moving) {
            NavigationStack {
                PlaceChooser(selection: Binding(get: { item.place?.id }, set: { id in
                    do { try store.move(item, to: store.places.first { $0.id == id }) } catch { self.error = error.localizedDescription }
                }))
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { moving = false } } }
            }
        }
        .sheet(isPresented: $upgrade) { NavigationStack { ProView() } }
        .sheet(isPresented: $editing) { NavigationStack { ItemEditor(item: item) } }
        .sheet(isPresented: $addingDate) { NavigationStack { DeadlineEditor(item: item) } }
        .onChange(of: store.revision) { _, _ in if !available { dismiss() } }
        .confirmationDialog("Delete \u{201C}\(available ? item.name : "")\u{201D}?", isPresented: $deleting, titleVisibility: .visible) {
            Button("Delete item permanently", role: .destructive) {
                do { try store.deleteItem(item); dismiss() } catch { self.error = error.localizedDescription }
            }
            if !item.archived { Button("Archive instead") { toggleArchive() } }
        } message: {
            Text("Its dates, scans and location history go too. You can undo for a few seconds. Packing lists keep a row with its name.")
        }
        .alert("Couldn't update", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") { error = nil } } message: { Text(error ?? "") }
    }

    private func toggleArchive() {
        if item.archived && !pro.allows(.item, count: store.activeItemCount) { upgrade = true; return }
        do { try store.setArchived(item, !item.archived) } catch { self.error = error.localizedDescription }
    }
}
