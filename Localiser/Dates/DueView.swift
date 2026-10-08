import SwiftUI
import EventKit
import EventKitUI

struct DueView: View {
    @Environment(LocaliserStore.self) private var store
    @Environment(ReminderService.self) private var reminders
    @State private var addDate = false
    @State private var showClosed = false
    private let sections = ["Decide soon", "Returning", "Warranties ending", "Expiring", "Missed"]

    private func section(_ deadline: Deadline) -> String {
        if let day = deadline.day, day < CalendarDay(.now) { return "Missed" }
        if deadline.kind == .warranty { return "Warranties ending" }
        if deadline.kind == .expiry { return "Expiring" }
        return deadline.decision == .returning ? "Returning" : "Decide soon"
    }

    var body: some View {
        let _ = store.revision
        List {
            Section("Reminder coverage") {
                LabeledContent("Notifications") { Text(reminders.permission).foregroundStyle(Theme.secondary) }
                Text("\(reminders.scheduled.count) of \(reminders.candidateCount) upcoming reminder requests scheduled.").font(.subheadline)
                if reminders.candidateCount > reminders.scheduled.count { Text("Some reminders are not scheduled. Review the dates below or add them to Calendar. Open Localiser regularly to refresh the queue.").foregroundStyle(Theme.secondary) }
                if let error = reminders.error { Text(error).foregroundStyle(.red) }
                Button("Enable notifications") { Task { await reminders.enable() } }
                if reminders.permission == "Disabled in Settings", let url = URL(string: UIApplication.openSettingsURLString) { Link("Open notification settings", destination: url) }
                Text("Scheduling depends on permission and device settings. Document names and numbers are hidden in notification text.").font(.caption).foregroundStyle(Theme.secondary)
            }
            if !store.deadlines.contains(where: \.active) { LibraryEmptyState(title: "Remember in time", systemImage: "calendar.badge.clock", description: "Add a confirmed return deadline, warranty end, or document expiry to an item.") }
            ForEach(sections, id: \.self) { heading in
                let dates = store.deadlines.filter { $0.active && section($0) == heading }
                if !dates.isEmpty {
                    Section(heading) { ForEach(dates) { deadline in NavigationLink { DeadlineDetailView(deadline: deadline) } label: { DeadlineRow(deadline: deadline) } } }
                }
            }
            if showClosed {
                Section("Closed / archived") {
                    ForEach(store.deadlines.filter { !$0.active }) { deadline in NavigationLink { DeadlineDetailView(deadline: deadline) } label: { DeadlineRow(deadline: deadline) } }
                }
            }
        }
        .scrollContentBackground(.hidden).background(Theme.ground).navigationTitle("Due soon")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { Button { showClosed.toggle() } label: { Image(systemName: showClosed ? "eye.slash" : "eye") }.accessibilityLabel(showClosed ? "Hide closed" : "Show closed") }
            ToolbarItem(placement: .topBarTrailing) { Button("Add date", systemImage: "plus") { addDate = true } }
        }
        .sheet(isPresented: $addDate) { NavigationStack {
            List {
                if store.items.filter({ !$0.archived }).isEmpty { Text("Add a belonging in Find first.") }
                ForEach(store.items.filter { !$0.archived }) { item in NavigationLink { DeadlineEditor(item: item) } label: { ItemRow(item: item) } }
            }.navigationTitle("Choose an item").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { addDate = false } } }
        } }
    }
}

struct DeadlineRow: View {
    let deadline: Deadline
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(deadline.item?.name ?? "Item unavailable").font(.headline)
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
                    Text(retainSource ? "The original may contain identification numbers. It will be stored with this item and included in device backup and any configured private sync." : "Only the confirmed date and your entered details will be saved. The original and recognized text will be discarded when this review closes.").font(.caption).foregroundStyle(Theme.secondary)
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
                        Text("Use the terms for this purchase. Localiser does not look up the store's policy.").font(.caption).foregroundStyle(Theme.secondary)
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
        .navigationTitle(existing == nil ? "Add date" : "Edit date").navigationBarTitleDisplayMode(.inline)
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
            Section { DeadlineRow(deadline: deadline); if !deadline.source.isEmpty { Text(deadline.source).font(.subheadline) } }
            Section("Scheduled reminders") {
                let requests = reminders.scheduled.filter { $0.deadlineID == deadline.id }
                if requests.isEmpty { Text("No future notification is currently scheduled for this date.").foregroundStyle(Theme.secondary) }
                ForEach(requests, id: \.id) { request in Text(request.fireDate, format: .dateTime.year().month().day().hour().minute()) }
                Button("Add to Calendar") { calendar = true }
            }
            if deadline.kind == .returns {
                Section("Return decision") {
                    Text(deadline.decisionRaw.capitalized)
                    if deadline.decision == .open || deadline.decision == .returning {
                        Button("Keep purchase") { decide(.keeping) }
                        Button("Plan to return") { decide(.returning) }
                        Button("Mark returned") { confirmReturned = true }
                    } else { Text("Edit this date and explicitly reopen the decision to resume return reminders.").foregroundStyle(Theme.secondary) }
                }
            }
            if let item = deadline.item { Section { NavigationLink("View belonging") { ItemDetailView(item: item) } } }
            Section { Button("Delete date", role: .destructive) { deleting = true } }
        }
        .navigationTitle(deadline.kind?.title ?? "Date").navigationBarTitleDisplayMode(.inline)
        .toolbar { if deadline.item != nil { Button("Edit") { editing = true } } }
        .sheet(isPresented: $editing) { if let item = deadline.item { NavigationStack { DeadlineEditor(item: item, existing: deadline) } } }
        .sheet(isPresented: $calendar) { CalendarEventEditor(deadline: deadline) }
        .confirmationDialog("Mark returned? This archives the item and cancels all of its active reminders. Its history will be kept.", isPresented: $confirmReturned, titleVisibility: .visible) { Button("Mark returned") { decide(.returned) } }
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
        let event = EKEvent(eventStore: eventStore)
        event.title = "Localiser: \(deadline.kind?.title ?? "Saved date")"
        event.isAllDay = true
        event.startDate = deadline.day?.date(hour: 0) ?? .now
        event.endDate = Calendar.current.date(byAdding: .day, value: 1, to: event.startDate)
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
