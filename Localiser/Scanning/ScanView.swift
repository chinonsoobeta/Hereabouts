import SwiftUI
import PhotosUI
import VisionKit
import PDFKit
import UniformTypeIdentifiers

struct ScanView: View {
    @Environment(LocaliserStore.self) private var store
    @Environment(ProAccess.self) private var pro
    @Environment(\.dismiss) private var dismiss
    @State private var photo: PhotosPickerItem?
    @State private var camera = false
    @State private var importing = false
    @State private var processing = false
    @State private var draft: ScanDraft?
    @State private var candidateID: String?
    @State private var itemID: UUID?
    @State private var newName = ""
    @FocusState private var nameFocused: Bool
    @State private var review = false
    @State private var error: String?
    @State private var upgrade = false

    private var selected: DateCandidate? { draft?.candidates.first { $0.id == candidateID } }

    var body: some View {
        SheetForm {
            Section("Read a receipt or label") {
                Button("Scan with camera", systemImage: "doc.viewfinder") { camera = true }.disabled(!VNDocumentCameraViewController.isSupported || processing)
                PhotosPicker(selection: $photo, matching: .images) { Label("Choose a photo", systemImage: "photo") }.disabled(processing)
                Button("Import PDF or image", systemImage: "doc.badge.plus") { importing = true }.disabled(processing)
                if !VNDocumentCameraViewController.isSupported { Text("Camera scanning is unavailable on this device. Choose a photo or import a document.").font(.caption).foregroundStyle(Theme.secondary) }
                if processing { ProgressView("Reading on this device…") }
            }
            if let draft {
                Section("Check the dates") {
                    if let preview = draft.preview, let image = UIImage(data: preview) { Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 220) }
                    DisclosureGroup("Recognized text (not saved)") { Text(draft.text.isEmpty ? "No text was recognized." : draft.text).font(.caption).textSelection(.enabled) }
                    if draft.candidates.isEmpty { Text("No complete date was found. Enter the date manually in the next step.") }
                    ForEach(draft.candidates) { candidate in
                        Button { candidateID = candidate.id } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                HStack { Text(candidate.raw).bold(); Spacer(); if candidate.id == candidateID { Image(systemName: "checkmark.circle.fill") } }
                                if let date = candidate.day.date() { Text(date, format: .dateTime.year().month().day()) }
                                Text(candidate.line).font(.caption).foregroundStyle(Theme.secondary)
                                if candidate.shortYear { Text("The year has two digits, so check the century before you confirm.").font(.caption).foregroundStyle(Theme.warning) }
                                else if candidate.ambiguous { Text("This could be day/month or month/day. Pick the one that matches the receipt.").font(.caption).foregroundStyle(Theme.warning) }
                                Text(candidate.hint.map { "Looks like a \($0.noun). You'll confirm it next." } ?? "Not sure what kind of date this is. You'll choose next.").font(.caption)
                            }
                        }
                    }
                    Button("Enter a different date manually") { candidateID = nil }
                    Text("A purchase date isn't the last day to return. You'll confirm the kind of date next, and nothing is scheduled until you do.").font(.caption).foregroundStyle(Theme.secondary)
                }
                Section("Which thing is it for?") {
                    Picker("Thing", selection: $itemID) {
                        Text("Choose a thing").tag(nil as UUID?)
                        ForEach(store.items.filter { !$0.archived }) { Text($0.name).tag(Optional($0.id)) }
                    }
                    TextField("Or name a new thing", text: $newName).focused($nameFocused).submitLabel(.done).onSubmit { nameFocused = false }
                    Button("Write it down") {
                        guard pro.allows(.item, count: store.activeItemCount) else { upgrade = true; return }
                        do { itemID = try store.addItem(name: newName).id; newName = "" } catch { self.error = error.localizedDescription }
                    }.disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Button("Review and confirm date") { nameFocused = false; review = true }.disabled(itemID == nil)
                }
            }
            Section { Text("Everything is read on your iPhone. You'll confirm the dates before anything is saved.").font(.caption).foregroundStyle(Theme.secondary) }
        }
        .groundBackground().navigationTitle("Scan a document").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        .sheet(isPresented: $camera) { DocumentCamera { result in
            camera = false
            switch result { case .success(let data): read(data, filename: "Document.pdf", mime: "application/pdf"); case .failure(let error): self.error = error.localizedDescription }
        } canceled: { camera = false } }
        .sheet(isPresented: $upgrade) { NavigationStack { ProView() } }
        .sheet(isPresented: $review, onDismiss: { draft = nil; candidateID = nil; photo = nil }) {
            if let draft, let item = store.items.first(where: { $0.id == itemID }) {
                NavigationStack { DeadlineEditor(item: item, suggestedDate: selected?.day.date(), source: "Confirmed from a scanned document", suggestedKind: selected?.hint, scan: draft, onSaved: { dismiss() }) }
            }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.pdf, .image]) { result in
            do {
                let url = try result.get()
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                if let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size > ScanReader.maximumBytes { throw ScanError.tooLarge }
                let data = try Data(contentsOf: url)
                read(data, filename: url.lastPathComponent, mime: url.pathExtension.lowercased() == "pdf" ? "application/pdf" : "image/jpeg")
            } catch { self.error = error.localizedDescription }
        }
        .onChange(of: photo) { _, value in
            guard let value else { return }
            processing = true; draft = nil; candidateID = nil
            Task {
                do {
                    guard let data = try await value.loadTransferable(type: Data.self) else { throw ScanError.unreadable }
                    read(data, filename: "Photo.jpg", mime: "image/jpeg")
                } catch { processing = false; self.error = error.localizedDescription }
            }
        }
        .alert("Couldn't read that document", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") { error = nil } } message: { Text(error ?? "") }
    }

    private func read(_ data: Data, filename: String, mime: String) {
        processing = true; draft = nil; candidateID = nil
        Task {
            do { draft = try await Task.detached(priority: .userInitiated) { try ScanReader.read(data: data, filename: filename, mime: mime) }.value }
            catch { self.error = error.localizedDescription }
            processing = false
        }
    }
}

