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
    @AppStorage(Home.nameKey) private var homeName = ""
    @AppStorage(Rituals.recapKey) private var recapOn = true
    @AppStorage(Rituals.stocktakeKey) private var stocktakeOn = true

    var body: some View {
        List {
            Section {
                NavigationLink { ProView(showsClose: false) } label: {
                    NotebookLine(name: "Hereabouts Pro", detail: pro.unlocked ? "Unlocked. Thank you." : "Free plan · \(store.activeItemCount) of \(CreationKind.item.freeLimit) things")
                }.accessibilityLabel("Purchase or restore lifetime Pro")
            }
            Section {
                TextField(Home.defaultName, text: $homeName).font(.wbItem).accessibilityLabel("Name of your home")
            } header: { Text("Home") }
            Section {
                Toggle("Show item names in reminders", isOn: $showItemNames)
                    .onChange(of: showItemNames) { _, _ in reminders.refresh(store.deadlines); reminders.refreshRituals(store) }
                Toggle("Sunday recap", isOn: $recapOn)
                    .onChange(of: recapOn) { _, _ in reminders.refreshRituals(store) }
                Toggle("Monthly stocktake", isOn: $stocktakeOn)
                    .onChange(of: stocktakeOn) { _, _ in reminders.refreshRituals(store) }
            } header: { Text("Reminders") }
              footer: { Text(showItemNames ? "Anyone who sees your lock screen can read the thing's name." : "Reminders say “A saved item” instead of the name.").font(.wbCaption).foregroundStyle(Theme.pencil) }
            Section {
                NavigationLink("Take your notebook with you.") { LeavingView() }.accessibilityIdentifier("settings.leaving")
            } header: { Text("Leaving") }
            Section {
                Label("Your library stays on this iPhone. There is no account, no advertising and no analytics.", systemImage: "lock.shield")
                Label("Receipts are read on the device. The text is thrown away once you confirm a date, unless you choose to keep the original.", systemImage: "doc.text.viewfinder")
            } header: { Text("Privacy & Support") }
            Section {
                Button("Show the introduction again", systemImage: "play.rectangle") { dismiss(); seenOnboarding = false }
                Link(destination: Support.mail(subject: "Hereabouts feedback")) { Label("Send feedback", systemImage: "envelope") }
                Link(destination: Support.supportPage) { Label("Help and support", systemImage: "questionmark.circle") }
                Link(destination: Support.privacy) { Label("Privacy policy", systemImage: "hand.raised") }
                Link(destination: Support.terms) { Label("Terms of use", systemImage: "doc.plaintext") }
            } header: { Text("Help") }
            Section {} footer: { Text("Hereabouts \(Support.version)").font(.wbCaption).foregroundStyle(Theme.pencil) }
        }
        .listStyle(.plain)
        .font(.wbBody).tint(Theme.purpleInk).groundBackground().navigationTitle("Settings").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.fontWeight(.semibold) } }
    }
}

