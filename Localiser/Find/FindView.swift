import SwiftUI
import PhotosUI
import TipKit
import AppIntents

struct FindView: View {
    @Environment(LocaliserStore.self) private var store
    @State private var query = ""
    @State private var newThing: NewThing?
    @FocusState private var searchFocused: Bool
    @State private var showArchived = false
    @State private var putAway = false
    @State private var addingPlace = false
    @State private var openedItem: Belonging?
    @Environment(ReminderService.self) private var reminders
    @State private var ritual: Ritual?
    @State private var speaking = false
    @State private var spoken: NewThing?
    @AppStorage(SiriTip.whereIs.key) private var whereIsTipDismissed = false
    @AppStorage(SiriTip.writeDown.key) private var writeDownTipDismissed = false

    private var results: [Belonging] {
        _ = store.revision
        return ItemSearch.results(query: query, entries: store.searchIndex, archived: showArchived)
    }

    private var browsing: Bool { query.isEmpty && !putAway && !showArchived }


    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                if browsing || store.items.isEmpty { titleCard }
                if (browsing || store.items.isEmpty) && !SiriTip.hiddenForTesting { siriTips }
                if store.items.isEmpty {
                    LibraryEmptyState(title: String(localized: "Nothing here yet"), systemImage: "magnifyingglass", description: String(localized: "Write down a thing and where you keep it."))
                } else if browsing {
                    dashboard
                } else {
                    if putAway {
                        Label("Choose a thing. Say where you put it.", systemImage: "tray.and.arrow.down")
                            .font(.wbBody).foregroundStyle(.white)
                            .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.purpleFill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                    if results.isEmpty {
                        ContentUnavailableView.search(text: query)
                        if !putAway {
                            Button("Write down where it is") { newThing = NewThing(name: query.trimmingCharacters(in: .whitespacesAndNewlines)) }
                                .buttonStyle(SoftButtonStyle()).accessibilityIdentifier("find.writeDown")
                        }
                    }
                    else { Text(results.count == 1 ? "1 match" : "\(results.count) matches").font(.wbLabel).textCase(.uppercase).foregroundStyle(Theme.secondary) }
                    ForEach(results) { item in itemCard(item) }
                }
            }
            .padding(.horizontal, 20).padding(.vertical, 12)
        }
        .background(Theme.ground)
        .safeAreaBar(edge: .bottom) { if (browsing || store.items.isEmpty) && !searchFocused { addBar } }
        .navigationTitle("Hereabouts")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(removing: .title)
        .navigationDestination(item: $openedItem) { item in ItemDetailView(item: item) }
        .onChange(of: store.openedItem, initial: true) { _, id in
            guard let id else { return }
            openedItem = store.items.first { $0.id == id }
            store.openedItem = nil
        }
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Where is…")
        .searchFocused($searchFocused)
        .onChange(of: store.findRequest, initial: true) { _, request in
            switch request {
            case .find?: searchFocused = true
            case .new?: newThing = NewThing()
            case .putAway?: newThing = NewThing(photoFirst: true)
            case .say?: speaking = VoiceCapture.isAvailable()
            default: return
            }
            store.findRequest = nil
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    Toggle("Show archived things", systemImage: "archivebox", isOn: $showArchived)
                    Toggle("Put-away mode", systemImage: "tray.and.arrow.down", isOn: $putAway)
                } label: { Image(systemName: "line.3.horizontal.decrease") }
                .accessibilityLabel("Find options")
                .popoverTip(PutAwayTip())
            }
            if VoiceCapture.isAvailable() {
                ToolbarItem(placement: .topBarTrailing) { Button("Say where", systemImage: "mic") { speaking = true }.accessibilityIdentifier("find.say") }
            }
        }
        .onChange(of: store.items.count, initial: true) { _, count in PutAwayTip.itemCount = count }
        .sheet(item: $newThing) { new in NavigationStack { ItemEditor(place: store.places.first { $0.id == new.placeID }, name: new.name, photoFirst: new.photoFirst, spokenPlace: new.spokenPlace) } }
        .sheet(isPresented: $speaking, onDismiss: { if let spoken { newThing = spoken; self.spoken = nil } }) { NavigationStack { VoiceSheet { spoken = $0 } } }
        .sheet(isPresented: $addingPlace) { NavigationStack { PlaceEditor() } }
        .sheet(item: $ritual) { ritual in
            NavigationStack {
                switch ritual {
                case .recap: RecapView(startStocktake: { Task { @MainActor in self.ritual = .stocktake } })
                case .stocktake: StocktakeView()
                }
            }
        }
        .onChange(of: reminders.openedRitual, initial: true) { _, value in
            guard let value, let opened = Ritual(rawValue: value) else { return }
            ritual = opened
            reminders.openedRitual = nil
        }
    }

    /// The top of Find: the home's name large and centred on the paper, the date under it, and a short ink rule.
    /// "Hereabouts" stays the screen's title for VoiceOver and the back button, but isn't shown.
    private var titleCard: some View {
        VStack(spacing: 6) {
            Text(store.currentHome?.name ?? Home.defaultName).font(.wbDisplay).foregroundStyle(Theme.ink)
            Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide))).font(.wbBody).foregroundStyle(Theme.pencil)
            Rectangle().fill(Theme.ink).frame(width: 56, height: 1.5).padding(.top, 10).accessibilityHidden(true)
        }
        .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
        .padding(.vertical, 18).padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine).accessibilityAddTraits(.isHeader)
    }

    /// Wide and low on the screen, where a thumb reaches it. Touch and hold to start with a photo.
    private var addBar: some View {
        Button { newThing = NewThing() } label: { Label("Add a thing", systemImage: "plus").fixedSize(horizontal: false, vertical: true) }
            .buttonStyle(PrimaryButtonStyle())
            .contextMenu {
                Button("Start with a name", systemImage: "character.cursor.ibeam") { newThing = NewThing() }
                Button("Start with a photo", systemImage: "camera") { newThing = NewThing(photoFirst: true) }
            }
            .accessibilityHint("Touch and hold to start with a photo")
            .accessibilityAction(named: "Start with a photo") { newThing = NewThing(photoFirst: true) }
            .padding(.horizontal, 20).padding(.vertical, 8)
    }

    @ViewBuilder private var siriTips: some View {
        if !whereIsTipDismissed { SiriTipRow(phrase: "Say **“Ask Hereabouts where something is”**") { whereIsTipDismissed = true } }
        if !writeDownTipDismissed { SiriTipRow(phrase: "Say **“Write something down in Hereabouts”**") { writeDownTipDismissed = true } }
    }

    @ViewBuilder private var dashboard: some View {
        HomeSwitcher()
        RitualBanners { ritual = $0 }
        if !store.missingItems.isEmpty {
            SectionHeading(title: String(localized: "Looking for")).padding(.top, 4)
            ForEach(store.missingItems) { item in itemCard(item) }
        }
        HStack {
            SectionHeading(title: String(localized: "Places"))
            Spacer()
            if store.placesHere.contains(where: { $0.parent == nil }) { NavigationLink("All places") { PlacesView() }.font(.wbLabel).foregroundStyle(Theme.purpleInk) }
        }.padding(.top, 8)
        VStack(spacing: 0) {
            ForEach(store.placesHere.filter { $0.parent == nil }.prefix(3)) { place in
                NavigationLink { PlaceDetailView(place: place) } label: { PlaceTile(place: place) }.buttonStyle(.plain)
            }
            NewPlaceTile { addingPlace = true }
        }
        SectionHeading(title: String(localized: "Recently put away")).padding(.top, 8)
        let lately = results.filter { !store.hasSeveralHomes || $0.home == store.currentHome }.map { ($0, $0.movements.map(\.date).max() ?? $0.createdAt) }.sorted { $0.1 > $1.1 }.prefix(3).map(\.0)
        ForEach(lately) { item in itemCard(item) }
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

/// A Siri phrase to try, with the current Siri glyph. The system's own tip view still draws the old orb.
struct SiriTipRow: View {
    let phrase: LocalizedStringKey
    let dismiss: () -> Void
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "siri").font(.title2).foregroundStyle(Theme.ink).accessibilityHidden(true)
            Text(phrase).font(.wbBody).foregroundStyle(Theme.ink).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button { withAnimation { dismiss() } } label: { Image(systemName: "xmark").font(.body.weight(.semibold)).foregroundStyle(Theme.pencil) }
                .frame(minWidth: 44, minHeight: 44).accessibilityLabel("Hide this tip")
        }
        .padding(.leading, 14).padding(.trailing, 4).padding(.vertical, 4)
        .background(Theme.noteBox, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

/// What the add sheet starts with: a name typed into a search that found nothing, or the camera first.
struct NewThing: Identifiable {
    let id = UUID()
    var name = ""
    var photoFirst = false
    var placeID: UUID?
    var spokenPlace: SpokenPlace?
}

struct PlaceTile: View {
    let place: Place
    var body: some View {
        let count = place.activeItemCount
        NotebookLine(name: place.name, detail: String(localized: "\(count) things"))
            .padding(.vertical, 14).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .overlay(alignment: .bottom) { Rectangle().fill(Theme.rule).frame(height: 1) }
            .contentShape(Rectangle())
    }

    static func symbol(for name: String) -> String {
        // Folded so "Entrée" and "entree" both match. More specific words come first: "carton",
        // "carnet" and "carro" must not fall to "car", nor "salle de bain" to "sala".
        let name = name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
        let table: [(String, String)] = [
            ("garage", "car"), ("kitchen", "fork.knife"), ("cuisine", "fork.knife"), ("cocina", "fork.knife"), ("cozinha", "fork.knife"),
            ("bed", "bed.double"), ("chambre", "bed.double"), ("dormitorio", "bed.double"), ("habitacion", "bed.double"), ("quarto", "bed.double"),
            ("bath", "shower"), ("salle de bain", "shower"), ("banheiro", "shower"), ("bano", "shower"),
            ("office", "desktopcomputer"), ("desk", "desktopcomputer"), ("bureau", "desktopcomputer"), ("oficina", "desktopcomputer"), ("escritorio", "desktopcomputer"),
            ("closet", "hanger"), ("cupboard", "hanger"), ("wardrobe", "hanger"), ("placard", "hanger"), ("armoire", "hanger"), ("armario", "hanger"),
            ("hall", "door.left.hand.closed"), ("entree", "door.left.hand.closed"), ("couloir", "door.left.hand.closed"), ("pasillo", "door.left.hand.closed"), ("corredor", "door.left.hand.closed"),
            ("living", "sofa"), ("salon", "sofa"), ("sala", "sofa"),
            ("storage", "archivebox"), ("locker", "lock"),
            ("carton", "shippingbox"), ("carnet", "square.grid.2x2"), ("carro", "car"), ("car", "car"), ("voiture", "car"), ("coche", "car"),
            ("basement", "stairs"), ("sous-sol", "stairs"), ("sotano", "stairs"), ("porao", "stairs"), ("cave", "stairs"),
            ("attic", "house"), ("grenier", "house"), ("desvan", "house"), ("atico", "house"), ("sotao", "house"),
            ("drawer", "rectangle.split.1x2"), ("tiroir", "rectangle.split.1x2"), ("cajon", "rectangle.split.1x2"), ("gaveta", "rectangle.split.1x2"),
            ("shelf", "books.vertical"), ("etagere", "books.vertical"), ("estante", "books.vertical"), ("prateleira", "books.vertical"),
            ("box", "shippingbox"), ("bin", "shippingbox"), ("boite", "shippingbox"), ("caja", "shippingbox"), ("caixa", "shippingbox")]
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

struct ItemRow: View {
    @Environment(LocaliserStore.self) private var store
    let item: Belonging
    var query = ""
    var body: some View {
        let _ = store.revision
        HStack(spacing: 14) {
            IconTile(systemImage: "shippingbox", photo: item.photo, size: 48)
            VStack(alignment: .leading, spacing: 3) {
                NotebookLine(name: item.name, detail: item.lentLine ?? item.place.map { String(localized: "is in \($0.path)") } ?? String(localized: "No place yet"), query: query)
                if item.isLent, let home = item.place { Text("Usually in \(home.path)").font(.wbCaption).foregroundStyle(Theme.secondary) }
                if store.hasSeveralHomes, let home = item.home, home != store.currentHome { Text("At \(home.name)").font(.wbCaption).foregroundStyle(Theme.secondary) }
                if let since = item.missingSince { Text("Missing since \(since.dayAndMonth)").font(.wbCaption).foregroundStyle(Theme.warning) }
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
    @State private var isPrivate: Bool
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var choosingPhoto = false
    @State private var takingPhoto = false
    @State private var error: String?
    @State private var suggestion: ItemSearch.CaptureSuggestion?
    @State private var nameIdeas: [String] = []
    @State private var upgrade = false
    @State private var several = false
    @FocusState private var nameFocused: Bool
    /// Photo-first capture: the camera opens before the name. The place starts at the last one used.
    private let photoFirst: Bool
    /// A place said aloud that the notebook doesn't have yet.
    private let spokenPlace: SpokenPlace?
    static let lastPlaceKey = "lastPlaceID"
    static let lastPlaceTimeKey = "lastPlaceSavedAt"
    /// Only a run of additions reuses the place, so yesterday's room isn't quietly carried over.
    static let lastPlaceWindow: TimeInterval = 10 * 60

    init(item: Belonging? = nil, place: Place? = nil, name: String = "", photoFirst: Bool = false, spokenPlace: SpokenPlace? = nil) {
        self.item = item
        self.photoFirst = photoFirst
        self.spokenPlace = spokenPlace
        _name = State(initialValue: item?.name ?? name); _notes = State(initialValue: item?.notes ?? "")
        _aliases = State(initialValue: item?.aliases ?? ""); _placeID = State(initialValue: item?.place?.id ?? place?.id)
        _photo = State(initialValue: item?.photo)
        _isPrivate = State(initialValue: item?.isPrivate ?? false)
    }

    var body: some View {
        SheetForm {
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
                if item == nil, photo != nil, ShelfReading.reader != nil {
                    Button("Several things in this photo?", systemImage: "square.grid.2x2") { nameFocused = false; several = true }
                        .font(.subheadline).accessibilityIdentifier("item.several").padding(.horizontal, 20).padding(.vertical, 10)
                }
            }.listRowBackground(Color.clear).listRowInsets(EdgeInsets())
            Section {
                TextField("Name", text: $name).focused($nameFocused).submitLabel(.done).onSubmit { nameFocused = false }.accessibilityIdentifier("item.name")
                if name.count > TextLimit.name - 20 { counter(name, TextLimit.name) }
                if item == nil, name.isEmpty, !nameIdeas.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("From the photo").font(.wbCaption).foregroundStyle(Theme.secondary)
                        FlowLayout(spacing: 8) {
                            ForEach(nameIdeas, id: \.self) { idea in
                                Button(idea) { name = idea; nameFocused = false }.buttonStyle(SoftButtonStyle(compact: true))
                            }
                        }
                    }
                }
                if item == nil && name.split(separator: " ").count >= 3 && suggestion == nil {
                    Button("Split into name and place", systemImage: "wand.and.stars") {
                        suggestion = ItemSearch.suggestion(name, places: store.places.map { ($0.id, $0.path) })
                        if suggestion == nil { error = String(localized: "Try a sentence such as \u{201C}passport in the bedroom drawer\u{201D}. You'll see the suggestion before anything changes.") }
                    }.font(.subheadline)
                }
                if item == nil {
                    if let suggestion {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Suggested name: \(suggestion.name)")
                            Text(suggestion.placeID.flatMap { id in store.places.first { $0.id == id }?.path } ?? String(localized: "Confirm a place: \(suggestion.unrecognizedPlace ?? String(localized: "Unknown"))"))
                            Button("Use suggestion") { name = suggestion.name; placeID = suggestion.placeID; self.suggestion = nil }
                        }
                    }
                }
            } header: { Text("What is it?").font(.wbLabel).foregroundStyle(Theme.ink).textCase(nil) }
            Section {
                PlacePicker(selection: $placeID, recent: item == nil ? store.recentPlaces() : [], home: item?.home)
                if let spokenPlace, placeID == nil { NewPlaceSuggestion(spoken: spokenPlace) { placeID = $0 } }
            } header: { Text("Where do you keep it?").font(.wbLabel).foregroundStyle(Theme.ink).textCase(nil) }
            Section {
                TextField("Notes", text: $notes, axis: .vertical).lineLimit(2...8)
                if notes.count > TextLimit.notes - 500 { counter(notes, TextLimit.notes) }
                TextField("Other names, one per line", text: $aliases, axis: .vertical).lineLimit(1...6)
                if aliases.count > TextLimit.aliases - 200 { counter(aliases, TextLimit.aliases) }
            } header: { Text("Optional details").font(.wbLabel).foregroundStyle(Theme.ink).textCase(nil) }
              footer: { Text("Add names you might search for, like \u{201C}ID\u{201D} for a passport.").foregroundStyle(Theme.secondary) }
            Section {
                Toggle("Keep private", isOn: $isPrivate).accessibilityIdentifier("item.private")
            } footer: { Text("Hidden from Spotlight, Siri, notifications and widgets. Included in backups and exports.").foregroundStyle(Theme.secondary) }
        }
        .groundBackground()
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                if let left = freeLeft { Text(left).font(.wbCaption).foregroundStyle(Theme.pencil).frame(maxWidth: .infinity, alignment: .leading) }
                Button(item == nil ? "Write it down" : "Save changes") { save() }
                    .buttonStyle(PrimaryButtonStyle())
                    .accessibilityIdentifier("item.save")
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 20).padding(.vertical, 12)
            .background(Theme.ground)
        }
        .navigationTitle(item == nil ? "New thing" : "Edit thing").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { nameFocused = false; UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) } }
        }
        .onAppear {
            let savedAt = UserDefaults.standard.object(forKey: Self.lastPlaceTimeKey) as? Date ?? .distantPast
            if item == nil, placeID == nil, spokenPlace == nil, Date.now.timeIntervalSince(savedAt) < Self.lastPlaceWindow,
               let raw = UserDefaults.standard.string(forKey: Self.lastPlaceKey), let id = UUID(uuidString: raw), store.placesHere.contains(where: { $0.id == id }) {
                placeID = id
            }
            if item == nil, photoFirst, photo == nil {
                if CameraPicker.isAvailable { takingPhoto = true } else { choosingPhoto = true }
            } else { nameFocused = item == nil }
        }
        .onChange(of: photo) { old, new in
            if photoFirst, old == nil, new != nil, name.isEmpty { nameFocused = true }
            guard item == nil, let new else { nameIdeas = []; return }
            Task { nameIdeas = await NameSuggestions.read(new) }
        }
        .sheet(isPresented: $upgrade) { NavigationStack { ProView() } }
        .sheet(isPresented: $several) {
            if let photo, let reader = ShelfReading.reader {
                NavigationStack { ShelfNamesView(photo: photo, reader: reader, placeID: $placeID, isPrivate: isPrivate) { dismiss() } }
            }
        }
        .photosPicker(isPresented: $choosingPhoto, selection: $selectedPhoto, matching: .images)
        .fullScreenCover(isPresented: $takingPhoto) { CameraPicker { photo = PhotoResize.jpeg($0) }.ignoresSafeArea() }
        .onChange(of: selectedPhoto) { _, newValue in
            guard let newValue else { return }
            Task {
                do {
                    guard let data = try await newValue.loadTransferable(type: Data.self), let image = UIImage(data: data) else { throw CocoaError(.fileReadCorruptFile) }
                    photo = PhotoResize.jpeg(image)
                } catch { self.error = String(localized: "Couldn't open that photo. Try another one.") }
                selectedPhoto = nil
            }
        }
        .alert("Couldn't save", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") { error = nil } } message: { Text(error ?? "") }
    }

    static let freePlanFull = String(localized: "Your free plan is full. Archive a thing or get Pro to add more.")

    /// A quiet note when three or fewer things are left on the free plan.
    private var freeLeft: String? {
        guard item == nil, !pro.unlocked else { return nil }
        let left = CreationKind.item.freeLimit - store.activeItemCount
        switch left {
        case ...0: return Self.freePlanFull
        case 1: return String(localized: "You can add 1 more thing for free.")
        case 2...3: return String(localized: "You can add \(left) more things for free.")
        default: return nil
        }
    }

    private func counter(_ text: String, _ limit: Int) -> some View {
        Text("\(text.count.formatted()) of \(limit.formatted()) characters").font(.wbCaption)
            .foregroundStyle(text.count > limit ? Theme.warning : Theme.secondary)
    }

    private func save() {
        if item == nil && !pro.allows(.item, count: store.activeItemCount) { upgrade = true; return }
        do {
            let place = store.places.first { $0.id == placeID }
            if let item { try store.editItem(item, name: name, place: place, notes: notes, aliases: aliases, photo: photo, isPrivate: isPrivate) }
            else {
                try store.addItem(name: name, place: place, notes: notes, aliases: aliases, photo: photo, isPrivate: isPrivate)
                UserDefaults.standard.set(place?.id.uuidString, forKey: Self.lastPlaceKey)
                UserDefaults.standard.set(Date.now, forKey: Self.lastPlaceTimeKey)
            }
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
    @State private var moving = false
    @State private var finding = false
    @State private var lending = false
    @State private var foundNote: String?
    @State private var confirmedPutAway = false
    @State private var upgrade = false
    @State private var error: String?
    @State private var deleting = false
    @State private var movingHome = false
    @Environment(ProAccess.self) private var pro
    private var available: Bool { item.managedObjectContext != nil && !item.isDeleted }

    var body: some View {
        let _ = store.revision
        SheetList {
            if available {
                Section {
                    VStack(alignment: .leading, spacing: 14) {
                        if let data = item.photo, let image = UIImage(data: data) {
                            Image(uiImage: image).resizable().scaledToFill().frame(maxWidth: .infinity).frame(height: 220)
                                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous)).accessibilityHidden(true)
                        }
                        FlowLayout(spacing: 8) {
                            if item.archived { Stamp(text: String(localized: "Archived")) }
                            else if item.isMissing { Stamp(text: String(localized: "Missing"), tone: .due) }
                            else if item.isLent { Stamp(text: String(localized: "With \(item.lentTo)"), tone: .purple) }
                            else if !item.packedTrips.isEmpty { Stamp(text: String(localized: "Packed"), tone: .due) }
                            else { Stamp(text: String(localized: "At home"), tone: .done) }
                            // The canvas leads with the next date when one is close.
                            if let askBack = item.openAskBack, let days = DueLabel.days(until: askBack.day), days <= 30, let pill = DueLabel.pill(for: askBack.day) {
                                Stamp(text: String(localized: "Ask for it back · \(pill.0)"), tone: pill.1)
                            }
                        }
                        Text(item.name).font(.wbDisplay).foregroundStyle(Theme.ink).fixedSize(horizontal: false, vertical: true)
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "mappin.and.ellipse").foregroundStyle(Theme.purple).accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 4) {
                                    PlaceBreadcrumb(path: item.place?.path)
                                    if store.hasSeveralHomes, let home = item.home {
                                        Text(home.name).font(.wbCaption).foregroundStyle(Theme.secondary).accessibilityIdentifier("item.home")
                                    }
                                    if let moved = item.movements.map(\.date).max() {
                                        Text(Date.now.timeIntervalSince(moved) < 60 ? "Moved just now" : "Moved \(moved.formatted(.relative(presentation: .named)))").font(.wbCaption).foregroundStyle(Theme.secondary)
                                    }
                                }
                            }
                            .accessibilityElement(children: .combine)
                            HStack(spacing: 10) {
                                Button(item.place == nil ? "Choose a place…" : "Move…") { moving = true }
                                    .buttonStyle(SoftButtonStyle(compact: true))
                                    .accessibilityIdentifier("item.move")
                                    .popoverTip(MoveTip())
                                if putAway {
                                    Button("Put away here") {
                                        do { try store.move(item, to: item.place); confirmedPutAway = true } catch { self.error = error.localizedDescription }
                                    }.buttonStyle(SoftButtonStyle(compact: true))
                                }
                            }
                            if item.isLent, !item.archived {
                                if let line = item.lentLine { Text(line).font(.wbCaption).foregroundStyle(Theme.ink) }
                                if let askBack = item.openAskBack, let day = askBack.day {
                                    Text("Ask for it back · \(day.formatted)").font(.wbCaption).foregroundStyle(Theme.ink).accessibilityIdentifier("item.askBack")
                                }
                                Button("It's back") {
                                    do { try store.gotBack(item) } catch { self.error = error.localizedDescription }
                                }.buttonStyle(PrimaryButtonStyle()).accessibilityIdentifier("item.back")
                                if let askBack = item.openAskBack {
                                    Button("Ask again next week") {
                                        do { try store.askAgainNextWeek(askBack) } catch { self.error = error.localizedDescription }
                                    }.buttonStyle(SoftButtonStyle(compact: true)).accessibilityIdentifier("item.askAgain")
                                }
                            } else if item.isMissing, !item.archived {
                                Text("Missing since \(item.missingSince?.dayAndMonth ?? String(localized: "recently")).").font(.wbCaption).foregroundStyle(Theme.ink)
                                Button("Found it") { finding = true }.buttonStyle(PrimaryButtonStyle()).accessibilityIdentifier("item.found")
                            } else if item.place != nil, !item.archived, !putAway { StillThereRow(item: item) { moving = true } }
                            if let foundNote { Label(foundNote, systemImage: "checkmark.circle").font(.wbCaption).foregroundStyle(Theme.sageInk) }
                            if confirmedPutAway { Label("Put away.", systemImage: "checkmark.circle").font(.wbCaption).foregroundStyle(Theme.sageInk) }
                        }
                        .card()
                        if !item.notes.isEmpty { Text(item.notes) }
                        let otherNames = item.aliases.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                        if !otherNames.isEmpty { Text("Also called: \(otherNames.joined(separator: ", "))").font(.wbCaption).foregroundStyle(Theme.secondary) }
                    }.plainRow()
                }
                if !item.packedTrips.isEmpty {
                    Section("Packed trips") { ForEach(item.packedTrips) { trip in NavigationLink(trip.name) { TripDetailView(trip: trip) } } }
                }
                if !item.movements.isEmpty {
                    Section("Where it's been") {
                        ForEach(item.movements.sorted { $0.date > $1.date }) { movement in
                            VStack(alignment: .leading) {
                                Text(movement.summary)
                                let when = movement.date.formatted(movement.date.isThisYear ? .dateTime.month().day().hour().minute() : .dateTime.year().month().day().hour().minute())
                                Text(movement.byline.map { "\($0) · \(when)" } ?? when).font(.caption).foregroundStyle(Theme.secondary)
                            }
                        }
                    }
                }
                Section {
                    Button(item.archived ? "Restore this thing" : "Archive this thing", systemImage: item.archived ? "tray.and.arrow.up" : "archivebox") { toggleArchive() }
                        .buttonStyle(SoftButtonStyle())
                } footer: {
                    Text(item.archived ? "Restored things show up in search again." : "Archive things you no longer own. They're hidden from search and don't count toward your free plan. You keep their history.")
                        .foregroundStyle(Theme.secondary)
                }
                .listRowBackground(Color.clear).listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            } else { ContentUnavailableView("This thing was deleted", systemImage: "trash") }
        }
        .groundBackground()
        .navigationTitle(available ? item.name : String(localized: "Deleted")).navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if available {
                if let sentence = item.whereItIsSentence {
                    ToolbarItem(placement: .topBarTrailing) {
                        ShareLink(item: sentence) { Image(systemName: "square.and.arrow.up") }.accessibilityLabel("Share where it is")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) { Button("Edit") { editing = true } }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Move…", systemImage: "arrow.right.circle") { moving = true }
                        if store.hasSeveralHomes { Button("Move to another home", systemImage: "house") { movingHome = true } }
                        if !item.archived, !item.isLent { Button("Lend it…", systemImage: "person.badge.clock") { lending = true } }
                        if !item.archived {
                            Button(item.isMissing ? "Found it…" : "Found it somewhere else…", systemImage: "sparkle.magnifyingglass") { finding = true }
                            if !item.isMissing {
                                Button("Can't find it", systemImage: "questionmark.circle") {
                                    do { try store.markMissing(item); foundNote = nil } catch { self.error = error.localizedDescription }
                                }
                            }
                        }
                        Button(item.archived ? "Restore this thing" : "Archive this thing", systemImage: "archivebox") { toggleArchive() }
                        Divider()
                        Button("Delete permanently", systemImage: "trash", role: .destructive) { deleting = true }
                    } label: { Image(systemName: "ellipsis") }
                    .accessibilityLabel("More")
                }
            }
        }
        .sheet(isPresented: $moving) {
            NavigationStack {
                PlaceChooser(selection: Binding(get: { item.place?.id }, set: { id in
                    do { try store.move(item, to: store.places.first { $0.id == id }) } catch { self.error = error.localizedDescription }
                }), home: item.home)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { moving = false } } }
            }
        }
        .sheet(isPresented: $movingHome) { NavigationStack { MoveToHomeSheet(subject: .thing(item)) } }
        .sheet(isPresented: $lending) { NavigationStack { LendSheet(item: item) } }
        .sheet(isPresented: $finding) {
            NavigationStack {
                PlaceChooser(selection: Binding(get: { nil }, set: { id in
                    let place = store.places.first { $0.id == id }
                    do { try store.found(item, at: place); foundNote = Movement.foundSentence(place) } catch { self.error = error.localizedDescription }
                }), noneTitle: String(localized: "No place yet"), suggested: store.foundSuggestions(for: item), title: String(localized: "Where was it?"), home: item.home)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { finding = false } } }
            }
        }
        .sheet(isPresented: $upgrade) { NavigationStack { ProView() } }
        .sheet(isPresented: $editing) { NavigationStack { ItemEditor(item: item) } }
        .onChange(of: store.revision) { _, _ in if !available { dismiss() } }
        .confirmationDialog("Delete \u{201C}\(available ? item.name : "")\u{201D}?", isPresented: $deleting, titleVisibility: .visible) {
            Button("Delete permanently", role: .destructive) {
                do { try store.deleteItem(item); dismiss() } catch { self.error = error.localizedDescription }
            }
            if !item.archived { Button("Archive instead") { toggleArchive() } }
        } message: {
            Text("You also delete its dates and history. You can undo for a few seconds. Its name stays in packing lists.")
        }
        .alert("Couldn't update", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") { error = nil } } message: { Text(error ?? "") }
    }

    private func toggleArchive() {
        if item.archived && !pro.allows(.item, count: store.activeItemCount) { upgrade = true; return }
        do { try store.setArchived(item, !item.archived) } catch { self.error = error.localizedDescription }
    }
}
