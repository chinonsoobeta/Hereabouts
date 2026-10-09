import SwiftUI
import EventKit
import EventKitUI
import TipKit

struct DueView: View {
    @Environment(LocaliserStore.self) private var store
    @Environment(ReminderService.self) private var reminders
    @State private var addDate = false
    @State private var showClosed = false
    @State private var calendarFor: Deadline?
    @State private var addingAll = false
    @State private var notice: String?
    @State private var error: String?
    private let sections = ["Missed", "Decide soon", "Returning", "Warranties ending", "Expiring"]

    private func section(_ deadline: Deadline) -> String {
        if let day = deadline.day, day < CalendarDay(.now) { return "Missed" }
        if deadline.kind == .warranty { return "Warranties ending" }
        if deadline.kind == .expiry { return "Expiring" }
        return deadline.decision == .returning ? "Returning" : "Decide soon"
    }

    var body: some View {
        let _ = store.revision
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                if !store.deadlines.contains(where: \.active) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .top) {
                            Image(systemName: "calendar.badge.clock").foregroundStyle(Theme.purple).accessibilityHidden(true)
                            Text("Remember in time").fixedSize(horizontal: false, vertical: true)
                        }.font(.wbTitle)
                        Text("Add a return deadline, warranty end or expiry date to an item. Hereabouts reminds you before it passes.")
                            .font(.wbBody).foregroundStyle(Theme.ink).fixedSize(horizontal: false, vertical: true)
                    }.card(padding: 16)
                }
                if store.deadlines.contains(where: \.active) { TipView(CalendarTip()).tipBackground(Theme.card) }
                ForEach(sections, id: \.self) { heading in dateSection(heading) }
                if showClosed {
                    SectionHeading(title: "Completed").padding(.top, 8)
                    ForEach(store.deadlines.filter { !$0.active }) { deadline in
                        NavigationLink { DeadlineDetailView(deadline: deadline) } label: { DueCard(deadline: deadline) }.buttonStyle(.plain)
                    }
                }
                if store.deadlines.contains(where: \.active) { coverageCard.padding(.top, 8) }
            }
            .padding(.horizontal, 20).padding(.vertical, 12)
        }
        .background(Theme.ground).navigationTitle("Due soon")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu("More", systemImage: "ellipsis.circle") {
                    Button("Add all to Calendar", systemImage: "calendar.badge.plus") { Task { await addAllToCalendar() } }.disabled(upcoming.isEmpty || addingAll)
                    if store.deadlines.contains(where: { !$0.active }) {
                        Toggle("Show completed", systemImage: "checkmark.circle", isOn: $showClosed)
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) { Button("Add date", systemImage: "plus") { addDate = true } }
        }
        .sheet(item: $calendarFor) { CalendarEventEditor(deadline: $0) }
        .alert("Added to Calendar", isPresented: Binding(get: { notice != nil }, set: { if !$0 { notice = nil } })) { Button("OK") { notice = nil } } message: { Text(notice ?? "") }
        .sheet(isPresented: $addDate) { NavigationStack {
            List {
                if store.items.filter({ !$0.archived }).isEmpty {
                    Section {
                        Text("Dates belong to an item. Add the item first, then its return, warranty or expiry date.").foregroundStyle(Theme.secondary)
                        NavigationLink { ItemEditor() } label: { Label("Add an item", systemImage: "plus") }
                    }
                }
                ForEach(store.items.filter { !$0.archived }) { item in NavigationLink { DeadlineEditor(item: item) } label: { ItemRow(item: item) } }
            }.groundBackground().navigationTitle("Which item?").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { addDate = false } } }
        } }
        .alert("Could not update date", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") { error = nil } } message: { Text(error ?? "") }
    }

    @ViewBuilder private func dateSection(_ heading: String) -> some View {
                    let dates = store.deadlines.filter { $0.active && section($0) == heading }.sorted { $0.dayString < $1.dayString }
                    if !dates.isEmpty {
                        SectionHeading(title: heading).padding(.top, 8)
                        ForEach(dates) { deadline in
                            if heading == "Decide soon" {
                                VStack(spacing: 14) {
                                    NavigationLink { DeadlineDetailView(deadline: deadline) } label: { DueCard(deadline: deadline, embedded: true) }.buttonStyle(.plain)
                                        .contextMenu { calendarMenu(deadline) }
                                    HStack(spacing: 10) {
                                        Button("Return it") { decide(deadline, .returning) }.buttonStyle(PrimaryButtonStyle())
                                        Button("Keep it") { decide(deadline, .keeping) }.buttonStyle(SoftButtonStyle())
                                    }
                                }.card()
                            } else {
                                NavigationLink { DeadlineDetailView(deadline: deadline) } label: { DueCard(deadline: deadline) }.buttonStyle(.plain)
                                    .contextMenu { calendarMenu(deadline) }
                            }
                        }
                    }
                    }

    private var coverageCard: some View {
                VStack(alignment: .leading, spacing: 10) {
                    Label { Text("Reminders").font(.wbItem) } icon: { Image(systemName: reminders.coverageGap ? "bell.badge" : "bell").foregroundStyle(reminders.coverageGap ? Theme.warning : Theme.purpleInk) }
                        .accessibilityAddTraits(.isHeader)
                    Text(coverageSummary).fixedSize(horizontal: false, vertical: true)
                    if reminders.permission == "Enabled" || reminders.permission == "Quiet delivery" {
                        if reminders.coverageGap { Text("Some reminders aren't queued yet because iPhone allows a limited number at once. Opening Hereabouts tops up the queue, or add the dates to Calendar.").font(.wbCaption).foregroundStyle(Theme.secondary).fixedSize(horizontal: false, vertical: true) }
                    } else if reminders.permission == "Disabled in Settings", let url = URL(string: UIApplication.openSettingsURLString) {
                        Button("Open notification settings") { UIApplication.shared.open(url) }.buttonStyle(SoftButtonStyle(compact: true))
                    } else {
                        Button("Turn on reminders") { Task { await reminders.enable() } }.buttonStyle(PrimaryButtonStyle())
                    }
                    if let error = reminders.error { Text(error).font(.wbCaption).foregroundStyle(Theme.warning) }
                    Text(ReminderService.showsItemNames ? "Reminders show item names. You can hide them in Settings." : "Item names are hidden in reminders. You can show them in Settings.").font(.wbCaption).foregroundStyle(Theme.secondary)
                }
                .foregroundStyle(Theme.ink)
                .card(padding: 16)
    }

    private func decide(_ deadline: Deadline, _ decision: ReturnDecision) {
        do { try store.decide(deadline, decision) } catch { self.error = error.localizedDescription }
    }

    private var upcoming: [Deadline] {
        let today = CalendarDay(.now)
        return store.deadlines.filter { $0.active && ($0.day.map { $0 >= today } ?? false) }
    }

    private var coverageSummary: String {
        switch reminders.permission {
        case "Enabled", "Quiet delivery":
            let count = reminders.scheduled.count
            return count == 1 ? "1 reminder is queued on this iPhone." : "\(count) reminders are queued on this iPhone."
        case "Disabled in Settings": return "Notifications are off for Hereabouts, so reminders can't reach you."
        default: return "Turn on reminders so Hereabouts can tell you before a date passes."
        }
    }

    @ViewBuilder private func calendarMenu(_ deadline: Deadline) -> some View {
        Button("Add to Calendar", systemImage: "calendar.badge.plus") { calendarFor = deadline }
    }

    private func addAllToCalendar() async {
        addingAll = true; defer { addingAll = false }
        do {
            let added = try await CalendarExport.addAll(upcoming)
            notice = added == 1 ? "1 date was added to your default calendar." : "\(added) dates were added to your default calendar."
        } catch { self.error = error.localizedDescription }
    }
}