struct LeavingView: View {
    @Environment(LocaliserStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var selectedFiles = Set<UUID>()
    @State private var document: LibraryExportDocument?
    @State private var exportType = UTType.json
    @State private var exporting = false
    @State private var importing = false
    @State private var pendingRestore: LibraryBackup?
    @State private var confirmingRestore = false
    @State private var confirmErase = false
    @State private var erasing = false
    @State private var erasePhrase = ""
    @State private var error: String?
    @State private var notice: String?

    private var libraryIsEmpty: Bool { store.items.isEmpty && store.places.isEmpty && store.deadlines.isEmpty && store.kits.isEmpty && store.trips.isEmpty }
    private var retainedFileCount: Int { store.items.filter { $0.photo != nil }.count + store.items.flatMap(\.scans).filter { $0.data != nil }.count }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Take your notebook with you.").font(.wbDisplay).foregroundStyle(Theme.ink).accessibilityAddTraits(.isHeader)
                Text("Nothing leaves this phone unless you carry it out. Every page is yours to keep, in a form you can open anywhere.").font(.wbBody).foregroundStyle(Theme.ink)
                SectionHeading(title: "Keep a copy")
                VStack(spacing: 0) {
                    Button { prepareBackup() } label: {
                        optionLabel("Back up everything", "Places, things, dates, trips and the photos you choose. Restores into a fresh Hereabouts.", "arrow.down.doc")
                    }.accessibilityLabel("Back up everything")
                    Button { prepareCSV() } label: {
                        optionLabel("Export a spreadsheet", "A plain list of things and places. Opens in Numbers, Excel or anything else.", "tablecells")
                    }.accessibilityLabel("Export a spreadsheet")
                    NavigationLink { BackupFilesView(selectedFiles: $selectedFiles) } label: {
                        optionLabel("Photos and documents to include", selectedFiles.isEmpty ? "None selected" : "\(selectedFiles.count) of \(retainedFileCount) selected", "photo.on.rectangle")
                    }.accessibilityLabel("Photos and documents to include")
                    Button { importing = true } label: {
                        optionLabel("Restore from a backup", "Bring your notebook home from a saved copy.", "arrow.counterclockwise")
                    }.accessibilityLabel("Restore from a backup")
                    Button {
                        Task {
                            do { let count = try await CalendarExport.addAll(store.deadlines.filter(\.active)); notice = "\(count) dates added to Calendar." }
                            catch { self.error = error.localizedDescription }
                        }
                    } label: {
                        optionLabel("Put dates in your calendar", "Returns, warranties and expiry dates keep reminding you after the app is gone.", "calendar")
                    }.accessibilityLabel("Put dates in your calendar")
                }.buttonStyle(.plain)
                Text("A backup holds your places, things, history, dates, kits and trips. Photos and documents are included only if you choose them. Backups are not encrypted, so anyone with the file can read it. Save it somewhere private, like iCloud Drive or Files on this iPhone.")
                    .font(.wbCaption).foregroundStyle(Theme.pencil).fixedSize(horizontal: false, vertical: true)
                SectionHeading(title: "Then, if you like")
                Button(role: .destructive) { confirmErase = true } label: {
                    optionLabel("Erase this notebook", "Wipes everything on this phone. We'll ask twice. Your backups stay wherever you put them.", "trash")
                }.buttonStyle(.plain).foregroundStyle(Theme.amber).accessibilityLabel("Erase this notebook")
                if let notice { Label(notice, systemImage: "checkmark.circle").font(.wbBody).foregroundStyle(Theme.green) }
                StickyNote {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("“If you ever come back, a backup brings everything home.”").font(.wbQuote)
                        Text("No account was made, so there's nothing to close. Thanks for keeping a notebook.").font(.wbCaption)
                    }.foregroundStyle(Theme.ink)
                }
                Button("I'll stay a while") { dismiss() }.buttonStyle(SoftButtonStyle())
            }.padding(20)
        }
        .background(Theme.paper).navigationTitle("Leaving").navigationBarTitleDisplayMode(.inline)
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
        .confirmationDialog("Erase this notebook?", isPresented: $confirmErase, titleVisibility: .visible) {
            Button("Continue to erase", role: .destructive) { erasePhrase = ""; erasing = true }
        } message: { Text("Wipes everything on this phone. We'll ask twice. Your backups stay wherever you put them.") }
        .alert("Erase this notebook?", isPresented: $erasing) {
            TextField("Type ERASE", text: $erasePhrase).textInputAutocapitalization(.characters)
            Button("Cancel", role: .cancel) { erasePhrase = "" }
            Button("Erase", role: .destructive) {
                do { try store.resetLibrary(); Spotlight.clear(); selectedFiles = []; notice = "Library erased." } catch { self.error = error.localizedDescription }
            }.disabled(erasePhrase != "ERASE")
        } message: { Text("This can't be undone without a backup. Type ERASE to confirm.") }
        .alert("Couldn't finish that", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") { error = nil } } message: { Text(error ?? "") }
    }

    private func optionLabel(_ title: String, _ detail: String, _ symbol: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol).font(.system(size: 20)).frame(width: 26).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.wbBody.weight(.bold)).foregroundStyle(Theme.ink)
                Text(detail).font(.wbCaption).foregroundStyle(Theme.pencil)
            }.fixedSize(horizontal: false, vertical: true)
        }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).card(padding: 12).contentShape(Rectangle())
    }

    private func restore(replacing: Bool) {
        defer { pendingRestore = nil }
        do {
            if let pendingRestore { try store.restore(pendingRestore, replacingExisting: replacing); notice = "Backup restored. Check reminders are on in Due." }
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
