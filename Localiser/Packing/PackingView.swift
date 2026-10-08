import SwiftUI

struct PackingView: View {
    @Environment(LocaliserStore.self) private var store
    @State private var newTrip = false
    @State private var newKit = false
    var body: some View {
        List {
            Section("Trips") {
                if store.trips.isEmpty { Text("Create a trip from a reusable kit or start an empty checklist.").foregroundStyle(.secondary) }
                ForEach(store.trips) { trip in
                    NavigationLink { TripDetailView(trip: trip) } label: {
                        VStack(alignment: .leading) { Text(trip.name).font(.headline); Text("\(trip.startDay) to \(trip.endDay) · \(trip.stateRaw)").font(.caption).foregroundStyle(.secondary) }
                    }
                }
                Button("New trip") { newTrip = true }
            }
            Section("Reusable kits") {
                ForEach(store.kits) { kit in NavigationLink { KitDetailView(kit: kit) } label: { LabeledContent(kit.name, value: "\(kit.entries.count) rows") } }
                Button("New kit") { newKit = true }
                Text("Each trip gets its own packing and departure checklist. Changes to a kit apply to future trips.").font(.caption).foregroundStyle(.secondary)
            }
        }
        .scrollContentBackground(.hidden).background(Theme.ground).navigationTitle("Packing")
        .sheet(isPresented: $newTrip) { NavigationStack { TripEditor() } }
        .sheet(isPresented: $newKit) { NavigationStack { KitEditor() } }
    }
}

struct KitEditor: View {
    @Environment(LocaliserStore.self) private var store
    @Environment(ProAccess.self) private var pro
    @Environment(\.dismiss) private var dismiss
    let kit: Kit?
    @State private var name: String
    @State private var error: String?
    @State private var upgrade = false
    init(kit: Kit? = nil) { self.kit = kit; _name = State(initialValue: kit?.name ?? "") }
    var body: some View {
        Form { TextField("Kit name", text: $name).accessibilityIdentifier("kit.name") }
            .navigationTitle(kit == nil ? "New kit" : "Edit kit").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") {
                    if kit == nil && !pro.allows(.kit, count: store.kits.count) { upgrade = true; return }
                    do { if let kit { try store.editKit(kit, name: name) } else { try store.addKit(name: name) }; dismiss() } catch { self.error = error.localizedDescription }
                }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).accessibilityIdentifier("kit.save") }
            }
            .alert("Could not save kit", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") { error = nil } } message: { Text(error ?? "") }
            .sheet(isPresented: $upgrade) { NavigationStack { ProView() } }
    }
}

