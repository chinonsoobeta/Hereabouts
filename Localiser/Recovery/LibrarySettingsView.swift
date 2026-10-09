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
    @Environment(\.dismiss) private var dismiss
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

    var body: some View {
        Form {
            Section { NavigationLink("Purchase or restore lifetime Pro") { ProView() } }
                header: { Text("Localiser Pro").foregroundStyle(Theme.secondary) }
            Section {
                Text("Document reading happens on your device. Source text is discarded after review; originals are retained only when you choose to keep them. Retained files may participate in device backup and configured private sync.").font(.footnote)
                Text("Localiser has no advertising or analytics SDK. Reminders use generic lock-screen text. Exported files are not encrypted by Localiser.").font(.footnote).foregroundStyle(Theme.secondary)
            } header: { Text("Privacy").foregroundStyle(Theme.secondary) }
            Section {
                Toggle("Use my private iCloud", isOn: Binding(get: { store.syncRequested }, set: { value in
                    do { try store.requestSync(value) } catch { self.error = error.localizedDescription }
                })).disabled(!store.syncAvailable)
                Text(store.syncStatus).font(.footnote).foregroundStyle(Theme.secondary)
                if !store.syncAvailable { Text("This build is not configured for private iCloud. Sync stays off until the app is signed with its own iCloud container.").font(.footnote) }
                Text("Changes work offline. Apply sync settings by restarting Localiser. Household sharing is not included.").font(.footnote).foregroundStyle(Theme.secondary)
            } header: { Text("Private sync").foregroundStyle(Theme.secondary) }
            Section {
                Button("Export inventory CSV") { prepareCSV() }
                Button("Export restorable backup") { prepareBackup() }
                Text("A backup includes places, belongings, history, confirmed dates, kits, trips and packing progress. Choose photos and retained documents below to include their files. Exports are available without a purchase.").font(.footnote).foregroundStyle(Theme.secondary)
                Text("The exported file is readable by anyone who can access it. Save it somewhere private.").font(.footnote)
            } header: { Text("Export").foregroundStyle(Theme.secondary) }
            Section {
                ForEach(store.items.filter { $0.photo != nil }) { item in
                    fileToggle(item.id, title: "Photo: \(item.name)")
                }
                ForEach(store.items.flatMap { Array($0.scans) }.filter { $0.data != nil }.sorted { $0.createdAt < $1.createdAt }) { scan in
                    fileToggle(scan.id, title: "\(scan.item?.name ?? "Document"): \(scan.filename)")
                }
                if store.items.allSatisfy({ $0.photo == nil && $0.scans.allSatisfy { $0.data == nil } }) { Text("No retained files.").foregroundStyle(Theme.secondary) }
            } header: { Text("Files to include in backup").foregroundStyle(Theme.secondary) }
            Section {
                Button("Choose Localiser backup") { importing = true }.disabled(store.syncEnabled || store.hasUsedSync)
                Text("Restore requires an empty local library and private sync off. Existing records are never overwritten. A restored library stays local until cloud reconnection is verified.").font(.footnote).foregroundStyle(Theme.secondary)
            } header: { Text("Restore").foregroundStyle(Theme.secondary) }
            Section {
                Button("Erase all local records…", role: .destructive) { erasePhrase = ""; erasing = true }
                    .foregroundStyle(Theme.warning).disabled(store.syncEnabled || store.hasUsedSync)
                Text("Export first. This removes local records and retained files, including trip history. This action does not erase an existing iCloud library.").font(.footnote).foregroundStyle(Theme.secondary)
                if store.hasUsedSync { Text("Restore and erase are unavailable for stores that have used sync until cloud reconnection has been verified. Export remains available.").font(.footnote) }
            } header: { Text("Erase local library").foregroundStyle(Theme.secondary) }
            if let notice { Section { Text(notice) } }
        }
        .groundBackground().navigationTitle("Settings and backup").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done", systemImage: "checkmark") { dismiss() }.labelStyle(.iconOnly) } }
        .fileExporter(isPresented: $exporting, document: document, contentType: exportType, defaultFilename: exportType == .json ? "Localiser-backup" : "Localiser-inventory") { result in
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
            Button("Restore") {
                defer { pendingRestore = nil }
                do { if let pendingRestore { try store.restore(pendingRestore); notice = "Backup restored. Check your library and enable reminders if needed." } }
                catch { self.error = error.localizedDescription }
            }
        } message: {
            Text("\(pendingRestore?.records.count ?? 0) records from \(pendingRestore?.createdAt.formatted(date: .abbreviated, time: .shortened) ?? "unknown date"). Only the files included in this backup can be restored.")
        }
        .alert("Erase all local records?", isPresented: $erasing) {
            TextField("Type ERASE", text: $erasePhrase).textInputAutocapitalization(.characters)
            Button("Cancel", role: .cancel) { erasePhrase = "" }
            Button("Erase", role: .destructive) {
                do { try store.resetLibrary(); selectedFiles = []; notice = "Local library erased." } catch { self.error = error.localizedDescription }
            }.disabled(erasePhrase != "ERASE")
        } message: { Text("This cannot be undone without a backup. Type ERASE to confirm.") }
        .alert("Could not complete", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") { error = nil } } message: { Text(error ?? "") }
    }

    private func fileToggle(_ id: UUID, title: String) -> some View {
        Toggle(title, isOn: Binding(get: { selectedFiles.contains(id) }, set: { if $0 { selectedFiles.insert(id) } else { selectedFiles.remove(id) } }))
    }
    private func prepareCSV() {
        exportType = .commaSeparatedText; document = LibraryExportDocument(data: Data(store.inventoryCSV().utf8)); exporting = true
    }
    private func prepareBackup() {
        do { exportType = .json; document = LibraryExportDocument(data: try store.backup(attachmentIDs: selectedFiles).encoded()); exporting = true }
        catch { self.error = error.localizedDescription }
    }
}
