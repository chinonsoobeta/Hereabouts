import SwiftUI

struct PackingView: View {
    @Environment(LocaliserStore.self) private var store
    @State private var newTrip = false
    @State private var newKit = false
    private var current: TripRecord? { store.trips.filter { $0.state == .packing || $0.state == .away || $0.state == .comingHome }.min { $0.startDay < $1.startDay } }
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                if let current {
                    NavigationLink { TripDetailView(trip: current) } label: { TripProgressCard(trip: current) }.buttonStyle(.plain)
                }
                SectionHeading(title: "Trips").padding(.top, 8)
                if store.trips.isEmpty { Text("Create a trip from a reusable kit or start an empty checklist.").foregroundStyle(Theme.secondary) }
                ForEach(store.trips.filter { $0.id != current?.id }) { trip in
                    NavigationLink { TripDetailView(trip: trip) } label: {
                        HStack(spacing: 14) {
                            IconTile(systemImage: "suitcase", size: 44, tone: trip.state == .finished ? .done : .neutral)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(trip.name).font(.wbItem).foregroundStyle(Theme.ink)
                                Text(trip.dateRange).font(.wbCaption).foregroundStyle(Theme.secondary)
                            }
                            Spacer(minLength: 8)
                            Pill(text: trip.stateTitle.capitalized, tone: trip.state == .finished ? .done : .neutral)
                        }.card()
                    }.buttonStyle(.plain)
                }
                Button("New trip") { newTrip = true }.buttonStyle(SoftButtonStyle())
                SectionHeading(title: "Reusable kits").padding(.top, 8)
                ForEach(store.kits) { kit in
                    NavigationLink { KitDetailView(kit: kit) } label: {
                        HStack(spacing: 14) {
                            IconTile(systemImage: "checklist", size: 44)
                            Text(kit.name).font(.wbItem).foregroundStyle(Theme.ink)
                            Spacer(minLength: 8)
                            Text(kit.entries.count == 1 ? "1 row" : "\(kit.entries.count) rows").font(.wbCaption).foregroundStyle(Theme.secondary)
                        }.card()
                    }.buttonStyle(.plain)
                }
                Button("New kit") { newKit = true }.buttonStyle(SoftButtonStyle())
                Text("Each trip gets its own packing and departure checklist. Changes to a kit apply to future trips.").font(.wbCaption).foregroundStyle(Theme.secondary)
            }
            .padding(.horizontal, 20).padding(.vertical, 12)
        }
        .background(Theme.ground).navigationTitle("Packing")
        .sheet(isPresented: $newTrip) { NavigationStack { TripEditor() } }
        .sheet(isPresented: $newKit) { NavigationStack { KitEditor() } }
    }
}

struct TripProgressCard: View {
    let trip: TripRecord
    var body: some View {
        let needed = trip.entries.reduce(0) { $0 + $1.requiredCount }
        let packed = trip.entries.reduce(0) { $0 + min(Int($1.packedCount), $1.requiredCount) }
        let fraction = needed == 0 ? 0 : Double(packed) / Double(needed)
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(trip.name).font(.wbTitle)
                Spacer(minLength: 8)
                Text("\(packed) of \(needed) packed").font(.wbLabel)
            }
            Text("\(trip.dateRange) · \(trip.details?.nights ?? 0) nights").font(.wbCaption).opacity(0.9)
            Capsule().fill(.white.opacity(0.25)).frame(height: 8)
                .overlay(alignment: .leading) { GeometryReader { proxy in Capsule().fill(.white).frame(width: proxy.size.width * fraction) } }
                .accessibilityHidden(true)
        }
        .foregroundStyle(.white)
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.purpleFill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

