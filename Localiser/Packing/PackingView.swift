import SwiftUI
import TipKit

struct PackingView: View {
    @Environment(LocaliserStore.self) private var store
    @State private var newTrip = false
    @State private var newKit = false
    @State private var showPast = false
    private var active: [TripRecord] { store.tripsHere.filter { [.packing, .away, .comingHome].contains($0.state) }.sorted { $0.startDay < $1.startDay } }
    private var past: [TripRecord] { store.tripsHere.filter { $0.state == .finished || $0.state == .canceled }.sorted { $0.startDay > $1.startDay } }
    var body: some View {
        let _ = store.revision
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                HomeSwitcher()
                if store.tripsHere.isEmpty && store.kitsHere.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .top) {
                            Image(systemName: "suitcase.rolling").foregroundStyle(Theme.purple).accessibilityHidden(true)
                            Text("What do you need for your trip?").fixedSize(horizontal: false, vertical: true)
                        }.font(.wbTitle)
                        Text("Make a checklist for a trip. Check off things as you pack. Put them away when you're home.")
                            .font(.wbBody).foregroundStyle(Theme.ink).fixedSize(horizontal: false, vertical: true)
                        Button("Plan a trip") { newTrip = true }.buttonStyle(PrimaryButtonStyle())
                        HStack(spacing: 12) {
                            Text("Take the same things each time? Save them as a kit.").font(.wbCaption).foregroundStyle(Theme.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                            Button { newKit = true } label: { Label("New kit", systemImage: "plus").font(.wbItem) }
                                .buttonStyle(SoftButtonStyle(compact: true))
                        }
                    }.card(padding: 16)
                } else {
                    SectionHeading(title: String(localized: "Trips"))
                    ForEach(Array(active.enumerated()), id: \.element.id) { index, trip in
                        NavigationLink { TripDetailView(trip: trip) } label: {
                            if index == 0 { TripProgressCard(trip: trip) } else { TripRow(trip: trip) }
                        }.buttonStyle(.plain)
                    }
                    Button("Plan a trip", systemImage: "plus") { newTrip = true }.buttonStyle(SoftButtonStyle())
                    if !past.isEmpty {
                        DisclosureGroup(isExpanded: $showPast) {
                            VStack(spacing: 12) {
                                ForEach(past) { trip in NavigationLink { TripDetailView(trip: trip) } label: { TripRow(trip: trip) }.buttonStyle(.plain) }
                            }.padding(.top, 8)
                        } label: { Text("Past trips (\(past.count))").font(.wbItem).foregroundStyle(Theme.ink) }
                        .tint(Theme.purpleInk)
                    }
                    SectionHeading(title: String(localized: "Kits")).padding(.top, 8)
                    if store.kitsHere.isEmpty {
                        Text("Save a kit to reuse a list, like \u{201C}Weekend away\u{201D}. Use it to plan a trip.").font(.wbCaption).foregroundStyle(Theme.secondary)
                    }
                    ForEach(store.kitsHere) { kit in
                        NavigationLink { KitDetailView(kit: kit) } label: {
                            NotebookLine(name: kit.name, detail: String(localized: "\(kit.entries.count) things")).card()
                        }.buttonStyle(.plain)
                    }
                    Button("New kit", systemImage: "plus") { newKit = true }.buttonStyle(SoftButtonStyle())
                }
            }
            .padding(.horizontal, 20).padding(.vertical, 12)
        }
        .background(Theme.ground).navigationTitle("Trips")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Plan a trip", systemImage: "plus") { newTrip = true } } }
        .sheet(isPresented: $newTrip) { NavigationStack { TripEditor() } }
        .sheet(isPresented: $newKit) { NavigationStack { KitEditor() } }
    }
}

struct TripRow: View {
    let trip: TripRecord
    var body: some View {
        HStack(spacing: 14) {
            IconTile(systemImage: "suitcase", size: 44, tone: trip.state == .finished ? .done : .neutral)
            VStack(alignment: .leading, spacing: 2) {
                NotebookLine(name: trip.name, detail: trip.dateRange)
            }
            Spacer(minLength: 8)
            Stamp(text: trip.stateTitle, tone: trip.state == .finished ? .done : .neutral)
        }.card()
    }
}

