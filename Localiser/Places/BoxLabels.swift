import CoreImage.CIFilterBuiltins
import SwiftUI
import UIKit
import VisionKit

/// Printed labels for boxes and shelves: the place's name and path, and a QR code holding only
/// hereabouts://place/<id>. Eight to a page, on A4 or US Letter.
enum BoxLabels {
    enum Paper: String, CaseIterable, Identifiable {
        case a4, letter
        var id: String { rawValue }
        var title: String { self == .a4 ? "A4" : "US Letter" }
        /// Points, portrait.
        var size: CGSize { self == .a4 ? CGSize(width: 595.28, height: 841.89) : CGSize(width: 612, height: 792) }
        /// Letter where it's the usual paper; A4 everywhere else.
        static func usual(for region: Locale.Region? = Locale.current.region) -> Paper {
            let letter: Set<String> = ["US", "CA", "MX", "CL", "CO", "CR", "DO", "GT", "PA", "PH", "PR", "SV", "VE"]
            return letter.contains(region?.identifier ?? "") ? .letter : .a4
        }
    }

    static let perPage = 8
    static func pageCount(labels: Int) -> Int { max(1, (labels + perPage - 1) / perPage) }

    static func qrCode(for url: URL, size: CGFloat) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(url.absoluteString.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scale = max(1, (size / output.extent.width).rounded(.down))
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let image = CIContext().createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: image)
    }

    /// The label sheet as PDF data. With `listContents`, each label also lists what's inside today.
    @MainActor static func pdf(for places: [Place], paper: Paper, listContents: Bool) -> Data {
        let bounds = CGRect(origin: .zero, size: paper.size)
        let margin: CGFloat = 36, gap: CGFloat = 12
        let cell = CGSize(width: (bounds.width - margin * 2 - gap) / 2, height: (bounds.height - margin * 2 - gap * 3) / 4)
        let renderer = UIGraphicsPDFRenderer(bounds: bounds)
        return renderer.pdfData { context in
            let pages = stride(from: 0, to: max(places.count, 1), by: perPage).map { Array(places.dropFirst($0).prefix(perPage)) }
            for page in pages {
                context.beginPage()
                for (index, place) in page.enumerated() {
                    let origin = CGPoint(x: margin + CGFloat(index % 2) * (cell.width + gap), y: margin + CGFloat(index / 2) * (cell.height + gap))
                    draw(place, in: CGRect(origin: origin, size: cell), listContents: listContents)
                }
            }
        }
    }

    @MainActor private static func draw(_ place: Place, in frame: CGRect, listContents: Bool) {
        let border = UIBezierPath(roundedRect: frame, cornerRadius: 10)
        UIColor.black.withAlphaComponent(0.35).setStroke(); border.lineWidth = 0.75
        border.setLineDash([4, 3], count: 2, phase: 0); border.stroke()
        let inset = frame.insetBy(dx: 12, dy: 12)
        let noteFont = UIFont.systemFont(ofSize: 7)
        let bottom = inset.maxY - noteFont.lineHeight - 4
        /// Draws wrapped text at the top of `rect`; returns the height used.
        @discardableResult func write(_ text: String, _ font: UIFont, _ color: UIColor = .black, in rect: CGRect, lines: Int) -> CGFloat {
            let style = NSMutableParagraphStyle(); style.lineBreakMode = .byWordWrapping
            let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color, .paragraphStyle: style]
            let box = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: min(font.lineHeight * CGFloat(lines), rect.height))
            guard box.height > 0 else { return 0 }
            let used = (text as NSString).boundingRect(with: box.size, options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine], attributes: attributes, context: nil).height
            (text as NSString).draw(with: box, options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine], attributes: attributes, context: nil)
            return min(ceil(used), box.height)
        }
        // The name runs across the top, big enough to read from across a room.
        let titleHeight = write(place.name, .systemFont(ofSize: 20, weight: .bold), in: CGRect(x: inset.minX, y: inset.minY, width: inset.width, height: inset.height), lines: 2)
        let top = inset.minY + titleHeight + 8
        let codeSide = max(0, min(bottom - top, 110))
        if let code = qrCode(for: AppLink.place(place.id).url, size: codeSide * 4) {
            UIGraphicsGetCurrentContext()?.interpolationQuality = .none
            code.draw(in: CGRect(x: inset.minX, y: top, width: codeSide, height: codeSide))
        }
        let column = CGRect(x: inset.minX + codeSide + 12, y: top, width: inset.maxX - inset.minX - codeSide - 12, height: bottom - top)
        var y = column.minY
        if place.parent != nil {
            y += write(place.path, .systemFont(ofSize: 10), .darkGray, in: CGRect(x: column.minX, y: y, width: column.width, height: column.maxY - y), lines: 3) + 6
        }
        if listContents {
            let names = place.items.filter { !$0.archived && !$0.isPrivate }.map(\.name).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
            if !names.isEmpty {
                let shown = names.prefix(8).joined(separator: ", ") + (names.count > 8 ? " and \(names.count - 8) more" : "")
                write(shown, .systemFont(ofSize: 10), .darkGray, in: CGRect(x: column.minX, y: y, width: column.width, height: column.maxY - y), lines: 7)
            }
        }
        let note = "Scan with the iPhone Camera to open in Hereabouts."
        (note as NSString).draw(in: CGRect(x: inset.minX, y: inset.maxY - noteFont.lineHeight, width: inset.width, height: noteFont.lineHeight), withAttributes: [.font: noteFont, .foregroundColor: UIColor.gray])
    }

    /// Writes the sheet to a temporary file named for sharing or printing.
    @MainActor static func file(for places: [Place], paper: Paper, listContents: Bool) throws -> URL {
        let name = places.count == 1 ? "\(places[0].name) label.pdf" : "Hereabouts labels.pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name.replacingOccurrences(of: "/", with: "-"))
        try pdf(for: places, paper: paper, listContents: listContents).write(to: url, options: .atomic)
        return url
    }
}

