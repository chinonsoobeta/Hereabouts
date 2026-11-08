import SwiftUI

struct PlacesView: View {
    @Environment(LocaliserStore.self) private var store
    @State private var adding = false
    @State private var error: String?
    @State private var printing = false
    @State private var scanning = false
    @State private var labelled: Place?
    @State private var unknownLabel = false
    @State private var tidying = false
    private let starters = [String(localized: "Kitchen"), String(localized: "Bedroom"), String(localized: "Garage"), String(localized: "Hall closet"), String(localized: "Office"), String(localized: "Attic")]
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HomeSwitcher()
                let spares = store.sparePlaces
                if !spares.isEmpty {
                    StickyNote {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(spares.count == 1 ? "\u{201C}\(spares[0].path)\u{201D} is an empty copy of another place." : "\(spares.count) empty places are copies of others, like \u{201C}\(spares[0].path)\u{201D}.")
                                .font(.wbBody).foregroundStyle(Theme.ink)
                            Button("Remove empty copies") { tidying = true }.buttonStyle(SoftButtonStyle()).accessibilityIdentifier("places.tidy")
                        }
                    }
                    .confirmationDialog("Remove empty copies of places?", isPresented: $tidying, titleVisibility: .visible) {
                        Button(spares.count == 1 ? "Remove 1 copy" : "Remove \(spares.count) copies") {
                            do { try store.mergeSparePlaces() } catch { self.error = error.localizedDescription }
                        }
                    } message: { Text("Only empty copies are removed. Places inside them move into the place you're keeping.") }
                }
                if store.placesHere.isEmpty {
                    LibraryEmptyState(title: String(localized: "Where do you keep things?"), systemImage: "house", description: String(localized: "Add a room, then the drawers, shelves and boxes inside it."))
                    quickStart(starters)
                    Button("Add a place") { adding = true }.buttonStyle(PrimaryButtonStyle())
                } else {
                    VStack(spacing: 0) {
                        ForEach(rooms) { place in
                            NavigationLink { PlaceDetailView(place: place) } label: { PlaceTile(place: place) }.buttonStyle(.plain)
                        }
                        NewPlaceTile { adding = true }
                    }
                    // Quick start stays for the first few rooms, so more than one can be picked.
                    if rooms.count < 3, !unusedStarters.isEmpty { quickStart(unusedStarters) }
                }
                if !store.lentItems.isEmpty {
                    SectionHeading(title: String(localized: "Lent out")).padding(.top, 8)
                    ForEach(store.lentItems) { item in
                        NavigationLink { ItemDetailView(item: item) } label: { ItemRow(item: item).card() }.buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 20).padding(.vertical, 12)
        }
        .background(Theme.ground).navigationTitle("Places")
        .toolbar {
            if !store.placesHere.isEmpty {
                Menu {
                    Button("Print labels", systemImage: "printer") { printing = true }
                    if LabelScanner.isAvailable { Button("Scan a label", systemImage: "qrcode.viewfinder") { scanning = true } }
                } label: { Image(systemName: "qrcode") }.accessibilityLabel("Box labels")
            }
            Button("Add a place", systemImage: "plus") { adding = true }
        }
        .sheet(isPresented: $adding) { NavigationStack { PlaceEditor() } }
        .sheet(isPresented: $printing) { NavigationStack { LabelSheetView(places: []) } }
        .fullScreenCover(isPresented: $scanning) {
            NavigationStack {
                LabelScanner { id in scanning = false; store.openedPlace = id }.ignoresSafeArea()
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { scanning = false } } }
            }
        }
        .navigationDestination(item: $labelled) { place in PlaceDetailView(place: place, fromLabel: true) }
        .onChange(of: store.openedPlace, initial: true) { _, id in
            guard let id else { return }
            store.openedPlace = nil
            if let place = store.places.first(where: { $0.id == id }) { labelled = place } else { unknownLabel = true }
        }
        .alert("This label's box isn't in your notebook", isPresented: $unknownLabel) { Button("OK") {} } message: { Text("It may have been deleted, or the label was made on another phone.") }
        .alert("Couldn't add that place", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") { error = nil } } message: { Text(error ?? "") }
    }

    private var rooms: [Place] { store.placesHere.filter { $0.parent == nil } }
    private var unusedStarters: [String] { starters.filter { name in !rooms.contains { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame } } }

    @ViewBuilder private func quickStart(_ names: [String]) -> some View {
        Text("Quick start").font(.wbLabel).foregroundStyle(Theme.secondary).textCase(.uppercase)
        FlowLayout(spacing: 8) {
            ForEach(names, id: \.self) { name in
                Button { addStarter(name) } label: { Label(name, systemImage: "plus").font(.wbItem) }
                    .buttonStyle(SoftButtonStyle(compact: true))
            }
        }
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
            Label("New place", systemImage: "plus")
                .font(.wbBody.weight(.bold)).foregroundStyle(Theme.purpleInk)
                .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
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
    private var duplicate: Place? { store.duplicatePlace(named: name, parent: parent, excluding: place, home: place?.home) }
    var body: some View {
        SheetForm {
            Section {
                TextField("Name, like Kitchen or Top drawer", text: $name).accessibilityIdentifier("place.name")
                if let duplicate {
                    Label("\u{201C}\(duplicate.path)\u{201D} already exists. You can still save another one.", systemImage: "exclamationmark.triangle")
                        .font(.wbCaption).foregroundStyle(Theme.warning)
                }
            }
            Section {
                PlacePicker(selection: $parentID, excluded: place, title: String(localized: "Inside"), noneTitle: String(localized: "None"), home: place?.home)
            } footer: { Text("Choose None if this place isn't inside another place.").foregroundStyle(Theme.secondary) }
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
        .alert("That didn't save", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") { error = nil } } message: { Text(error ?? "") }
    }
}

struct PlaceDetailView: View {
    @Environment(LocaliserStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let place: Place
    /// Opened by scanning its label: lead with putting things in.
    var fromLabel = false
    @State private var editing = false
    @State private var printing = false
    @State private var adding = false
    @State private var addingItem = false
    @State private var deleting = false
    @State private var movingHome = false
    @State private var error: String?
    private var available: Bool { place.managedObjectContext != nil && !place.isDeleted }

    /// Every unarchived item here or in any place inside, nearest first.
    private var nestedItems: [Belonging] {
        store.items.filter { !$0.archived && ($0.place.map { $0.isWithin(place) } ?? false) }
            .sorted { ($0.place == place ? 0 : 1, $0.name) < ($1.place == place ? 0 : 1, $1.name) }
    }

    var body: some View {
        let _ = store.revision
        SheetList {
            if available {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(place.name).font(.wbDisplay).foregroundStyle(Theme.ink)
                        if place.parent != nil { PlaceBreadcrumb(path: place.path) }
                        let count = place.activeItemCount
                        Text(count == 1 ? "1 thing" : "\(count) things").font(.wbCaption).foregroundStyle(Theme.purpleInk)
                    }.plainRow()
                    if fromLabel {
                        Button("Put things in this box", systemImage: "tray.and.arrow.down") { addingItem = true }
                            .buttonStyle(PrimaryButtonStyle()).plainRow()
                    }
                    HStack(spacing: 10) {
                        Button("Add a thing", systemImage: "plus") { addingItem = true }.buttonStyle(SoftButtonStyle(compact: true))
                        Button("Add a place", systemImage: "square.stack") { adding = true }.buttonStyle(SoftButtonStyle(compact: true))
                    }.plainRow()
                }
                if !place.children.isEmpty {
                    Section("Places inside") {
                        ForEach(place.children.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }) { child in
                            NavigationLink { PlaceDetailView(place: child) } label: {
                                NotebookLine(name: child.name, detail: String(localized: "\(child.activeItemCount) things"))
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
                  footer: { if !place.children.isEmpty && !nestedItems.isEmpty { Text("You also see things in the places inside.").foregroundStyle(Theme.secondary) } }
                if store.hasSeveralHomes {
                    Section { Button("Move to another home", systemImage: "house") { movingHome = true }.buttonStyle(SoftButtonStyle()) }
                        .listRowBackground(Color.clear).listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                }
                Section { Button("Delete place", role: .destructive) { deleting = true } }
            } else { ContentUnavailableView("This place was deleted", systemImage: "trash") }
        }
        .groundBackground()
        .navigationTitle(available ? place.name : "").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if available {
                Button("Print a label", systemImage: "printer") { printing = true }
                Button("Edit") { editing = true }
            }
        }
        .sheet(isPresented: $printing) { NavigationStack { LabelSheetView(places: [place]) } }
        .sheet(isPresented: $editing) { NavigationStack { PlaceEditor(place: place) } }
        .sheet(isPresented: $adding) { NavigationStack { PlaceEditor(parent: place) } }
        .sheet(isPresented: $addingItem) { NavigationStack { ItemEditor(place: place) } }
        .sheet(isPresented: $movingHome) { NavigationStack { MoveToHomeSheet(subject: .place(place)) } }
        .onChange(of: store.revision) { _, _ in if !available { dismiss() } }
        .confirmationDialog("Delete \u{201C}\(available ? place.name : "")\u{201D}?", isPresented: $deleting, titleVisibility: .visible) {
            Button("Delete place", role: .destructive) {
                do { try store.deletePlace(place, clearContents: true); dismiss() } catch { self.error = error.localizedDescription }
            }
        } message: {
            Text(place.parent.map { "Everything inside moves to \u{201C}\($0.name)\u{201D}. Nothing else is deleted." }
                 ?? "Things directly here will have no place set. Places inside it move to the top level. Nothing else is deleted.")
        }
        .alert("Couldn't delete", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") { error = nil } } message: { Text(error ?? "") }
    }
}