/// Packing → Away → Coming home → Done, with the current stage highlighted.
struct TripStageStrip: View {
    let state: TripState
    private static let stages: [(TripState, String)] = [(.packing, String(localized: "Packing")), (.away, String(localized: "Away")), (.comingHome, String(localized: "Home")), (.finished, String(localized: "Done"))]
    var body: some View {
        let current = Self.stages.firstIndex { $0.0 == state } ?? -1
        HStack(spacing: 6) {
            ForEach(Array(Self.stages.enumerated()), id: \.offset) { index, stage in
                VStack(spacing: 4) {
                    Capsule().fill(index <= current ? Theme.purpleFill : Theme.lilac).frame(height: 6)
                    Text(stage.1).font(.wbCaption).foregroundStyle(index == current ? Theme.purpleInk : Theme.secondary)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "Status: \(state == .canceled ? String(localized: "called off") : (TripState.titles[state] ?? "").lowercased())"))
    }
}

/// One checklist row. It reads the store's revision itself: the task is a Core Data object, so SwiftUI can't see
/// `checked` change, and on iOS 27 a row whose inputs look unchanged was left showing the old tick.
struct TripTaskRow: View {
    @Environment(LocaliserStore.self) private var store
    let task: TripTask
    let toggle: () -> Void
    let delete: () -> Void
    var body: some View {
        let _ = store.revision
        Button(action: toggle) {
            Label { Text(task.title).foregroundStyle(Theme.ink).strikethrough(task.checked, color: Theme.secondary) } icon: {
                PenCheckbox(checked: task.checked)
            }
        }
        .accessibilityLabel(task.title).accessibilityAddTraits(task.checked ? .isSelected : [])
        .accessibilityIdentifier("task.\(task.title)")
        .swipeActions { Button("Delete", role: .destructive, action: delete) }
    }
}

struct TripProgressCard: View {
    @Environment(LocaliserStore.self) private var store
    let trip: TripRecord
    var body: some View {
        let _ = store.revision
        let needed = trip.entries.reduce(0) { $0 + $1.requiredCount }
        let packed = trip.entries.reduce(0) { $0 + min(Int($1.packedCount), $1.requiredCount) }
        let fraction = needed == 0 ? 0 : Double(packed) / Double(needed)
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                NotebookLine(name: trip.name, detail: String(localized: "\(packed) of \(needed) packed"))
            }
            Text([trip.dateRange, trip.details?.nightsLabel].compactMap { $0 }.joined(separator: " · ")).font(.wbCaption).opacity(0.9)
            ProgressView(value: fraction).tint(Theme.purpleInk).accessibilityLabel("Packing progress")
        }
        .foregroundStyle(Theme.ink)
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.paper)
        .overlay { Rectangle().stroke(Theme.ink, style: StrokeStyle(lineWidth: 1.5, dash: [2, 4])) }
    }
}