extension TripRecord {
    var dateRange: String {
        guard let start = CalendarDay(stored: startDay)?.date(), let end = CalendarDay(stored: endDay)?.date() else { return "\(startDay) to \(endDay)" }
        let format = Date.FormatStyle.dateTime.month(.abbreviated).day()
        return startDay == endDay ? start.formatted(format) : "\(start.formatted(format)) – \(end.formatted(format))"
    }
    var stateTitle: String { state == .comingHome ? "coming home" : stateRaw }
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
            .groundBackground().navigationTitle(kit == nil ? "New kit" : "Edit kit").navigationBarTitleDisplayMode(.inline)
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
                            Text("\(entry.unitQuantity)\(entry.perDay ? " per day" : entry.perNight ? " per night" : " in total") · \(entry.condition.title)").font(.caption).foregroundStyle(Theme.secondary)
                            if entry.unlinked && entry.item == nil { Text("Deleted item. Kept as a text row.").font(.caption).foregroundStyle(Theme.secondary) }
                            if entry.item?.archived == true { Text("Archived item: excluded from new trips").font(.caption).foregroundStyle(Theme.warning) }
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
        .groundBackground().navigationTitle(kit.name).navigationBarTitleDisplayMode(.inline).toolbar { Button("Edit") { edit = true } }
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
    @State private var scale: PackingScale
    @State private var condition: PackingCondition
    @State private var error: String?
    init(kit: Kit, entry: KitEntry? = nil) {
        self.kit = kit; self.entry = entry
        _name = State(initialValue: entry?.name ?? ""); _itemID = State(initialValue: entry?.item?.id)
        _quantity = State(initialValue: entry.map { Int($0.unitQuantity) } ?? 1)
        _scale = State(initialValue: entry?.scale ?? .once); _condition = State(initialValue: entry?.condition ?? .always)
    }
    private var scaleHint: String {
        switch scale {
        case .once: "Pack \(quantity) whatever the trip length."
        case .perDay: "\(quantity) for each day away, counting travel days. A day trip needs \(quantity); a weekend away needs \(quantity * 3)."
        case .perNight: "\(quantity) for each night away. A day trip needs none; a weekend away needs \(quantity * 2)."
        }
    }
    var body: some View {
        Form {
            Picker("Link a belonging", selection: $itemID) { Text("Free-text row").tag(nil as UUID?); ForEach(store.items.filter { !$0.archived }) { Text($0.name).tag(Optional($0.id)) } }
            if itemID == nil { TextField("Row name", text: $name).accessibilityIdentifier("kit.entry.name") }
            Stepper("Quantity: \(quantity)", value: $quantity, in: 1...99)
            Picker("Amount", selection: $scale) { ForEach(PackingScale.allCases) { Text($0.title).tag($0) } }
            Text(scaleHint).font(.caption).foregroundStyle(Theme.secondary)
            Picker("Include for", selection: $condition) { ForEach(PackingCondition.allCases) { Text($0.title).tag($0) } }
            Text("Rows linked to an item are grouped by where it lives. Text rows appear under Anywhere.").font(.caption).foregroundStyle(Theme.secondary)
        }
        .groundBackground().navigationTitle(entry == nil ? "Add packing row" : "Edit packing row").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("Save") {
                do { try store.setKitEntry(kit: kit, existing: entry, name: name, item: store.items.first { $0.id == itemID }, unit: quantity, perNight: scale.perNight, perDay: scale.perDay, condition: condition); dismiss() } catch { self.error = error.localizedDescription }
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
                    Text("Packed counts and manual quantity overrides will be kept. Review any excess or missing items after saving.").font(.caption).foregroundStyle(Theme.secondary)
                }
            }
        }
        .groundBackground().navigationTitle(trip == nil ? "New trip" : "Edit trip").navigationBarTitleDisplayMode(.inline)
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
    /// Says exactly what is left before the trip can be marked away.
    private var departureBlocker: String? {
        let unpacked = trip.entries.filter { $0.requiredCount > 0 && ($0.item?.archived == true || Int($0.packedCount) < $0.requiredCount) }.map(\.title).sorted()
        let tasks = trip.tasks.filter { !$0.checked }.map(\.title).sorted()
        guard !unpacked.isEmpty || !tasks.isEmpty else { return nil }
        var parts: [String] = []
        if !unpacked.isEmpty { parts.append("Still to pack: \(unpacked.prefix(5).joined(separator: ", "))\(unpacked.count > 5 ? " and \(unpacked.count - 5) more" : "").") }
        if !tasks.isEmpty { parts.append("Still to do: \(tasks.joined(separator: ", ")).") }
        return parts.joined(separator: "\n") + "\nOr choose Start coming home to skip packing checks."
    }
    var body: some View {
        let _ = store.revision
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    TripProgressCard(trip: trip)
                    Text("Status: \(trip.stateTitle)").font(.wbCaption).foregroundStyle(Theme.secondary)
                }.plainRow()
                if trip.state == .packing { Button("Add item or free-text row") { adding = true } }
            }
            ForEach(groups, id: \.self) { group in
                Section(group) {
                    ForEach(trip.entries.filter { ($0.item?.place?.path ?? "Anywhere") == group }.sorted { $0.title < $1.title }) { entry in
                        HStack(spacing: 12) {
                            if trip.state == .packing {
                                let done = entry.requiredCount > 0 && Int(entry.packedCount) >= entry.requiredCount
                                Button {
                                    attempt { try store.pack(entry, count: done ? 0 : entry.requiredCount) }
                                } label: {
                                    Image(systemName: done ? "checkmark.circle.fill" : "circle").font(.title2).foregroundStyle(done ? Theme.purple : Theme.secondary)
                                        .frame(width: 44, height: 44).contentShape(Rectangle())
                                }
                                .buttonStyle(.borderless)
                                .accessibilityLabel(done ? "Unpack \(entry.title)" : "Pack \(entry.title)")
                            }
                            NavigationLink { TripEntryDetailView(entry: entry) } label: {
                                VStack(alignment: .leading) {
                                    Text(entry.title).font(.wbItem)
                                    Text("\(entry.packedCount) packed / \(entry.requiredCount) needed").font(.subheadline).foregroundStyle(Theme.secondary)
                                    if entry.item?.archived == true { Text("Archived or returned. Resolve or remove this row.").font(.caption).foregroundStyle(Theme.warning) }
                                    if entry.unlinked && entry.item == nil { Text("Deleted item. Kept as a text row.").font(.caption).foregroundStyle(Theme.secondary) }
                                    if trip.state == .comingHome { Text("Coming home: \(entry.resolutionRaw)").font(.caption) }
                                }
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
                    Button("Mark away") {
                        if let blocker = departureBlocker { error = blocker } else { attempt { try store.changeTripState(trip, to: .away) } }
                    }
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
        .groundBackground().navigationTitle(trip.name).navigationBarTitleDisplayMode(.inline)
        .toolbar { if trip.state == .packing || trip.state == .away { Button("Edit") { edit = true } } }
        .sheet(isPresented: $edit) { NavigationStack { TripEditor(trip: trip) } }
        .sheet(isPresented: $adding) { NavigationStack { TripEntryAdder(trip: trip) } }
        .confirmationDialog("Cancel this trip? Its packing allocation will be cleared. Saved home locations will remain unchanged.", isPresented: $canceling, titleVisibility: .visible) { Button("Cancel trip", role: .destructive) { attempt { try store.changeTripState(trip, to: .canceled) } } }
        .confirmationDialog("Delete this trip and its checklists? Belongings and home locations will be kept.", isPresented: $deleting, titleVisibility: .visible) { Button("Delete trip", role: .destructive) { attempt { try store.deleteTrip(trip); dismiss() } } }
        .alert("Not quite ready", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") { error = nil } } message: { Text(error ?? "") }
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
        .groundBackground().navigationTitle("Add trip row").navigationBarTitleDisplayMode(.inline)
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
                Text(entry.item?.place?.path ?? "Anywhere").foregroundStyle(Theme.secondary)
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
                    Text("Changing quantities does not erase the number already packed.").font(.caption).foregroundStyle(Theme.secondary)
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
                    Text("Unresolved rows stay on this checklist. Resolve them before finishing coming home.").font(.caption).foregroundStyle(Theme.secondary)
                }
            }
        }
        .groundBackground().navigationTitle(entry.title).navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Remove this row and its packing allocation? The belonging's home location will not change.", isPresented: $deleting, titleVisibility: .visible) { Button("Remove row", role: .destructive) { attempt { try store.deleteTripEntry(entry); dismiss() } } }
        .alert("Could not update row", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") { error = nil } } message: { Text(error ?? "") }
    }
    private func attempt(_ action: () throws -> Void) { do { try action() } catch { self.error = error.localizedDescription } }
}