struct DeadlineRow: View {
    let deadline: Deadline
    var showsItem = true
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if showsItem { Text(deadline.item?.name ?? "Item unavailable").font(.headline) }
            LabeledContent(deadline.kind?.title ?? "Unknown date") { if let date = deadline.day?.date() { Text(date, format: .dateTime.year().month().day()) } }
                .font(.subheadline).foregroundStyle(Theme.secondary)
        }.padding(.vertical, 4)
    }
}

struct DeadlineEditor: View {
    @Environment(LocaliserStore.self) private var store
    @Environment(ProAccess.self) private var pro
    @Environment(\.dismiss) private var dismiss
    let item: Belonging
    let existing: Deadline?
    let scan: ScanDraft?
    let onSaved: (() -> Void)?
    @State private var kind: DeadlineKind
    @State private var date: Date
    @State private var source: String
    @State private var leadDays: Int
    @State private var hour: Int
    @State private var enabled: Bool
    @State private var confirmed = false
    @State private var useWindow = false
    @State private var windowDays = 30
    @State private var anchor = Date()
    @State private var anchorType = "Purchase date"
    @State private var includeAnchor = false
    @State private var reopen = false
    @State private var error: String?
    @State private var retainSource = false
    @State private var saving = false
    @State private var upgrade = false