extension TripRecord {
    var dateRange: String {
        guard let start = CalendarDay(stored: startDay)?.date(), let end = CalendarDay(stored: endDay)?.date() else { return String(localized: "\(startDay) to \(endDay)") }
        let format = Date.FormatStyle.dateTime.month(.abbreviated).day()
        return startDay == endDay ? start.formatted(format) : "\(start.formatted(format)) – \(end.formatted(format))"
    }
    var stateTitle: String { state.flatMap { TripState.titles[$0] } ?? stateRaw }
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
        SheetForm { TextField("Kit name", text: $name).accessibilityIdentifier("kit.name") }
            .groundBackground().navigationTitle(kit == nil ? "New kit" : "Edit kit").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") {
                    if kit == nil && !pro.allows(.kit, count: store.kits.count) { upgrade = true; return }
                    do { if let kit { try store.editKit(kit, name: name) } else { try store.addKit(name: name) }; dismiss() } catch { self.error = error.localizedDescription }
                }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).accessibilityIdentifier("kit.save") }
            }
            .alert("Couldn't save", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") { error = nil } } message: { Text(error ?? "") }
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
        SheetList {
            Section {
                Button("Plan a trip with this kit", systemImage: "suitcase") { trip = true }.buttonStyle(PrimaryButtonStyle()).plainRow()
            }
            Section {
                ForEach(kit.entries.sorted { $0.title < $1.title }) { entry in
                    Button { editingEntry = entry } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.title).font(.wbItem).foregroundStyle(Theme.ink)
                            Text(entry.ruleSummary).font(.wbCaption).foregroundStyle(Theme.secondary)
                            if entry.unlinked && entry.item == nil { Text("You deleted this thing. Its name stays on the list.").font(.wbCaption).foregroundStyle(Theme.secondary) }
                            if entry.item?.archived == true { Text("You archived this thing. It won't be added to new trips.").font(.wbCaption).foregroundStyle(Theme.warning) }
                        }
                    }.swipeActions { Button("Delete", role: .destructive) { attempt { try store.deleteKitEntry(entry) } } }
                }
                Button("Add something to pack", systemImage: "plus") { addEntry = true }
            } header: { Text("What to pack").foregroundStyle(Theme.secondary) }
            Section {
                ForEach(kit.tasks.sorted { $0.title < $1.title }) { task in Text(task.title).swipeActions { Button("Delete", role: .destructive) { attempt { try store.deleteKitTask(task) } } } }
                AddTaskField(title: $taskTitle) { attempt { try store.addKitTask(kit, title: taskTitle); taskTitle = "" } }
            } header: { Text("Before you leave").foregroundStyle(Theme.secondary) }
              footer: { Text("Use this kit when you plan a trip. Later edits to the kit won't change that trip.").foregroundStyle(Theme.secondary) }
        }
        .groundBackground().navigationTitle(kit.name).navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { Button("Edit") { edit = true } }
            ToolbarItem(placement: .topBarTrailing) {
                Menu { Button("Delete kit", systemImage: "trash", role: .destructive) { deleting = true } } label: { Image(systemName: "ellipsis") }.accessibilityLabel("Kit options")
            }
        }
        .sheet(isPresented: $edit) { NavigationStack { KitEditor(kit: kit) } }
        .sheet(isPresented: $addEntry) { NavigationStack { KitEntryEditor(kit: kit) } }
        .sheet(item: $editingEntry) { entry in NavigationStack { KitEntryEditor(kit: kit, entry: entry) } }
        .sheet(isPresented: $trip) { NavigationStack { TripEditor(kit: kit) } }
        .confirmationDialog("Delete \u{201C}\(kit.name)\u{201D}?", isPresented: $deleting, titleVisibility: .visible) { Button("Delete kit", role: .destructive) { attempt { try store.deleteKit(kit); dismiss() } } } message: { Text("Trips you've already planned keep their own lists.") }
        .alert("Couldn't update the kit", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") { error = nil } } message: { Text(error ?? "") }
    }
    private func attempt(_ action: () throws -> Void) { do { try action() } catch { self.error = error.localizedDescription } }
}

/// A single row that adds a task when you press Return.
struct AddTaskField: View {
    @Binding var title: String
    var add: () -> Void
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "plus.circle").foregroundStyle(Theme.purpleInk).accessibilityHidden(true)
            TextField("Add a task", text: $title).submitLabel(.done)
                .onSubmit { if !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { add() } }
                .accessibilityIdentifier("task.add")
        }
    }
}

