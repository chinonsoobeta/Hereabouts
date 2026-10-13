import SwiftUI
import UniformTypeIdentifiers

/// "Save to Hereabouts" from the share sheet (B3): a shared order email, PDF or photo becomes a date
/// on a thing. The extension that hosts this needs the App Group, so for now only tests reach it.
enum ShareImport {
    /// Share extensions get far less memory than the app.
    static let maximumPages = 5

    enum Shared: Sendable {
        case text(String)
        case file(Data, filename: String, mime: String)
    }

    struct Reading: Sendable {
        let found: [OrderEmail.Found]
        /// The document, for the free scan count and for keeping it if asked. Nil for plain text.
        let scan: ScanDraft?
    }

    static func read(_ shared: Shared) throws -> Reading {
        switch shared {
        case .text(let text):
            return Reading(found: OrderEmail.read(text), scan: nil)
        case .file(let data, let filename, let mime):
            let draft = try ScanReader.read(data: data, filename: filename, mime: mime, maximumPages: maximumPages)
            return Reading(found: OrderEmail.read(draft.text), scan: draft)
        }
    }

    /// What a found date most likely is: a return-by line is a return date; otherwise the line's own word.
    static func kind(for found: OrderEmail.Found) -> DeadlineKind {
        found.role == .returnBy ? .returns : found.candidate.hint ?? .returns
    }
}

@MainActor extension LocaliserStore {
    /// Saves a shared date onto an existing thing, or onto a new one with `newName`.
    @discardableResult func saveShared(_ found: OrderEmail.Found, kind: DeadlineKind, to item: Belonging?, newName: String, scan: ScanDraft?) throws -> Deadline {
        let target = try item ?? addItem(name: newName)
        return try setDeadline(item: target, kind: kind, day: found.candidate.day, source: "Shared: \(found.candidate.line.trimmingCharacters(in: .whitespaces))", leadDays: kind.defaultLeadDays, hour: 9, enabled: true, confirmed: true, scan: scan)
    }
}

/// Which date, and which thing. Return-by dates come first.
struct ShareSaveView: View {
    @Environment(LocaliserStore.self) private var store
    @Environment(ProAccess.self) private var pro
    let reading: ShareImport.Reading
    var onDone: () -> Void
    @State private var chosenID: String?
    @State private var kind: DeadlineKind = .returns
    @State private var itemID: UUID?
    @State private var newName = ""
    @State private var error: String?

    private var chosen: OrderEmail.Found? { reading.found.first { $0.id == chosenID } }
    private var item: Belonging? { store.items.first { $0.id == itemID } }
    private var limitReached: String? {
        if item == nil, !pro.allows(.item, count: store.activeItemCount) { return "The free notebook is full. Open Hereabouts to get Pro, or archive something first." }
        if let scan = reading.scan, !scan.candidates.isEmpty, !pro.allows(.scan, count: store.completedScans) { return "That's this month's free scans. Open Hereabouts to get Pro." }
        return nil
    }

    var body: some View {
        SheetForm {
            Section {
                if reading.found.isEmpty {
                    Text("No dates in that. Open the thing in Hereabouts and add the date by hand.").foregroundStyle(Theme.secondary).accessibilityIdentifier("share.none")
                }
                ForEach(reading.found) { found in
                    Button { chosenID = found.id; kind = ShareImport.kind(for: found) } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(found.candidate.day.date()?.formatted(date: .long, time: .omitted) ?? found.candidate.raw).font(.wbItem).foregroundStyle(Theme.ink)
                                Text(found.candidate.line.trimmingCharacters(in: .whitespaces)).font(.wbCaption).foregroundStyle(Theme.pencil).lineLimit(2)
                            }
                            Spacer(minLength: 8)
                            if chosenID == found.id { Image(systemName: "checkmark").foregroundStyle(Theme.purpleInk).accessibilityHidden(true) }
                        }.contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).accessibilityAddTraits(chosenID == found.id ? .isSelected : [])
                }
            } header: { Text("Which date?").font(.wbLabel).foregroundStyle(Theme.ink).textCase(nil) }
            if chosen != nil {
                Section {
                    Picker("Kind", selection: $kind) { ForEach([DeadlineKind.returns, .warranty, .expiry], id: \.self) { Text($0.title).tag($0) } }
                    Picker("Thing", selection: $itemID) {
                        Text("Something new").tag(nil as UUID?)
                        ForEach(store.items.filter { !$0.archived }) { Text($0.name).tag(Optional($0.id)) }
                    }
                    if itemID == nil { TextField("Name, like Blue kettle", text: $newName).accessibilityIdentifier("share.name") }
                } header: { Text("Which thing is it for?").font(.wbLabel).foregroundStyle(Theme.ink).textCase(nil) }
                  footer: { if let limitReached { Text(limitReached).foregroundStyle(Theme.warning) } }
            }
        }
        .groundBackground()
        .navigationTitle("Save to Hereabouts").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { onDone() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }.fontWeight(.semibold).accessibilityIdentifier("share.save")
                    .disabled(chosen == nil || limitReached != nil || (itemID == nil && newName.trimmingCharacters(in: .whitespaces).isEmpty))
            }
        }
        .onAppear { if chosenID == nil, let first = reading.found.first { chosenID = first.id; kind = ShareImport.kind(for: first) } }
        .alert("That didn't save", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") { error = nil } } message: { Text(error ?? "") }
    }

    private func save() {
        guard let chosen else { return }
        do { try store.saveShared(chosen, kind: kind, to: item, newName: newName, scan: reading.scan); onDone() }
        catch { self.error = error.localizedDescription }
    }
}