struct KitDetailView: View {
    @Environment(LocaliserStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let kit: Kit
    @State private var edit = false
    @State private var addEntry = false
    @State private var editingEntry: KitEntry?
    @State private var trip = false
    @State private var deleting = false
    @State private var taskTitle = ""
    @State private var error: String?
    var body: some View {
        let _ = store.revision
        List {
            Section("Packing rows") {
                ForEach(kit.entries.sorted { $0.title < $1.title }) { entry in
                    Button { editingEntry = entry } label: {
                        VStack(alignment: .leading) {
                            Text(entry.title).font(.headline)
                            Text("\(entry.unitQuantity)\(entry.perNight ? " per night" : " total") · \(entry.condition.title)").font(.caption).foregroundStyle(.secondary)
                            if entry.item?.archived == true { Text("Archived item: excluded from new trips").font(.caption).foregroundStyle(.orange) }
                        }
                    }.swipeActions { Button("Delete", role: .destructive) { attempt { try store.deleteKitEntry(entry) } } }
                }
                Button("Add packing row") { addEntry = true }
            }
            Section("Reusable departure routine") {
                ForEach(kit.tasks.sorted { $0.title < $1.title }) { task in Text(task.title).swipeActions { Button("Delete", role: .destructive) { attempt { try store.deleteKitTask(task) } } } }
                TextField("New departure task", text: $taskTitle)
                Button("Add departure task") { attempt { try store.addKitTask(kit, title: taskTitle); taskTitle = "" } }.disabled(taskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            Section { Button("Create trip from this kit") { trip = true }; Button("Delete kit", role: .destructive) { deleting = true } }
        }
        .navigationTitle(kit.name).navigationBarTitleDisplayMode(.inline).toolbar { Button("Edit") { edit = true } }
        .sheet(isPresented: $edit) { NavigationStack { KitEditor(kit: kit) } }
        .sheet(isPresented: $addEntry) { NavigationStack { KitEntryEditor(kit: kit) } }
        .sheet(item: $editingEntry) { entry in NavigationStack { KitEntryEditor(kit: kit, entry: entry) } }
        .sheet(isPresented: $trip) { NavigationStack { TripEditor(kit: kit) } }
        .confirmationDialog("Delete this kit? Existing trips will keep their own checklists.", isPresented: $deleting, titleVisibility: .visible) { Button("Delete kit", role: .destructive) { attempt { try store.deleteKit(kit); dismiss() } } }
        .alert("Could not update kit", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") { error = nil } } message: { Text(error ?? "") }
    }
    private func attempt(_ action: () throws -> Void) { do { try action() } catch { self.error = error.localizedDescription } }
}

struct KitEntryEditor: View {
    @Environment(LocaliserStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let kit: Kit
    let entry: KitEntry?
    @State private var name: String
    @State private var itemID: UUID?
    @State private var quantity: Int
    @State private var perNight: Bool
    @State private var condition: PackingCondition
    @State private var error: String?
    init(kit: Kit, entry: KitEntry? = nil) {
        self.kit = kit; self.entry = entry
        _name = State(initialValue: entry?.name ?? ""); _itemID = State(initialValue: entry?.item?.id)
        _quantity = State(initialValue: entry.map { Int($0.unitQuantity) } ?? 1)
        _perNight = State(initialValue: entry?.perNight ?? false); _condition = State(initialValue: entry?.condition ?? .always)
    }
    var body: some View {
        Form {
            Picker("Link a belonging", selection: $itemID) { Text("Free-text row").tag(nil as UUID?); ForEach(store.items.filter { !$0.archived }) { Text($0.name).tag(Optional($0.id)) } }
            if itemID == nil { TextField("Row name", text: $name).accessibilityIdentifier("kit.entry.name") }
            Stepper("Quantity: \(quantity)", value: $quantity, in: 1...99)
            Toggle("Multiply by nights", isOn: $perNight)
            Picker("Include for", selection: $condition) { ForEach(PackingCondition.allCases) { Text($0.title).tag($0) } }
            Text("Linked rows use the item's current place. Free-text rows appear under Anywhere.").font(.caption).foregroundStyle(.secondary)
        }
        .navigationTitle(entry == nil ? "Add packing row" : "Edit packing row").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("Save") {
                do { try store.setKitEntry(kit: kit, existing: entry, name: name, item: store.items.first { $0.id == itemID }, unit: quantity, perNight: perNight, condition: condition); dismiss() } catch { self.error = error.localizedDescription }
            }.disabled(itemID == nil && name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).accessibilityIdentifier("kit.entry.save") }
        }
        .alert("Could not save row", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") { error = nil } } message: { Text(error ?? "") }
    }
}

struct TripEditor: View {
    @Environment(LocaliserStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let trip: TripRecord?
    @State private var name: String
    @State private var start: Date
    @State private var end: Date
    @State private var flying: Bool
    @State private var international: Bool
    @State private var work: Bool
    @State private var kitID: UUID?
    @State private var error: String?
    init(trip: TripRecord? = nil, kit: Kit? = nil) {
        self.trip = trip
        _name = State(initialValue: trip?.name ?? "")
        _start = State(initialValue: trip?.details?.start.date() ?? .now)
        _end = State(initialValue: trip?.details?.end.date() ?? Calendar.current.date(byAdding: .day, value: 3, to: .now) ?? .now)
        _flying = State(initialValue: trip?.flying ?? false); _international = State(initialValue: trip?.international ?? false); _work = State(initialValue: trip?.work ?? false)
        _kitID = State(initialValue: kit?.id)
    }
    private var details: TripDetails { TripDetails(name: name, start: CalendarDay(start), end: CalendarDay(end), flying: flying, international: international, work: work) }
    var body: some View {
        Form {
            Section("Trip") {
                TextField("Trip name", text: $name).accessibilityIdentifier("trip.name")
                DatePicker("Depart", selection: $start, displayedComponents: .date)
                DatePicker("Come home", selection: $end, displayedComponents: .date)
                Text("\(details.nights) nights")
                if details.end < details.start { Text("Come-home date must be on or after departure.").foregroundStyle(.red) }
                Toggle("Flying", isOn: $flying); Toggle("International", isOn: $international); Toggle("Work", isOn: $work)
                if trip == nil { Picker("Kit", selection: $kitID) { Text("Start without a kit").tag(nil as UUID?); ForEach(store.kits) { Text($0.name).tag(Optional($0.id)) } } }
            }
            if let trip {
                Section("Quantity changes") {
                    ForEach(trip.entries.filter { $0.required(for: details) != $0.requiredCount }.sorted { $0.title < $1.title }) { entry in Text("\(entry.title): \(entry.requiredCount) → \(entry.required(for: details)); \(entry.packedCount) already packed") }
                    Text("Packed counts and manual quantity overrides will be kept. Review any excess or missing items after saving.").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(trip == nil ? "New trip" : "Edit trip").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("Save") {
                do { if let trip { try store.editTrip(trip, details: details) } else { try store.addTrip(details, kit: store.kits.first { $0.id == kitID }) }; dismiss() } catch { self.error = error.localizedDescription }
            }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || details.end < details.start).accessibilityIdentifier("trip.save") }
        }
        .alert("Could not save trip", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") { error = nil } } message: { Text(error ?? "") }
    }
}

struct TripDetailView: View {
    @Environment(LocaliserStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let trip: TripRecord
    @State private var edit = false
    @State private var adding = false
    @State private var deleting = false
    @State private var canceling = false
    @State private var taskTitle = ""
    @State private var error: String?
    private var groups: [String] { Set(trip.entries.map { $0.item?.place?.path ?? "Anywhere" }).sorted() }
    var body: some View {
        let _ = store.revision
        List {
            Section {
                Text("\(trip.startDay) to \(trip.endDay) · \(trip.details?.nights ?? 0) nights")
                Text("Status: \(trip.stateRaw)")
                if trip.state == .packing { Button("Add item or free-text row") { adding = true } }
            }
            ForEach(groups, id: \.self) { group in
                Section(group) {
                    ForEach(trip.entries.filter { ($0.item?.place?.path ?? "Anywhere") == group }.sorted { $0.title < $1.title }) { entry in
                        NavigationLink { TripEntryDetailView(entry: entry) } label: {
                            VStack(alignment: .leading) {
                                Text(entry.title).font(.headline)
                                Text("\(entry.packedCount) packed / \(entry.requiredCount) needed").font(.subheadline).foregroundStyle(.secondary)
                                if entry.item?.archived == true { Text("Archived / returned item: resolve or remove this row.").font(.caption).foregroundStyle(.orange) }
                                if trip.state == .comingHome { Text("Coming home: \(entry.resolutionRaw)").font(.caption) }
                            }
                        }
                    }
                }
            }
            if trip.state == .packing {
                Section("Before departure") {
                    ForEach(trip.tasks.sorted { $0.title < $1.title }) { task in
                        Toggle(task.title, isOn: Binding(get: { task.checked }, set: { value in attempt { try store.checkTask(task, checked: value) } }))
                            .swipeActions { Button("Delete", role: .destructive) { attempt { try store.deleteTripTask(task) } } }
                    }
                    TextField("New departure task", text: $taskTitle)
                    Button("Add departure task") { attempt { try store.addTripTask(trip, title: taskTitle); taskTitle = "" } }.disabled(taskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Button("Mark away") { attempt { try store.changeTripState(trip, to: .away) } }
                }
            }
            if trip.state == .away || trip.state == .packing { Section { Button("Start coming home") { attempt { try store.changeTripState(trip, to: .comingHome) } } } }
            if trip.state == .comingHome { Section("Coming home") {
                Text("\(trip.unresolvedEntries.count) packed rows still need a confirmed resolution. An end date never puts items away automatically.")
                Button("Finish coming home") { attempt { try store.changeTripState(trip, to: .finished) } }.disabled(!trip.unresolvedEntries.isEmpty)
            } }
            Section {
                if trip.state != .canceled && trip.state != .finished { Button("Cancel trip", role: .destructive) { canceling = true } }
                Button("Delete trip", role: .destructive) { deleting = true }
            }
        }
        .navigationTitle(trip.name).navigationBarTitleDisplayMode(.inline)
        .toolbar { if trip.state == .packing || trip.state == .away { Button("Edit") { edit = true } } }
        .sheet(isPresented: $edit) { NavigationStack { TripEditor(trip: trip) } }
        .sheet(isPresented: $adding) { NavigationStack { TripEntryAdder(trip: trip) } }
        .confirmationDialog("Cancel this trip? Its packing allocation will be cleared. Saved home locations will remain unchanged.", isPresented: $canceling, titleVisibility: .visible) { Button("Cancel trip", role: .destructive) { attempt { try store.changeTripState(trip, to: .canceled) } } }
        .confirmationDialog("Delete this trip and its checklists? Belongings and home locations will be kept.", isPresented: $deleting, titleVisibility: .visible) { Button("Delete trip", role: .destructive) { attempt { try store.deleteTrip(trip); dismiss() } } }
        .alert("Could not update trip", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") { error = nil } } message: { Text(error ?? "") }
    }
    private func attempt(_ action: () throws -> Void) { do { try action() } catch { self.error = error.localizedDescription } }
}

struct TripEntryAdder: View {
    @Environment(LocaliserStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let trip: TripRecord
    @State private var itemID: UUID?
    @State private var name = ""
    @State private var error: String?
    var body: some View {
        Form {
            Picker("Belonging", selection: $itemID) { Text("Free-text row").tag(nil as UUID?); ForEach(store.items.filter { !$0.archived }) { Text($0.name).tag(Optional($0.id)) } }
            if itemID == nil { TextField("Row name", text: $name) }
        }
        .navigationTitle("Add trip row").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("Save") {
                do { try store.addTripEntry(trip, name: name, item: store.items.first { $0.id == itemID }); dismiss() } catch { self.error = error.localizedDescription }
            }.disabled(itemID == nil && name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
        }
        .alert("Could not add row", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") { error = nil } } message: { Text(error ?? "") }
    }
}

struct TripEntryDetailView: View {
    @Environment(LocaliserStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let entry: TripEntry
    @State private var packed: Int
    @State private var quantity: Int
    @State private var placeID: UUID?
    @State private var deleting = false
    @State private var error: String?
    init(entry: TripEntry) { self.entry = entry; _packed = State(initialValue: Int(entry.packedCount)); _quantity = State(initialValue: entry.requiredCount) }
    var body: some View {
        let _ = store.revision
        List {
            Section {
                Text("\(entry.packedCount) packed / \(entry.requiredCount) needed")
                Text(entry.item?.place?.path ?? "Anywhere").foregroundStyle(.secondary)
                if let item = entry.item { NavigationLink("View belonging") { ItemDetailView(item: item) } }
            }
            if entry.trip?.state == .packing {
                Section("Packing") {
                    Stepper("Packed: \(packed)", value: $packed, in: 0...max(entry.requiredCount, Int(entry.packedCount)))
                    Button("Save packed count") { attempt { try store.pack(entry, count: packed) } }
                    Button("Pack all") { attempt { try store.pack(entry, count: entry.requiredCount); packed = Int(entry.packedCount) } }
                    Button("Unpack") { attempt { try store.pack(entry, count: 0); packed = 0 } }
                }
                Section("Quantity override") {
                    Stepper("Needed: \(quantity)", value: $quantity, in: 0...9999)
                    Button("Use manual quantity") { attempt { try store.setTripQuantity(entry, override: quantity) } }
                    Button("Use kit rule") { attempt { try store.setTripQuantity(entry, override: nil); quantity = entry.requiredCount } }
                    Text("Changing quantities does not erase the number already packed.").font(.caption).foregroundStyle(.secondary)
                }
                Section { Button("Remove row", role: .destructive) { deleting = true } }
            }
            if entry.trip?.state == .comingHome && entry.packedCount > 0 {
                Section("Coming home") {
                    Text("Resolution: \(entry.resolutionRaw)")
                    if entry.item?.archived == true {
                        Button("Confirm already returned / archived") { attempt { try store.resolveHome(entry, resolution: .noLongerHere) } }
                    } else {
                        Button(entry.item == nil ? "Confirm unpacked" : "Put back: \(entry.homePlace?.path ?? "location unspecified")") { attempt { try store.resolveHome(entry, resolution: .putBack) } }
                        if entry.item != nil {
                            PlacePicker(selection: $placeID)
                            Button("Confirm new place") { attempt { try store.resolveHome(entry, resolution: .newPlace, newPlace: store.places.first { $0.id == placeID }) } }.disabled(placeID == nil)
                        }
                    }
                    Button("Leave unresolved for now") { attempt { try store.resolveHome(entry, resolution: .unresolved) } }
                    Text("Unresolved rows stay on this checklist. Resolve them before finishing coming home.").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(entry.title).navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Remove this row and its packing allocation? The belonging's home location will not change.", isPresented: $deleting, titleVisibility: .visible) { Button("Remove row", role: .destructive) { attempt { try store.deleteTripEntry(entry); dismiss() } } }
        .alert("Could not update row", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") { error = nil } } message: { Text(error ?? "") }
    }
    private func attempt(_ action: () throws -> Void) { do { try action() } catch { self.error = error.localizedDescription } }
}