extension KitEntry {
    /// "1 · every trip", "2 per night · flying".
    var ruleSummary: String {
        let amount = perDay ? String(localized: "\(unitQuantity) per day") : perNight ? String(localized: "\(unitQuantity) per night") : "\(unitQuantity)"
        let trips = switch condition {
        case .always: String(localized: "every trip")
        case .flying: String(localized: "flying trips")
        case .international: String(localized: "international trips")
        case .work: String(localized: "work trips")
        }
        return "\(amount) · \(trips)"
    }
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
    private var home: HomeRecord? { kit.home }
    init(kit: Kit, entry: KitEntry? = nil) {
        self.kit = kit; self.entry = entry
        _name = State(initialValue: entry?.name ?? ""); _itemID = State(initialValue: entry?.item?.id)
        _quantity = State(initialValue: entry.map { Int($0.unitQuantity) } ?? 1)
        _scale = State(initialValue: entry?.scale ?? .once); _condition = State(initialValue: entry?.condition ?? .always)
    }
    private var scaleHint: String {
        switch scale {
        case .once: String(localized: "Pack \(quantity) for any trip length.")
        case .perDay: String(localized: "\(quantity) for each day away, counting travel days. A day trip needs \(quantity); a weekend away needs \(quantity * 3).")
        case .perNight: String(localized: "\(quantity) for each night away. A day trip needs none; a weekend away needs \(quantity * 2).")
        }
    }
    var body: some View {
        SheetForm {
            Picker("Thing", selection: $itemID) { Text("None, just a name").tag(nil as UUID?); ForEach(store.items.filter { !$0.archived && (home == nil || $0.home == home) }) { Text($0.name).tag(Optional($0.id)) } }
            if itemID == nil { TextField("Name, like Phone charger", text: $name).accessibilityIdentifier("kit.entry.name") }
            Stepper("Quantity: \(quantity)", value: $quantity, in: 1...99)
            Picker("Amount", selection: $scale) { ForEach(PackingScale.allCases) { Text($0.title).tag($0) } }
            Text(scaleHint).font(.caption).foregroundStyle(Theme.secondary)
            Picker("Include for", selection: $condition) { ForEach(PackingCondition.allCases) { Text($0.title).tag($0) } }
            Text("Choose a thing from your notebook to pack by place.").font(.caption).foregroundStyle(Theme.secondary)
        }
        .groundBackground().navigationTitle(entry == nil ? "Add to kit" : "Edit").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("Save") {
                do { try store.setKitEntry(kit: kit, existing: entry, name: name, item: store.items.first { $0.id == itemID }, unit: quantity, perNight: scale.perNight, perDay: scale.perDay, condition: condition); dismiss() } catch { self.error = error.localizedDescription }
            }.disabled(itemID == nil && name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).accessibilityIdentifier("kit.entry.save") }
        }
        .alert("Couldn't save", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") { error = nil } } message: { Text(error ?? "") }
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
        SheetForm {
            Section("Trip") {
                TextField("Trip name", text: $name).accessibilityIdentifier("trip.name")
                DatePicker("Leave", selection: $start, displayedComponents: .date)
                DatePicker("Come home", selection: $end, displayedComponents: .date)
                if details.end < details.start { Text("Come home on or after the day you leave.").foregroundStyle(Theme.warning) }
                else { Text(details.nightsLabel) }
                Toggle("Flying", isOn: $flying); Toggle("International", isOn: $international); Toggle("Work", isOn: $work)
                if trip == nil { Picker("Kit", selection: $kitID) { Text("Start without a kit").tag(nil as UUID?); ForEach(store.kitsHere) { Text($0.name).tag(Optional($0.id)) } } }
            }
            if let trip {
                Section("Quantity changes") {
                    ForEach(trip.entries.filter { $0.required(for: details) != $0.requiredCount }.sorted { $0.title < $1.title }) { entry in Text("\(entry.title): \(entry.requiredCount) → \(entry.required(for: details)); \(entry.packedCount) already packed") }
                    Text("You keep your packed counts and quantities you've set. Check the list after you save.").font(.caption).foregroundStyle(Theme.secondary)
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
        .alert("Couldn't save", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") { error = nil } } message: { Text(error ?? "") }
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
    @State private var notReady: String?
    @State private var lentPacking: TripEntry?
    @State private var error: String?
    private var groups: [String] { Set(trip.entries.map { $0.item?.place?.path ?? String(localized: "Anywhere") }).sorted() }
    /// Says exactly what is left before the trip can be marked away.
    private var departureBlocker: String? {
        let unpacked = trip.entries.filter { $0.requiredCount > 0 && ($0.item?.archived == true || Int($0.packedCount) < $0.requiredCount) }.map(\.title).sorted()
        let tasks = trip.tasks.filter { !$0.checked }.map(\.title).sorted()
        guard !unpacked.isEmpty || !tasks.isEmpty else { return nil }
        var parts: [String] = []
        if !unpacked.isEmpty {
            let list = unpacked.prefix(5).joined(separator: ", ")
            parts.append(unpacked.count > 5 ? String(localized: "Still to pack: \(list) and \(unpacked.count - 5) more.") : String(localized: "Still to pack: \(list)."))
        }
        if !tasks.isEmpty { parts.append(String(localized: "Still to do: \(tasks.joined(separator: ", ")).")) }
        return parts.joined(separator: "\n")
    }
    var body: some View {
        let _ = store.revision
        SheetList {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    TripProgressCard(trip: trip)
                    TripStageStrip(state: trip.state ?? .packing)
                    if trip.state == .canceled { Text("You called off this trip.").font(.wbCaption).foregroundStyle(Theme.secondary) }
                }.plainRow()
                if trip.state == .packing { TipView(LeavingTip()).plainRow() }
                stageButton
            }
            // A card of its own. As the only ordinary row under the plain header, it had square top corners.
            if trip.state == .packing {
                Section { Button("Add something to pack", systemImage: "plus") { adding = true } }
            }
            ForEach(groups, id: \.self) { group in
                Section(group) {
                    ForEach(trip.entries.filter { ($0.item?.place?.path ?? String(localized: "Anywhere")) == group }.sorted { $0.title < $1.title }) { entry in entryRow(entry) }
                }
            }
            if trip.state == .packing {
                Section {
                    ForEach(trip.tasks.sorted { $0.title < $1.title }) { task in
                        TripTaskRow(task: task, toggle: { attempt { try store.checkTask(task, checked: !task.checked) } }, delete: { attempt { try store.deleteTripTask(task) } })
                    }
                    AddTaskField(title: $taskTitle) { attempt { try store.addTripTask(trip, title: taskTitle); taskTitle = "" } }
                } header: { Text("Before you leave").foregroundStyle(Theme.secondary) }
            }
            if trip.state == .comingHome {
                Section {
                    let left = trip.unresolvedEntries.count
                    Text(left == 0 ? "You're done unpacking. You can finish the trip." : left == 1 ? "Put away 1 more thing. Tap it to say where it went." : "Put away \(left) more things. Tap each one to say where it went.")
                        .foregroundStyle(Theme.secondary)
                } header: { Text("Unpacking").foregroundStyle(Theme.secondary) }
            }
        }
        .groundBackground().navigationTitle(trip.name).navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if trip.state == .packing || trip.state == .away { Button("Edit trip", systemImage: "pencil") { edit = true } }
                    if trip.state == .packing { Button("Skip to coming home", systemImage: "house") { attempt { try store.changeTripState(trip, to: .comingHome) } } }
                    if trip.state != .canceled && trip.state != .finished { Button("Call off trip", systemImage: "xmark.circle") { canceling = true } }
                    Divider()
                    Button("Delete trip", systemImage: "trash", role: .destructive) { deleting = true }
                } label: { Image(systemName: "ellipsis") }
                .accessibilityLabel("Trip options")
            }
        }
        .sheet(isPresented: $edit) { NavigationStack { TripEditor(trip: trip) } }
        .sheet(isPresented: $adding) { NavigationStack { TripEntryAdder(trip: trip) } }
        .confirmationDialog("Call off \u{201C}\(trip.name)\u{201D}?", isPresented: $canceling, titleVisibility: .visible) { Button("Call off trip", role: .destructive) { attempt { try store.changeTripState(trip, to: .canceled) } } } message: { Text("You keep its packing list. Your things stay in their places.") }
        .confirmationDialog("Delete \u{201C}\(trip.name)\u{201D}?", isPresented: $deleting, titleVisibility: .visible) { Button("Delete trip", role: .destructive) { attempt { try store.deleteTrip(trip); dismiss() } } } message: { Text("You delete the trip and its lists. You keep your things and their places.") }
        .confirmationDialog("\(lentPacking?.title ?? String(localized: "It")) is with \(lentPacking?.item?.lentTo ?? String(localized: "someone"))", isPresented: Binding(get: { lentPacking != nil }, set: { if !$0 { lentPacking = nil } }), titleVisibility: .visible, presenting: lentPacking) { entry in
            Button("Pack it anyway") { attempt { try store.pack(entry, count: entry.requiredCount) } }
            if let item = entry.item { Button("It's back, pack it") { attempt { try store.gotBack(item); try store.pack(entry, count: entry.requiredCount) } } }
        } message: { _ in Text("The notebook says it's lent out.") }
        .alert("Not quite ready", isPresented: Binding(get: { notReady != nil }, set: { if !$0 { notReady = nil } })) {
            Button("Keep packing", role: .cancel) { notReady = nil }
            Button("Leave anyway") { notReady = nil; attempt { try store.changeTripState(trip, to: .comingHome) } }
        } message: { Text((notReady ?? "") + "\n\n" + String(localized: "Choose Leave anyway to skip packing checks and go to unpacking when you're back.")) }
        .alert("Couldn't update the trip", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") { error = nil } } message: { Text(error ?? "") }
    }

    @ViewBuilder private var stageButton: some View {
        switch trip.state {
        case .packing:
            Button("I'm leaving") {
                if let blocker = departureBlocker { notReady = blocker } else { attempt { try store.changeTripState(trip, to: .away) } }
            }.buttonStyle(PrimaryButtonStyle()).plainRow()
        case .away:
            Button("I'm coming home") { attempt { try store.changeTripState(trip, to: .comingHome) } }.buttonStyle(PrimaryButtonStyle()).plainRow()
        case .comingHome:
            Button("Finish trip") { attempt { try store.changeTripState(trip, to: .finished) } }
                .buttonStyle(PrimaryButtonStyle()).disabled(!trip.unresolvedEntries.isEmpty).plainRow()
        case .finished, .canceled, .none:
            EmptyView()
        }
    }

    @ViewBuilder private func entryRow(_ entry: TripEntry) -> some View {
        HStack(spacing: 12) {
            if trip.state == .packing {
                let done = entry.requiredCount > 0 && Int(entry.packedCount) >= entry.requiredCount
                Button {
                    // Packing something that's lent out is probably a mistake; ask first.
                    if !done, entry.item?.isLent == true { lentPacking = entry }
                    else { attempt { try store.pack(entry, count: done ? 0 : entry.requiredCount) } }
                } label: {
                    PenCheckbox(checked: done)
                        .frame(width: 44, height: 44).contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(done ? "Unpack \(entry.title)" : "Pack \(entry.title)")
            }
            NavigationLink { TripEntryDetailView(entry: entry) } label: {
                VStack(alignment: .leading, spacing: 2) {
                    NotebookLine(name: entry.title, detail: entry.requiredCount == 0 ? String(localized: "Not needed for this trip") : String(localized: "\(entry.packedCount) of \(entry.requiredCount) packed"))
                    if entry.item?.archived == true { Text("Archived or returned. Remove it or mark it no longer here.").font(.wbCaption).foregroundStyle(Theme.warning) }
                    if let item = entry.item, item.isLent { Text("With \(item.lentTo)").font(.wbCaption).foregroundStyle(Theme.warning) }
                    if entry.unlinked && entry.item == nil { Text("You deleted this thing. Its name stays on the list.").font(.wbCaption).foregroundStyle(Theme.secondary) }
                    if trip.state == .comingHome, entry.packedCount > 0 { Text(entry.resolution?.title ?? "").font(.wbCaption).foregroundStyle(entry.resolution == .pending || entry.resolution == .unresolved ? Theme.warning : Theme.sageInk) }
                }
            }
        }
    }
    private func attempt(_ action: () throws -> Void) { do { try action() } catch { self.error = error.localizedDescription } }
}

struct TripEntryAdder: View {
    @Environment(LocaliserStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let trip: TripRecord
    private var home: HomeRecord? { trip.home }
    @State private var itemID: UUID?
    @State private var name = ""
    @State private var error: String?
    var body: some View {
        SheetForm {
            Picker("Thing", selection: $itemID) { Text("None, just a name").tag(nil as UUID?); ForEach(store.items.filter { !$0.archived && (home == nil || $0.home == home) }) { Text($0.name).tag(Optional($0.id)) } }
            if itemID == nil { TextField("Name, like Sunglasses", text: $name) }
        }
        .groundBackground().navigationTitle("Add something to pack").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("Save") {
                do { try store.addTripEntry(trip, name: name, item: store.items.first { $0.id == itemID }); dismiss() } catch { self.error = error.localizedDescription }
            }.disabled(itemID == nil && name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
        }
        .alert("Couldn't add it", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") { error = nil } } message: { Text(error ?? "") }
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
        SheetList {
            Section {
                Text("\(entry.packedCount) of \(entry.requiredCount) packed")
                Text(entry.item?.place?.path ?? String(localized: "Anywhere")).foregroundStyle(Theme.secondary)
                if let item = entry.item { NavigationLink("Open \(item.name)") { ItemDetailView(item: item) } }
            }
            if entry.trip?.state == .packing {
                Section("Packing") {
                    Stepper("Packed: \(packed)", value: $packed, in: 0...max(entry.requiredCount, Int(entry.packedCount)))
                    Button("Save packed count") { attempt { try store.pack(entry, count: packed) } }
                    Button("Pack all") { attempt { try store.pack(entry, count: entry.requiredCount); packed = Int(entry.packedCount) } }
                    Button("Unpack") { attempt { try store.pack(entry, count: 0); packed = 0 } }
                }
                Section("Set quantity") {
                    Stepper("Needed: \(quantity)", value: $quantity, in: 0...9999)
                    Button("Use this quantity") { attempt { try store.setTripQuantity(entry, override: quantity) } }
                    Button("Use kit rule") { attempt { try store.setTripQuantity(entry, override: nil); quantity = entry.requiredCount } }
                    Text("Changing how many are needed doesn't unpack anything.").font(.caption).foregroundStyle(Theme.secondary)
                }
                Section { Button("Remove from this trip", role: .destructive) { deleting = true } }
            }
            if entry.trip?.state == .comingHome && entry.packedCount > 0 {
                Section("Coming home") {
                    Text(entry.resolution?.title ?? "")
                    if entry.item?.archived == true {
                        Button("Confirm returned or archived") { attempt { try store.resolveHome(entry, resolution: .noLongerHere) } }
                    } else {
                        Button(entry.item == nil ? "Confirm unpacked" : "Put back: \(entry.homePlace?.path ?? String(localized: "no place yet"))") { attempt { try store.resolveHome(entry, resolution: .putBack) } }
                        if entry.item != nil {
                            PlacePicker(selection: $placeID, home: entry.item?.home)
                            Button("Confirm new place") { attempt { try store.resolveHome(entry, resolution: .newPlace, newPlace: store.places.first { $0.id == placeID }) } }.disabled(placeID == nil)
                        }
                    }
                    Button("Leave unresolved for now") { attempt { try store.resolveHome(entry, resolution: .unresolved) } }
                    Text("You can leave things on this list for later. Put them away before you finish the trip.").font(.caption).foregroundStyle(Theme.secondary)
                }
            }
        }
        .groundBackground().navigationTitle(entry.title).navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Remove it from this trip? Where it lives doesn't change.", isPresented: $deleting, titleVisibility: .visible) { Button("Remove", role: .destructive) { attempt { try store.deleteTripEntry(entry); dismiss() } } }
        .alert("Couldn't update", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") { error = nil } } message: { Text(error ?? "") }
    }
    private func attempt(_ action: () throws -> Void) { do { try action() } catch { self.error = error.localizedDescription } }
}
