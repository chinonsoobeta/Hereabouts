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
    @Environment(\.horizontalSizeClass) private var sizeClass
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
            return String(localized: "You have \(count) reminders scheduled on this iPhone.")
        case "Disabled in Settings": return String(localized: "Notifications are off for Hereabouts, so reminders can't reach you.")
        default: return String(localized: "Turn on reminders so Hereabouts can tell you before a date passes.")
        }
    }

    var body: some View {
        SheetList {
            if store.isStale {
                Section {
                    Label("Hereabouts couldn't refresh your notebook. Close the app and open it again. Nothing has been deleted.", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(Theme.warning).fixedSize(horizontal: false, vertical: true)
                }
            }
            Section {
                NavigationLink(value: SettingsPage.pro) {
                    NotebookLine(name: String(localized: "Hereabouts Pro"), detail: pro.standing?.summary ?? String(localized: "Free plan, \(store.activeItemCount) of \(CreationKind.item.freeLimit) things"))
                }.accessibilityLabel(String(localized: "Hereabouts Pro")).accessibilityValue(pro.standing?.summary ?? String(localized: "Free plan, \(store.activeItemCount) of \(CreationKind.item.freeLimit) things"))
            }
            Section {
                NavigationLink(value: SettingsPage.homes) {
                    NotebookLine(name: store.currentHome?.name ?? Home.defaultName, detail: store.hasSeveralHomes ? String(localized: "\(store.homes.count) homes") : String(localized: "Rename or add a home"))
                }.accessibilityIdentifier("settings.homes")
            } header: { Text("Home") }
            Section {
                Label { Text(coverageSummary).fixedSize(horizontal: false, vertical: true) } icon: {
                    Image(systemName: reminders.coverageGap ? "bell.badge" : "bell").foregroundStyle(reminders.coverageGap ? Theme.warning : Theme.purpleInk)
                }
                if reminders.permission == "Enabled" || reminders.permission == "Quiet delivery" {
                    if reminders.coverageGap { Text("Your iPhone limits how many reminders you can schedule at once. Open Hereabouts to schedule the rest.").font(.wbCaption).foregroundStyle(Theme.pencil).fixedSize(horizontal: false, vertical: true) }
                } else if reminders.permission == "Disabled in Settings", let url = URL(string: UIApplication.openSettingsURLString) {
                    Button("Open notification settings", systemImage: "bell.slash") { UIApplication.shared.open(url) }
                } else {
                    Button("Turn on reminders", systemImage: "bell.badge") { Task { await reminders.enable() } }
                }
                if let problem = reminders.problem { Text(problem.message).font(.wbCaption).foregroundStyle(Theme.warning).fixedSize(horizontal: false, vertical: true) }
                Toggle("Show names in reminders", isOn: $showItemNames)
                    .onChange(of: showItemNames) { _, _ in reminders.refresh(store.deadlines); reminders.refreshRituals(store) }
                Toggle("Sunday recap", isOn: $recapOn)
                    .onChange(of: recapOn) { _, _ in reminders.refreshRituals(store) }
                Toggle("Monthly check", isOn: $stocktakeOn)
                    .onChange(of: stocktakeOn) { _, _ in reminders.refreshRituals(store) }
            } header: { Text("Reminders") }
              footer: { Text(showItemNames ? "Anyone who sees your Lock Screen can read the thing's name." : "Reminders won't show the thing's name.").font(.wbCaption).foregroundStyle(Theme.pencil) }
            Section {
                if pro.unlocked {
                    Toggle("Automatic backups", isOn: $automaticBackups)
                    Text(lastBackupTime > 0 ? "Last backup \(Date(timeIntervalSince1970: lastBackupTime).formatted(.relative(presentation: .named)))" : "Your first backup is saved soon after you open the app.")
                        .font(.wbCaption).foregroundStyle(Theme.pencil)
                } else {
                    NavigationLink(value: SettingsPage.pro) {
                        NotebookLine(name: String(localized: "Automatic backups"), detail: String(localized: "Pro saves a copy of your notebook every week."))
                    }
                }
            } header: { Text("Backups") }
              footer: { if pro.unlocked { Text("Your backups go to iCloud Drive, or this iPhone if it's off. You keep the newest five.").font(.wbCaption).foregroundStyle(Theme.pencil) } }
            Section {
                NavigationLink("Take your notebook with you.", value: SettingsPage.leaving).accessibilityIdentifier("settings.leaving")
            } header: { Text("Leaving") }
            Section {
                Label("Your notebook is saved on this iPhone. With Pro, weekly backups go to your own iCloud Drive. You don't need an account. There's no advertising or analytics.", systemImage: "lock.shield")
            } header: { Text("Privacy") }
            Section {
                Button("Show the introduction again", systemImage: "play.rectangle") { seenOnboarding = false }
                Link(destination: Support.mail(subject: "Hereabouts feedback")) { Label("Send feedback", systemImage: "envelope") }
                Link(destination: Support.supportPage) { Label("Help and support", systemImage: "questionmark.circle") }
                Link(destination: Support.privacy) { Label("Privacy Policy", systemImage: "hand.raised") }
                Link(destination: Support.terms) { Label("Terms of Use", systemImage: "doc.plaintext") }
                NavigationLink(value: SettingsPage.acknowledgements) { Label("Acknowledgments", systemImage: "text.book.closed") }.accessibilityIdentifier("settings.acknowledgements")
            } header: { Text("Help") }
            Section {} footer: { Text("Hereabouts \(Support.version)").font(.wbCaption).foregroundStyle(Theme.pencil) }
        }
        .listStyle(.plain)
        .font(.wbBody).tint(Theme.purpleInk)
        // One comfortable column on a wide screen, like Find.
        .frame(maxWidth: sizeClass == .regular ? FindView.readingWidth : .infinity)
        .frame(maxWidth: .infinity)
        .groundBackground().navigationTitle("Settings").navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: SettingsPage.self) { page in
            switch page {
            case .pro: ProView(showsClose: false).toolbarVisibility(.hidden, for: .tabBar)
            case .homes: HomesView().toolbarVisibility(.hidden, for: .tabBar)
            case .leaving: LeavingView().toolbarVisibility(.hidden, for: .tabBar)
            case .acknowledgements: AcknowledgementsView().toolbarVisibility(.hidden, for: .tabBar)
            }
        }
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
                Text("Nothing leaves this iPhone except copies you save and, with Pro, weekly backups to your own iCloud Drive. You can keep a copy in a format you can open anywhere.").font(.wbBody).foregroundStyle(Theme.ink)
                SectionHeading(title: String(localized: "Keep a copy"))
                VStack(spacing: 0) {
                    Button { prepareBackup() } label: {
                        optionLabel(String(localized: "Back up everything"), String(localized: "Save places, things, dates, trips and photos you choose. Restore into a fresh Hereabouts."), "arrow.down.doc")
                    }.accessibilityLabel("Back up everything")
                    Button { prepareCSV() } label: {
                        optionLabel(String(localized: "Export a spreadsheet"), String(localized: "Save a list of things and places. Open it in Numbers, Excel or another app."), "tablecells")
                    }.accessibilityLabel("Export a spreadsheet")
                    NavigationLink { BackupFilesView(selectedFiles: $selectedFiles) } label: {
                        optionLabel(String(localized: "Photos and documents to include"), selectedFiles.isEmpty ? String(localized: "None selected") : String(localized: "\(selectedFiles.count) of \(retainedFileCount) selected"), "photo.on.rectangle")
                    }.accessibilityLabel("Photos and documents to include")
                    Button { importing = true } label: {
                        optionLabel(String(localized: "Restore from a backup"), String(localized: "Restore your notebook from a saved copy."), "arrow.counterclockwise")
                    }.accessibilityLabel("Restore from a backup")
                }.buttonStyle(.plain)
                if !savedBackups.isEmpty {
                    SectionHeading(title: String(localized: "Saved automatically"))
                    VStack(spacing: 0) {
                        ForEach(savedBackups) { backup in
                            Button { Task { await chooseSaved(backup) } } label: {
                                optionLabel(backup.date.formatted(date: .abbreviated, time: .shortened), String(localized: "Restore this backup."), "clock.arrow.circlepath")
                            }.accessibilityLabel("Restore the backup from \(backup.date.formatted(date: .abbreviated, time: .shortened))")
                        }
                    }.buttonStyle(.plain)
                }
                Text("A backup holds your places, things, history, dates, kits and trips. You choose which photos and documents to include. Backups aren't encrypted. Anyone with the file can read it. Save it somewhere private, like iCloud Drive or Files on this iPhone.")
                    .font(.wbCaption).foregroundStyle(Theme.pencil).fixedSize(horizontal: false, vertical: true)
                SectionHeading(title: String(localized: "Erase your notebook"))
                Button(role: .destructive) { confirmErase = true } label: {
                    optionLabel(String(localized: "Erase this notebook"), String(localized: "You'll erase this notebook on your iPhone. You'll confirm twice. Your saved backups stay where you put them."), "trash")
                }.buttonStyle(.plain).foregroundStyle(Theme.amber).accessibilityLabel("Erase this notebook")
                if let notice { Label(notice, systemImage: "checkmark.circle").font(.wbBody).foregroundStyle(Theme.green) }
                StickyNote {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("You can restore your notebook from a backup if you come back.").font(.wbQuote)
                        Text("You didn't create an account, so there's nothing to close.").font(.wbCaption)
                    }.foregroundStyle(Theme.ink)
                }
                Button("Back to Settings") { dismiss() }.buttonStyle(SoftButtonStyle())
            }.padding(20)
        }
        .background(Theme.paper).navigationTitle("Leaving").navigationBarTitleDisplayMode(.inline)
        .task { savedBackups = await AutomaticBackups.savedEverywhere() }
        .onChange(of: selectedFiles) { _, ids in AutomaticBackups.saveSelection(ids) }
        .fileExporter(isPresented: $exporting, document: document, contentType: exportType, defaultFilename: exportType == .json ? String(localized: "Hereabouts backup \(Date.now.formatted(.iso8601.year().month().day()))") : String(localized: "Hereabouts things")) { result in
            switch result { case .success: notice = exportType == .json ? String(localized: "Backup saved.") : String(localized: "Spreadsheet saved."); case .failure(let failure): error = failure.localizedDescription }
            document = nil
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            do {
                let url = try result.get()
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                guard size <= LibraryBackup.maximumBytes else { throw LocaliserError.invalidBackup(String(localized: "Choose a backup under 200 MB.")) }
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
            let summary = String(localized: "\(pendingRestore?.contents ?? String(localized: "A backup")), saved \(pendingRestore?.createdAt.formatted(date: .abbreviated, time: .shortened) ?? String(localized: "on an unknown date")).")
            Text(libraryIsEmpty ? summary : summary + " " + String(localized: "This replaces the notebook on this phone. If anything goes wrong, it stays exactly as it is."))
        }
        .confirmationDialog("Erase this notebook?", isPresented: $confirmErase, titleVisibility: .visible) {
            Button("Continue to erase", role: .destructive) { erasePhrase = ""; erasing = true }
        } message: { Text("You'll erase this notebook on your iPhone. You'll confirm twice. Your saved backups stay where you put them.") }
        .alert("Erase this notebook?", isPresented: $erasing) {
            TextField("Type ERASE", text: $erasePhrase).textInputAutocapitalization(.characters)
            Button("Cancel", role: .cancel) { erasePhrase = "" }
            Button("Erase", role: .destructive) {
                do { try store.resetLibrary(); Spotlight.clear(); selectedFiles = []; notice = String(localized: "Notebook erased.") } catch { self.error = error.localizedDescription }
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
            if let pendingRestore { try store.restore(pendingRestore, replacingExisting: replacing); notice = String(localized: "Backup restored.") }
        } catch { self.error = error.localizedDescription }
    }
    /// A saved backup goes through the same check and confirmation as one chosen from Files.
    private func chooseSaved(_ backup: SavedBackup) async {
        do {
            let file = try await AutomaticBackups.load(backup)
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
                Text("Hereabouts uses two fonts. Both are free to use under the SIL Open Font License.").font(.wbBody).foregroundStyle(Theme.ink)
                ForEach(Typeface.all) { face in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(face.name).font(.wbItem).foregroundStyle(Theme.ink).accessibilityAddTraits(.isHeader)
                        Text(face.copyright).font(.wbCaption).foregroundStyle(Theme.pencil)
                        Text(face.licence() ?? String(localized: "The license text isn't available.")).font(.wbCaption).foregroundStyle(Theme.ink).textSelection(.enabled)
                    }
                }
            }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Theme.paper).navigationTitle("Acknowledgments").navigationBarTitleDisplayMode(.inline)
    }
}
