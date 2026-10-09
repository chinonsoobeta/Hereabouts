import SwiftUI
import UniformTypeIdentifiers

struct LibraryExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json, .commaSeparatedText] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        guard let contents = configuration.file.regularFileContents else { throw CocoaError(.fileReadCorruptFile) }
        data = contents
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

struct LibrarySettingsView: View {
    @Environment(LocaliserStore.self) private var store
    @Environment(ProAccess.self) private var pro
    @Environment(ReminderService.self) private var reminders
    @Environment(\.dismiss) private var dismiss
    @AppStorage(ReminderService.showNamesKey) private var showItemNames = true
    @AppStorage(OnboardingView.seenKey) private var seenOnboarding = true
    @State private var selectedFiles = Set<UUID>()
    @State private var document: LibraryExportDocument?
    @State private var exportType = UTType.json
    @State private var exporting = false
    @State private var importing = false
    @State private var pendingRestore: LibraryBackup?
    @State private var confirmingRestore = false
    @State private var erasing = false
    @State private var erasePhrase = ""
    @State private var error: String?
    @State private var notice: String?

    private var libraryIsEmpty: Bool { store.items.isEmpty && store.places.isEmpty && store.deadlines.isEmpty && store.kits.isEmpty && store.trips.isEmpty }
    private var retainedFileCount: Int { store.items.filter { $0.photo != nil }.count + store.items.flatMap(\.scans).filter { $0.data != nil }.count }

    var body: some View {
        Form {
            Section {
                NavigationLink { ProView(showsClose: false) } label: {
                    HStack(spacing: 12) {
                        IconTile(systemImage: "sparkles", size: 40)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Hereabouts Pro").font(.wbItem).foregroundStyle(Theme.ink)
                            Text(pro.unlocked ? "Unlocked. Thank you." : "Free plan · \(store.activeItemCount) of \(CreationKind.item.freeLimit) items").font(.wbCaption).foregroundStyle(Theme.secondary)
                        }
                    }
                }
                .accessibilityLabel("Purchase or restore lifetime Pro")
            }
            Section {
                Toggle("Show item names in reminders", isOn: $showItemNames)
                    .onChange(of: showItemNames) { _, _ in reminders.refresh(store.deadlines) }
            } header: { Text("Reminders").foregroundStyle(Theme.secondary) }
              footer: { Text(showItemNames ? "Reminders say which item is due, for example \u{201C}Headphones: last day to return is tomorrow.\u{201D} Anyone who sees your lock screen can read them." : "Reminders say \u{201C}A saved item\u{201D} instead of the name.").foregroundStyle(Theme.secondary) }
            Section {
                Button("Export restorable backup", systemImage: "arrow.down.doc") { prepareBackup() }
                Button("Export inventory CSV", systemImage: "tablecells") { prepareCSV() }
                NavigationLink {
                    BackupFilesView(selectedFiles: $selectedFiles)
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Photos and documents to include")
                            Text(selectedFiles.isEmpty ? "None selected" : "\(selectedFiles.count) of \(retainedFileCount) selected").font(.wbCaption).foregroundStyle(Theme.ink)
                        }
                    } icon: { Image(systemName: "photo.on.rectangle") }
                }
                Button("Restore from a backup", systemImage: "arrow.counterclockwise") { importing = true }
            } header: { Text("Backup").foregroundStyle(Theme.secondary) }
              footer: { Text("A backup holds your places, items, history, dates, kits and trips. Photos and documents are included only if you choose them. Backups are not encrypted, so anyone with the file can read it. Save it somewhere private, like iCloud Drive or Files on this iPhone.").font(.wbCaption).foregroundStyle(Theme.secondary).fixedSize(horizontal: false, vertical: true) }
            Section {
                Label("Your library stays on this iPhone. There is no account, no advertising and no analytics.", systemImage: "lock.shield")
                Label("Receipts are read on the device. The text is thrown away once you confirm a date, unless you choose to keep the original.", systemImage: "doc.text.viewfinder")
            } header: { Text("Privacy").foregroundStyle(Theme.secondary) }
            .font(.wbBody)
            Section {
                Button("Show the introduction again", systemImage: "play.rectangle") { dismiss(); seenOnboarding = false }
                Link(destination: Support.mail(subject: "Hereabouts feedback")) { Label("Send feedback", systemImage: "envelope") }
                Link(destination: Support.supportPage) { Label("Help and support", systemImage: "questionmark.circle") }
                Link(destination: Support.privacy) { Label("Privacy policy", systemImage: "hand.raised") }
                Link(destination: Support.terms) { Label("Terms of use", systemImage: "doc.plaintext") }
            } header: { Text("Help").foregroundStyle(Theme.secondary) }
            Section {
                Button("Erase all local records…", systemImage: "trash", role: .destructive) { erasePhrase = ""; erasing = true }
                    .foregroundStyle(Theme.warning)
            } footer: { Text("Export a backup first. Erasing removes every item, place, date, kit and trip from this iPhone.").foregroundStyle(Theme.secondary) }
            if let notice { Section { Label(notice, systemImage: "checkmark.circle").foregroundStyle(Theme.sageInk) } }
            Section {} footer: {
                Text("Hereabouts \(Support.version)").font(.wbCaption).foregroundStyle(Theme.secondary).frame(maxWidth: .infinity)
            }
        }
        .tint(Theme.purpleInk)
        .groundBackground().navigationTitle("Settings").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.fontWeight(.semibold) } }
        .fileExporter(isPresented: $exporting, document: document, contentType: exportType, defaultFilename: exportType == .json ? "Hereabouts backup \(Date.now.formatted(.iso8601.year().month().day()))" : "Hereabouts inventory") { result in
            switch result { case .success: notice = "Export saved."; case .failure(let failure): error = failure.localizedDescription }
            document = nil
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            do {
                let url = try result.get()
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                guard size <= LibraryBackup.maximumBytes else { throw LocaliserError.invalidBackup("Choose a backup under 200 MB.") }
                let file = try LibraryBackup.decoded(Data(contentsOf: url))
                try store.validateBackup(file)
                pendingRestore = file; confirmingRestore = true
            } catch { self.error = error.localizedDescription }
        }
        .alert("Restore backup?", isPresented: $confirmingRestore) {
            Button("Cancel", role: .cancel) { pendingRestore = nil }
            if libraryIsEmpty {
                Button("Restore") { restore(replacing: false) }
            } else {
                Button("Erase and restore", role: .destructive) { restore(replacing: true) }
            }
        } message: {
            let count = pendingRestore?.records.count ?? 0
            let summary = "\(count == 1 ? "1 record" : "\(count) records") saved \(pendingRestore?.createdAt.formatted(date: .abbreviated, time: .shortened) ?? "on an unknown date")."
            Text(libraryIsEmpty ? summary : summary + " Your current library will be replaced. If anything goes wrong, it is kept exactly as it is.")
        }
        .alert("Erase all local records?", isPresented: $erasing) {
            TextField("Type ERASE", text: $erasePhrase).textInputAutocapitalization(.characters)
            Button("Cancel", role: .cancel) { erasePhrase = "" }
            Button("Erase", role: .destructive) {
                do { try store.resetLibrary(); Spotlight.clear(); selectedFiles = []; notice = "Library erased." } catch { self.error = error.localizedDescription }
            }.disabled(erasePhrase != "ERASE")
        } message: { Text("This can't be undone without a backup. Type ERASE to confirm.") }
        .alert("Couldn't finish that", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") { error = nil } } message: { Text(error ?? "") }
    }

    private func restore(replacing: Bool) {
        defer { pendingRestore = nil }
        do {
            if let pendingRestore { try store.restore(pendingRestore, replacingExisting: replacing); notice = "Backup restored. Check reminders are on in Due soon." }
        } catch { self.error = error.localizedDescription }
    }
    private func prepareCSV() {
        exportType = .commaSeparatedText; document = LibraryExportDocument(data: Data(store.inventoryCSV().utf8)); exporting = true
    }
    private func prepareBackup() {
        do { exportType = .json; document = LibraryExportDocument(data: try store.backup(attachmentIDs: selectedFiles).encoded()); exporting = true }
        catch { self.error = error.localizedDescription }
    }
}