    init(item: Belonging, existing: Deadline? = nil, suggestedDate: Date? = nil, source: String = "", suggestedKind: DeadlineKind? = nil, scan: ScanDraft? = nil, onSaved: (() -> Void)? = nil) {
        self.item = item; self.existing = existing; self.scan = scan; self.onSaved = onSaved
        let kind = existing?.kind ?? suggestedKind ?? .returns
        _kind = State(initialValue: kind)
        _date = State(initialValue: existing?.day?.date() ?? suggestedDate ?? .now)
        _source = State(initialValue: existing?.source ?? source)
        _leadDays = State(initialValue: existing.map { Int($0.leadDays) } ?? kind.defaultLeadDays)
        _hour = State(initialValue: existing.map { Int($0.hour) } ?? 9)
        _enabled = State(initialValue: existing?.enabled ?? true)
    }

    private var finalDay: CalendarDay? {
        if kind == .returns && useWindow { return CalendarDay(anchor).adding(days: windowDays - (includeAnchor ? 1 : 0)) }
        return CalendarDay(date)
    }
    private var closed: Bool { existing?.kind == .returns && (existing?.decision == .keeping || existing?.decision == .returned) }

    var body: some View {
        Form {
            if let scan {
                Section("Scanned document") {
                    if let preview = scan.preview, let image = UIImage(data: preview) { Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 200) }
                    Text("A receipt date may be a purchase date. Confirm the date type and any missing terms; suggestions are not store policies.").font(.subheadline)
                    Toggle("Keep original document", isOn: $retainSource)
                    Text(retainSource ? "The original may contain identification numbers. It will be stored with this item and included in your device backup and in Hereabouts backups." : "Only the confirmed date and your entered details will be saved. The original and recognized text will be discarded when this review closes.").font(.caption).foregroundStyle(Theme.secondary)
                }
            }
            Section(item.name) {
                Picker("Date type", selection: $kind) { ForEach(DeadlineKind.allCases) { Text($0.title).tag($0) } }.disabled(existing != nil)
                if kind == .returns {
                    Toggle("Calculate from a confirmed return window", isOn: $useWindow)
                    if useWindow {
                        Picker("Window starts from", selection: $anchorType) { Text("Purchase date").tag("Purchase date"); Text("Delivery date").tag("Delivery date") }
                        DatePicker(anchorType, selection: $anchor, displayedComponents: .date)
                        Stepper("Window: \(windowDays) days", value: $windowDays, in: 1...365)
                        Toggle("Count the starting day as day 1", isOn: $includeAnchor)
                        Text("Use the terms for this purchase. Hereabouts doesn't look up the store's policy.").font(.caption).foregroundStyle(Theme.secondary)
                    }
                }
                if !useWindow || kind != .returns { DatePicker("Final date", selection: $date, displayedComponents: .date).accessibilityIdentifier("deadline.date") }
                TextField("Source or terms (optional)", text: $source, axis: .vertical)
            }
            Section("Reminders") {
                Toggle("Remind me", isOn: $enabled)
                if enabled {
                    Stepper("\(leadDays) days before", value: $leadDays, in: 0...3650)
                    Picker("Local time", selection: $hour) { ForEach(0..<24) { Text(String(format: "%02d:00", $0)).tag($0) } }
                    Text("A reminder is also scheduled on the date, if it is still in the future and queue space is available. Enable notifications in Due soon.").font(.caption).foregroundStyle(Theme.secondary)
                }
                if kind == .expiry { Text("The lead time is your preference. It does not establish travel eligibility or insurance coverage.").font(.caption).foregroundStyle(Theme.secondary) }
            }
            Section("Review before saving") {
                if let value = finalDay?.date() { LabeledContent("Confirmed deadline") { Text(value, format: .dateTime.year().month().day()).foregroundStyle(Theme.secondary) } }
                if closed { Toggle("Reopen return decision", isOn: $reopen) }
                if item.archived { Text("This item is archived. Restore it in Find before reminders can be scheduled.").foregroundStyle(Theme.secondary) }
                Toggle("I have checked the date type and final date", isOn: $confirmed).accessibilityIdentifier("deadline.confirm")
            }
        }
        .groundBackground().navigationTitle(existing == nil ? "Add date" : "Edit date").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("Save") { save() }.disabled(saving || !confirmed || finalDay == nil || (closed && !reopen)).accessibilityIdentifier("deadline.save") }
        }
        .onChange(of: kind) { _, new in leadDays = new.defaultLeadDays; useWindow = false; confirmed = false }
        .onChange(of: date) { _, _ in confirmed = false }
        .onChange(of: anchor) { _, _ in confirmed = false }
        .onChange(of: windowDays) { _, _ in confirmed = false }
        .onChange(of: includeAnchor) { _, _ in confirmed = false }
        .onChange(of: useWindow) { _, _ in confirmed = false }
        .onChange(of: anchorType) { _, _ in confirmed = false }
        .sheet(isPresented: $upgrade) { NavigationStack { ProView() } }
        .alert("Could not save date", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") { error = nil } } message: { Text(error ?? "") }
    }

    private func save() {
        guard let day = finalDay, !saving else { return }
        if let scan, !scan.candidates.isEmpty, !pro.allows(.scan, count: store.completedScans) { upgrade = true; return }
        saving = true
        do {
            var evidence = source
            if kind == .returns && useWindow { evidence += "\n\(anchorType): \(CalendarDay(anchor).stored); \(windowDays) days; starting day \(includeAnchor ? "included" : "excluded")." }
            try store.setDeadline(item: item, kind: kind, day: day, source: evidence, leadDays: leadDays, hour: hour, enabled: enabled, confirmed: confirmed, existing: existing, reopen: reopen, scan: scan, retainSource: retainSource)
            dismiss()
            onSaved?()
        } catch { saving = false; self.error = error.localizedDescription }
    }
}

