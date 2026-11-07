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
    @AppStorage(ReminderService.showNamesKey) private var showItemNames = true
    @AppStorage(OnboardingView.seenKey) private var seenOnboarding = true
    @AppStorage(Rituals.recapKey) private var recapOn = true
    @AppStorage(Rituals.stocktakeKey) private var stocktakeOn = true
    @AppStorage(AutomaticBackups.enabledKey) private var automaticBackups = true
    @AppStorage(AutomaticBackups.lastKey) private var lastBackupTime = 0.0

    private var coverageSummary: String {
        switch reminders.permission {
        case "Enabled", "Quiet delivery":
            let count = reminders.scheduled.count
            return count == 1 ? "1 reminder is queued on this iPhone." : "\(count) reminders are queued on this iPhone."
        case "Disabled in Settings": return "Notifications are off for Hereabouts, so reminders can't reach you."
        default: return "Turn on reminders so Hereabouts can tell you before a date passes."
        }
    }

    var body: some View {
        SheetList {
            Section {
                NavigationLink { ProView(showsClose: false).toolbarVisibility(.hidden, for: .tabBar) } label: {
                    NotebookLine(name: "Hereabouts Pro", detail: pro.standing?.summary ?? "Free plan · \(store.activeItemCount) of \(CreationKind.item.freeLimit) things")
                }.accessibilityLabel("Hereabouts Pro").accessibilityValue(pro.standing?.summary ?? "Free plan, \(store.activeItemCount) of \(CreationKind.item.freeLimit) things")
            }
            Section {
                NavigationLink { HomesView().toolbarVisibility(.hidden, for: .tabBar) } label: {
                    NotebookLine(name: store.currentHome?.name ?? Home.defaultName, detail: store.hasSeveralHomes ? "\(store.homes.count) homes" : "Rename, or add another home")
                }.accessibilityIdentifier("settings.homes")
            } header: { Text("Home") }
            Section {
                Label { Text(coverageSummary).fixedSize(horizontal: false, vertical: true) } icon: {
                    Image(systemName: reminders.coverageGap ? "bell.badge" : "bell").foregroundStyle(reminders.coverageGap ? Theme.warning : Theme.purpleInk)
                }
                if reminders.permission == "Enabled" || reminders.permission == "Quiet delivery" {
                    if reminders.coverageGap { Text("Some reminders aren't queued yet because iPhone allows a limited number at once. Opening Hereabouts tops up the queue.").font(.wbCaption).foregroundStyle(Theme.pencil).fixedSize(horizontal: false, vertical: true) }
                } else if reminders.permission == "Disabled in Settings", let url = URL(string: UIApplication.openSettingsURLString) {
                    Button("Open notification settings", systemImage: "bell.slash") { UIApplication.shared.open(url) }
                } else {
                    Button("Turn on reminders", systemImage: "bell.badge") { Task { await reminders.enable() } }
                }
                if let error = reminders.error { Text(error).font(.wbCaption).foregroundStyle(Theme.warning) }
                Toggle("Show names in reminders", isOn: $showItemNames)
                    .onChange(of: showItemNames) { _, _ in reminders.refresh(store.deadlines); reminders.refreshRituals(store) }
                Toggle("Sunday recap", isOn: $recapOn)
                    .onChange(of: recapOn) { _, _ in reminders.refreshRituals(store) }
                Toggle("Monthly stocktake", isOn: $stocktakeOn)
                    .onChange(of: stocktakeOn) { _, _ in reminders.refreshRituals(store) }
            } header: { Text("Reminders") }
              footer: { Text(showItemNames ? "Anyone who sees your lock screen can read the thing's name." : "Reminders say “A saved thing” instead of the name.").font(.wbCaption).foregroundStyle(Theme.pencil) }
            Section {
                if pro.unlocked {
                    Toggle("Automatic backups", isOn: $automaticBackups)
                    Text(lastBackupTime > 0 ? "Last one \(Date(timeIntervalSince1970: lastBackupTime).formatted(.relative(presentation: .named)))" : "The first one is made soon after you open the app.")
                        .font(.wbCaption).foregroundStyle(Theme.pencil)
                } else {
                    NavigationLink { ProView(showsClose: false).toolbarVisibility(.hidden, for: .tabBar) } label: {
                        NotebookLine(name: "Automatic backups", detail: "Pro saves a copy of your notebook every week.")
                    }
                }
            } header: { Text("Backups") }
              footer: { if pro.unlocked { Text("Saved to iCloud Drive, or to this iPhone if iCloud Drive is off. The newest five are kept.").font(.wbCaption).foregroundStyle(Theme.pencil) } }
            Section {
                NavigationLink("Take your notebook with you.") { LeavingView().toolbarVisibility(.hidden, for: .tabBar) }.accessibilityIdentifier("settings.leaving")
            } header: { Text("Leaving") }
            Section {
                Label("Your notebook stays on this iPhone. There is no account, no advertising and no analytics.", systemImage: "lock.shield")
            } header: { Text("Privacy") }
            Section {
                Button("Show the introduction again", systemImage: "play.rectangle") { seenOnboarding = false }
                Link(destination: Support.mail(subject: "Hereabouts feedback")) { Label("Send feedback", systemImage: "envelope") }
                Link(destination: Support.supportPage) { Label("Help and support", systemImage: "questionmark.circle") }
                Link(destination: Support.privacy) { Label("Privacy policy", systemImage: "hand.raised") }
                Link(destination: Support.terms) { Label("Terms of use", systemImage: "doc.plaintext") }
                NavigationLink { AcknowledgementsView().toolbarVisibility(.hidden, for: .tabBar) } label: { Label("Acknowledgements", systemImage: "text.book.closed") }.accessibilityIdentifier("settings.acknowledgements")
            } header: { Text("Help") }
            Section {} footer: { Text("Hereabouts \(Support.version)").font(.wbCaption).foregroundStyle(Theme.pencil) }
        }
        .listStyle(.plain)
        .font(.wbBody).tint(Theme.purpleInk).groundBackground().navigationTitle("Settings").navigationBarTitleDisplayMode(.inline)
    }
}