/// Chooses which photos and kept documents go into the next backup.
struct BackupFilesView: View {
    @Environment(LocaliserStore.self) private var store
    @Binding var selectedFiles: Set<UUID>
    private var photos: [Belonging] { store.items.filter { $0.photo != nil } }
    private var documents: [ScanRecord] { store.items.flatMap { Array($0.scans) }.filter { $0.data != nil }.sorted { $0.createdAt < $1.createdAt } }
    var body: some View {
        Form {
            if photos.isEmpty && documents.isEmpty {
                Text("No photos or kept documents yet.").foregroundStyle(Theme.secondary)
            } else {
                Section {
                    Button(selectedFiles.isEmpty ? "Include all" : "Include none") {
                        selectedFiles = selectedFiles.isEmpty ? Set(photos.map(\.id) + documents.map(\.id)) : []
                    }
                } footer: { Text("Files make a backup larger. A backup can be up to 200 MB.").foregroundStyle(Theme.secondary) }
                if !photos.isEmpty {
                    Section { ForEach(photos) { toggle($0.id, title: $0.name) } } header: { Text("Item photos").foregroundStyle(Theme.secondary) }
                }
                if !documents.isEmpty {
                    Section { ForEach(documents) { toggle($0.id, title: "\($0.item?.name ?? "Document") · \($0.filename)") } } header: { Text("Kept documents").foregroundStyle(Theme.secondary) }
                }
            }
        }
        .tint(Theme.purple)
        .groundBackground().navigationTitle("Files to include").navigationBarTitleDisplayMode(.inline)
    }
    private func toggle(_ id: UUID, title: String) -> some View {
        Toggle(title, isOn: Binding(get: { selectedFiles.contains(id) }, set: { if $0 { selectedFiles.insert(id) } else { selectedFiles.remove(id) } }))
    }
}

/// Gear button that opens Settings from any tab.
private struct SettingsButton: ViewModifier {
    @State private var open = false
    func body(content: Content) -> some View {
        content
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Settings", systemImage: "gear") { open = true } } }
            .sheet(isPresented: $open) { NavigationStack { LibrarySettingsView() } }
    }
}

extension View {
    func settingsButton() -> some View { modifier(SettingsButton()) }
}