struct DocumentCamera: UIViewControllerRepresentable {
    let completed: (Result<Data, Error>) -> Void
    let canceled: () -> Void
    func makeCoordinator() -> Coordinator { Coordinator(completed: completed, canceled: canceled) }
    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController(); controller.delegate = context.coordinator; return controller
    }
    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}
    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let completed: (Result<Data, Error>) -> Void
        let canceled: () -> Void
        init(completed: @escaping (Result<Data, Error>) -> Void, canceled: @escaping () -> Void) { self.completed = completed; self.canceled = canceled }
        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) { canceled() }
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) { completed(.failure(error)) }
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            guard scan.pageCount <= 10 else { completed(.failure(ScanError.tooManyPages)); return }
            let document = PDFDocument()
            for index in 0..<scan.pageCount {
                if let page = PDFPage(image: scan.imageOfPage(at: index)) { document.insert(page, at: document.pageCount) }
            }
            guard let data = document.dataRepresentation(), data.count <= ScanReader.maximumBytes else { completed(.failure(ScanError.tooLarge)); return }
            completed(.success(data))
        }
    }
}

struct StoredScanView: View {
    @Environment(LocaliserStore.self) private var store
    @Environment(ProAccess.self) private var pro
    let scan: ScanRecord
    @State private var removing = false
    @State private var error: String?
    var body: some View {
        let _ = store.revision
        VStack {
            if let data = scan.data {
                if scan.mime == "application/pdf" { PDFPreview(data: data) }
                else if let image = UIImage(data: data) { ScrollView { Image(uiImage: image).resizable().scaledToFit() } }
                Button("Remove original document", role: .destructive) { removing = true }.padding()
            } else { LibraryEmptyState(title: "Date-only scan", systemImage: "calendar", description: "The original wasn't kept. Your dates stay with the thing.") }
        }
        .navigationTitle(scan.filename).navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Remove the original?", isPresented: $removing, titleVisibility: .visible) { Button("Remove original", role: .destructive) {
            do { try store.removeScanSource(scan) } catch { self.error = error.localizedDescription }
        } } message: { Text(pro.unlocked ? "Your dates stay with the thing." : "Your dates stay with the thing. The scan still counts toward this month's free scans.") }
        .alert("Couldn't remove the original", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") { error = nil } } message: { Text(error ?? "") }
    }
}

struct PDFPreview: UIViewRepresentable {
    let data: Data
    func makeUIView(context: Context) -> PDFView { let view = PDFView(); view.autoScales = true; view.document = PDFDocument(data: data); return view }
    func updateUIView(_ uiView: PDFView, context: Context) {}
}