struct LeavingView: View {
    @Environment(LocaliserStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var selectedFiles = AutomaticBackups.savedSelection()
    @State private var savedBackups: [SavedBackup] = []
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
    private var retainedFileCount: Int { store.items.filter { $0.photo != nil }.count }

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
                }.buttonStyle(.plain)
                if !savedBackups.isEmpty {
                    SectionHeading(title: "Saved automatically")
                    VStack(spacing: 0) {
                        ForEach(savedBackups) { backup in
                            Button { chooseSaved(backup) } label: {
                                optionLabel(backup.date.formatted(date: .abbreviated, time: .shortened), "Restore this one.", "clock.arrow.circlepath")
                            }.accessibilityLabel("Restore the backup from \(backup.date.formatted(date: .abbreviated, time: .shortened))")
                        }
                    }.buttonStyle(.plain)
                }
                Text("A backup holds your places, things, history, dates, kits and trips. Photos and documents are included only if you choose them. Backups aren't encrypted, so anyone with the file can read it. Save it somewhere private, like iCloud Drive or Files on this iPhone.")
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
        .task { savedBackups = await AutomaticBackups.savedEverywhere() }
        .onChange(of: selectedFiles) { _, ids in AutomaticBackups.saveSelection(ids) }
        .fileExporter(isPresented: $exporting, document: document, contentType: exportType, defaultFilename: exportType == .json ? "Hereabouts backup \(Date.now.formatted(.iso8601.year().month().day()))" : "Hereabouts things") { result in
            switch result { case .success: notice = exportType == .json ? "Backup saved." : "Spreadsheet saved."; case .failure(let failure): error = failure.localizedDescription }
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
            let summary = "\(pendingRestore?.contents ?? "A backup"), saved \(pendingRestore?.createdAt.formatted(date: .abbreviated, time: .shortened) ?? "on an unknown date")."
            Text(libraryIsEmpty ? summary : summary + " This replaces the notebook on this phone. If anything goes wrong, it stays exactly as it is.")
        }
        .confirmationDialog("Erase this notebook?", isPresented: $confirmErase, titleVisibility: .visible) {
            Button("Continue to erase", role: .destructive) { erasePhrase = ""; erasing = true }
        } message: { Text("Wipes everything on this phone. We'll ask twice. Your backups stay wherever you put them.") }
        .alert("Erase this notebook?", isPresented: $erasing) {
            TextField("Type ERASE", text: $erasePhrase).textInputAutocapitalization(.characters)
            Button("Cancel", role: .cancel) { erasePhrase = "" }
            Button("Erase", role: .destructive) {
                do { try store.resetLibrary(); Spotlight.clear(); selectedFiles = []; notice = "Notebook erased." } catch { self.error = error.localizedDescription }
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
            if let pendingRestore { try store.restore(pendingRestore, replacingExisting: replacing); notice = "Backup restored." }
        } catch { self.error = error.localizedDescription }
    }
    /// A saved backup goes through the same check and confirmation as one chosen from Files.
    private func chooseSaved(_ backup: SavedBackup) {
        do {
            let file = try AutomaticBackups.load(backup)
            try store.validateBackup(file)
            pendingRestore = file; confirmingRestore = true
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
    var body: some View {
        SheetForm {
            if photos.isEmpty {
                Text("No photos or kept documents yet.").foregroundStyle(Theme.secondary)
            } else {
                Section {
                    Button(selectedFiles.isEmpty ? "Include all" : "Include none") {
                        selectedFiles = selectedFiles.isEmpty ? Set(photos.map(\.id)) : []
                    }
                } footer: { Text("Files make a backup larger. A backup can be up to 200 MB.").foregroundStyle(Theme.secondary) }
                if !photos.isEmpty {
                    Section { ForEach(photos) { toggle($0.id, title: $0.name) } } header: { Text("Photos of things").foregroundStyle(Theme.secondary) }
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

/// A typeface the app ships, with the licence file bundled next to it.
struct Typeface: Identifiable {
    let name: String
    let file: String
    var id: String { name }
    static let all = [Typeface(name: "Atkinson Hyperlegible", file: "atkinsonhyperlegible-OFL"), Typeface(name: "Fraunces", file: "fraunces-OFL")]

    func licence(in bundle: Bundle = .main) -> String? {
        bundle.url(forResource: file, withExtension: "txt").flatMap { try? String(contentsOf: $0, encoding: .utf8) }
    }
    /// The first line of the licence file.
    var copyright: String { licence()?.split(whereSeparator: \.isNewline).first.map(String.init) ?? "" }
}

struct AcknowledgementsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Hereabouts is set in two typefaces, both free to use under the SIL Open Font License.").font(.wbBody).foregroundStyle(Theme.ink)
                ForEach(Typeface.all) { face in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(face.name).font(.wbItem).foregroundStyle(Theme.ink).accessibilityAddTraits(.isHeader)
                        Text(face.copyright).font(.wbCaption).foregroundStyle(Theme.pencil)
                        Text(face.licence() ?? "The licence text isn't available.").font(.wbCaption).foregroundStyle(Theme.ink).textSelection(.enabled)
                    }
                }
            }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Theme.paper).navigationTitle("Acknowledgements").navigationBarTitleDisplayMode(.inline)
    }
}