struct DeadlineDetailView: View {
    @Environment(LocaliserStore.self) private var store
    @Environment(ReminderService.self) private var reminders
    @Environment(\.dismiss) private var dismiss
    let deadline: Deadline
    @State private var editing = false
    @State private var calendar = false
    @State private var deleting = false
    @State private var confirmReturned = false
    @State private var error: String?
    var body: some View {
        let _ = store.revision
        List {
            Section {
                DeadlineRow(deadline: deadline, showsItem: false)
                if !deadline.source.isEmpty { Label("From \(deadline.source)", systemImage: "doc.text").font(.subheadline).foregroundStyle(Theme.secondary) }
            }
            Section("Reminders") {
                let requests = reminders.scheduled.filter { $0.deadlineID == deadline.id }.sorted { $0.fireDate < $1.fireDate }
                if let next = requests.first {
                    Label { Text("We'll remind you \(next.fireDate.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).hour().minute())).") } icon: { Image(systemName: "bell").foregroundStyle(Theme.purpleInk) }
                    if requests.count > 1 { Text("\(requests.count - 1) more reminder\(requests.count == 2 ? "" : "s") after that.").font(.wbCaption).foregroundStyle(Theme.secondary) }
                } else if !deadline.active {
                    Text("Reminders stop once a date is completed.").foregroundStyle(Theme.secondary)
                } else if reminders.permission == "Enabled" || reminders.permission == "Quiet delivery" {
                    Text("No reminders left before this date.").foregroundStyle(Theme.secondary)
                } else {
                    Button("Turn on reminders", systemImage: "bell") { Task { await reminders.enable() } }
                }
                Button("Add to Calendar", systemImage: "calendar.badge.plus") { calendar = true }
            }
            if deadline.kind == .returns {
                Section {
                    if deadline.decision == .open || deadline.decision == .returning {
                        if deadline.decision == .returning { Label("You're returning it.", systemImage: "arrow.uturn.backward").foregroundStyle(Theme.ink) }
                        else { Button("I'm returning it") { decide(.returning) }.buttonStyle(PrimaryButtonStyle()).plainRow() }
                        Button("I'm keeping it") { decide(.keeping) }.buttonStyle(SoftButtonStyle()).plainRow()
                        if deadline.decision == .returning { Button("It's been returned") { confirmReturned = true }.buttonStyle(PrimaryButtonStyle()).plainRow() }
                    } else {
                        Label(deadline.decision == .keeping ? "You're keeping it." : "Returned.", systemImage: "checkmark.circle").foregroundStyle(Theme.sageInk)
                        Text("To get return reminders again, edit this date and turn on Reopen return decision.").font(.wbCaption).foregroundStyle(Theme.secondary)
                    }
                } header: { Text("Keep or return?").foregroundStyle(Theme.secondary) }
            }
            if let item = deadline.item { Section { NavigationLink("Open \(item.name)") { ItemDetailView(item: item) } } }
            Section { Button("Delete date", role: .destructive) { deleting = true } }
        }
        .groundBackground().navigationTitle(deadline.item?.name ?? deadline.kind?.title ?? "Date").navigationBarTitleDisplayMode(.inline)
        .toolbar { if deadline.item != nil { Button("Edit") { editing = true } } }
        .sheet(isPresented: $editing) { if let item = deadline.item { NavigationStack { DeadlineEditor(item: item, existing: deadline) } } }
        .sheet(isPresented: $calendar) { CalendarEventEditor(deadline: deadline) }
        .confirmationDialog("Mark it as returned?", isPresented: $confirmReturned, titleVisibility: .visible) { Button("It's been returned") { decide(.returned) } } message: { Text("The item moves to your archive and its reminders stop. Its history is kept.") }
        .confirmationDialog("Delete this date and its reminders?", isPresented: $deleting, titleVisibility: .visible) { Button("Delete date", role: .destructive) {
            do { try store.deleteDeadline(deadline); dismiss() } catch { self.error = error.localizedDescription }
        } }
        .alert("Could not update date", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") { error = nil } } message: { Text(error ?? "") }
    }
    private func decide(_ decision: ReturnDecision) { do { try store.decide(deadline, decision) } catch { self.error = error.localizedDescription } }
}

struct CalendarEventEditor: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    let deadline: Deadline
    func makeCoordinator() -> Coordinator { Coordinator(dismiss: { dismiss() }) }
    func makeUIViewController(context: Context) -> EKEventEditViewController {
        let controller = EKEventEditViewController()
        let eventStore = EKEventStore()
        let event: EKEvent
        if let plan = CalendarExport.plan(for: deadline) { event = CalendarExport.makeEvent(plan, in: eventStore) }
        else { event = EKEvent(eventStore: eventStore); event.title = (deadline.kind ?? .returns).calendarTitle(itemName: deadline.item?.name) }
        controller.eventStore = eventStore; controller.event = event; controller.editViewDelegate = context.coordinator
        return controller
    }
    func updateUIViewController(_ uiViewController: EKEventEditViewController, context: Context) {}
    final class Coordinator: NSObject, EKEventEditViewDelegate {
        let dismiss: () -> Void
        init(dismiss: @escaping () -> Void) { self.dismiss = dismiss }
        func eventEditViewController(_ controller: EKEventEditViewController, didCompleteWith action: EKEventEditViewAction) { dismiss() }
    }
}