/// Choose paper and whether to list contents, then share or print.
struct LabelSheetView: View {
    @Environment(LocaliserStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let initial: [Place]
    @State private var chosen: Set<UUID>
    @State private var paper = BoxLabels.Paper.usual()
    @State private var listContents = false
    @State private var file: URL?
    @State private var error: String?

    init(places: [Place]) {
        initial = places
        _chosen = State(initialValue: Set(places.map(\.id)))
    }

    private var picking: Bool { initial.count != 1 }
    private var selected: [Place] { store.places.filter { chosen.contains($0.id) }.sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending } }

    var body: some View {
        let _ = store.revision
        SheetForm {
            if picking {
                Section {
                    ForEach(store.places.sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }) { place in
                        Toggle(place.path, isOn: Binding(get: { chosen.contains(place.id) }, set: { on in if on { chosen.insert(place.id) } else { chosen.remove(place.id) } }))
                    }
                } header: { Text("Which places?").font(.wbLabel).foregroundStyle(Theme.ink).textCase(nil) }
            }
            Section {
                Picker("Paper", selection: $paper) { ForEach(BoxLabels.Paper.allCases) { Text($0.title).tag($0) } }
                Toggle("List what's inside", isOn: $listContents)
            } footer: {
                Text(listContents ? "Printed lists go out of date as things move. Private things are left off." : "Eight labels to a page. The code opens the place in Hereabouts.")
                    .foregroundStyle(Theme.secondary)
            }
        }
        .groundBackground()
        .safeAreaInset(edge: .bottom) {
            Group {
                if let file, !selected.isEmpty {
                    ShareLink(item: file) {
                        Text(selected.count == 1 ? "Share or print the label" : "Share or print \(selected.count) labels")
                            .fixedSize(horizontal: false, vertical: true)
                    }.buttonStyle(PrimaryButtonStyle()).accessibilityIdentifier("labels.share")
                } else {
                    Text("Choose at least one place.").font(.wbCaption).foregroundStyle(Theme.secondary).frame(maxWidth: .infinity, minHeight: 52)
                }
            }
            .padding(.horizontal, 20).padding(.vertical, 12).background(Theme.ground)
        }
        .navigationTitle(picking ? "Print labels" : "Print a label").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
        .task(id: "\(chosen.sorted { $0.uuidString < $1.uuidString })\(paper.rawValue)\(listContents)") { render() }
        .alert("Couldn't make the labels", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") { error = nil } } message: { Text(error ?? "") }
    }

    private func render() {
        guard !selected.isEmpty else { file = nil; return }
        do { file = try BoxLabels.file(for: selected, paper: paper, listContents: listContents) } catch { self.error = error.localizedDescription }
    }
}

/// "Scan a label" inside the app. Needs a camera, so it's hidden where scanning isn't supported.
struct LabelScanner: UIViewControllerRepresentable {
    var found: (UUID) -> Void

    static var isAvailable: Bool { DataScannerViewController.isSupported && DataScannerViewController.isAvailable }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(recognizedDataTypes: [.barcode(symbologies: [.qr])], qualityLevel: .balanced, isHighlightingEnabled: true)
        scanner.delegate = context.coordinator
        try? scanner.startScanning()
        return scanner
    }

    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) { context.coordinator.parent = self }
    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    @MainActor final class Coordinator: NSObject, @preconcurrency DataScannerViewControllerDelegate {
        var parent: LabelScanner
        private var done = false
        init(parent: LabelScanner) { self.parent = parent }

        func dataScanner(_ scanner: DataScannerViewController, didAdd items: [RecognizedItem], allItems: [RecognizedItem]) {
            for item in items {
                guard !done, case .barcode(let code) = item, let text = code.payloadStringValue,
                      let url = URL(string: text), case .place(let id)? = AppLink(url: url) else { continue }
                done = true
                scanner.stopScanning()
                parent.found(id)
            }
        }
    }
}
