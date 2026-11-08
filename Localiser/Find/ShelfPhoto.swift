import Foundation
import FoundationModels
import ImageIO
import SwiftUI
import UIKit

/// "Several things?": names for what's on a shelf, from one photo. Made entirely on the phone.
protocol ShelfReader: Sendable {
    func names(in photo: Data) async throws -> [String]
}

enum ShelfReading {
    static let maximumNames = 12

    /// The reader to use here, or nil when this phone can't read photos this way.
    @MainActor static var reader: (any ShelfReader)? {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--stand-in-shelf-reader") { return StandInShelfReader(result: ["Drill", "Spirit level", "Tape measure"]) }
        #endif
        if #available(iOS 27.0, *), OnDeviceShelfReader.isAvailable { return OnDeviceShelfReader() }
        return nil
    }

    /// Trimmed, without repeats or blanks, at most twelve, in the order given.
    static func clean(_ names: [String]) -> [String] {
        var seen = Set<String>()
        var kept: [String] = []
        for raw in names {
            let name = String(raw.components(separatedBy: .newlines).joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters)).prefix(TextLimit.name))
            guard !name.isEmpty, seen.insert(name.lowercased()).inserted else { continue }
            kept.append(name)
            if kept.count == maximumNames { break }
        }
        return kept
    }

    /// How many of `wanted` fit: all with Pro, otherwise what's left on the free plan.
    static func fitting(_ wanted: Int, unlocked: Bool, activeItems: Int, freeLimit: Int = CreationKind.item.freeLimit) -> Int {
        unlocked ? wanted : max(0, min(wanted, freeLimit - activeItems))
    }
}

/// For unit and UI tests.
struct StandInShelfReader: ShelfReader {
    var result: [String]
    var failure: (any Error & Sendable)?
    init(result: [String] = [], failure: (any Error & Sendable)? = nil) { self.result = result; self.failure = failure }
    func names(in photo: Data) async throws -> [String] {
        if let failure { throw failure }
        return result
    }
}

@available(iOS 27.0, *)
@Generable struct ShelfNames {
    @Guide(description: "Short everyday names for the separate objects in the photo, like \"Drill\" or \"Blue suitcase\". Leave out walls, shelves and furniture.", .maximumCount(12))
    var names: [String]
}

/// Apple's on-device model, when it's on and can look at images.
@available(iOS 27.0, *)
struct OnDeviceShelfReader: ShelfReader {
    static var isAvailable: Bool {
        let model = SystemLanguageModel.default
        return model.availability == .available && model.capabilities.contains(.vision)
    }

    func names(in photo: Data) async throws -> [String] {
        guard let source = CGImageSourceCreateWithData(photo as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceCreateThumbnailWithTransform: true, kCGImageSourceThumbnailMaxPixelSize: 1024] as CFDictionary)
        else { throw PhotoError.unreadable }
        let session = LanguageModelSession(instructions: "You help someone keep a list of their belongings. Name each separate thing you can see, as they would write it in a notebook.")
        let response = try await session.respond(generating: ShelfNames.self) {
            "What things are in this photo?"
            Attachment(image)
        }
        return response.content.names
    }
}

@MainActor extension LocaliserStore {
    /// Writes down several things in one place. Stops at the first failure; what was saved stays.
    @discardableResult func addItems(named names: [String], place: Place?, isPrivate: Bool = false) throws -> [Belonging] {
        try names.map { try addItem(name: $0, place: place, isPrivate: isPrivate) }
    }
}

/// The list after a shelf photo: every name ticked, editable, one place for all.
struct ShelfNamesView: View {
    @Environment(LocaliserStore.self) private var store
    @Environment(ProAccess.self) private var pro
    @Environment(\.dismiss) private var dismiss
    let photo: Data
    let reader: any ShelfReader
    @Binding var placeID: UUID?
    var isPrivate = false
    var onSaved: () -> Void
    @State private var rows: [Row] = []
    @State private var reading = true
    @State private var failed = false
    @State private var error: String?
    @State private var upgrade = false

    struct Row: Identifiable { let id = UUID(); var name: String; var on = true }

    private var chosen: [String] { ShelfReading.clean(rows.filter(\.on).map(\.name)) }
    private var fits: Int { ShelfReading.fitting(chosen.count, unlocked: pro.unlocked, activeItems: store.activeItemCount) }

    var body: some View {
        SheetForm {
            Section {
                if let image = UIImage(data: photo) {
                    Image(uiImage: image).resizable().scaledToFill().frame(maxWidth: .infinity).frame(height: 140)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous)).accessibilityHidden(true)
                }
            }.listRowBackground(Color.clear).listRowInsets(EdgeInsets())
            Section {
                if reading {
                    ProgressView("Reading your photo on this iPhone…")
                } else if rows.isEmpty {
                    Text(failed ? "Couldn't read that photo. Write down one thing at a time." : "Couldn't see anything to name. Try a closer photo.")
                        .foregroundStyle(Theme.secondary).accessibilityIdentifier("shelf.none")
                }
                ForEach($rows) { $row in
                    HStack(spacing: 12) {
                        Toggle(isOn: $row.on) { EmptyView() }.labelsHidden().accessibilityLabel(row.name.isEmpty ? "Include" : "Include \(row.name)")
                        TextField("Name", text: $row.name, axis: .vertical).lineLimit(1...3).foregroundStyle(row.on ? Theme.ink : Theme.secondary)
                    }
                }
            } header: { Text("What's there?").font(.wbLabel).foregroundStyle(Theme.ink).textCase(nil) }
              footer: { if !rows.isEmpty { Text("Uncheck things you don't want to save. You can edit the names.").foregroundStyle(Theme.secondary) } }
            Section {
                PlacePicker(selection: $placeID, recent: store.recentPlaces())
            } header: { Text("Where do you keep them?").font(.wbLabel).foregroundStyle(Theme.ink).textCase(nil) }
        }
        .groundBackground()
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                if !pro.unlocked, fits < chosen.count {
                    Text(fits == 0 ? "Your free plan is full. Get Pro to add more." : "You can save \(fits) of these for free.")
                        .font(.wbCaption).foregroundStyle(Theme.pencil).frame(maxWidth: .infinity, alignment: .leading).accessibilityIdentifier("shelf.freeLeft")
                }
                Button(saveTitle) { save() }
                    .buttonStyle(PrimaryButtonStyle()).accessibilityIdentifier("shelf.save")
                    .disabled(reading || chosen.isEmpty)
            }
            .padding(.horizontal, 20).padding(.vertical, 12).background(Theme.ground)
        }
        .navigationTitle("Several things").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        .task {
            do { rows = ShelfReading.clean(try await reader.names(in: photo)).map { Row(name: $0) } }
            catch { failed = true }
            reading = false
        }
        .sheet(isPresented: $upgrade) { NavigationStack { ProView() } }
        .alert("Couldn't save", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") { error = nil } } message: { Text(error ?? "") }
    }

    private var saveTitle: String {
        let count = pro.unlocked ? chosen.count : min(chosen.count, max(fits, 0))
        return count == 1 ? String(localized: "Write down 1 thing") : count == 0 ? String(localized: "Write them down") : String(localized: "Write down \(count) things")
    }

    private func save() {
        guard fits > 0 else { upgrade = true; return }
        do {
            let place = store.places.first { $0.id == placeID }
            try store.addItems(named: Array(chosen.prefix(fits)), place: place, isPrivate: isPrivate)
            UserDefaults.standard.set(place?.id.uuidString, forKey: ItemEditor.lastPlaceKey)
            UserDefaults.standard.set(Date.now, forKey: ItemEditor.lastPlaceTimeKey)
            dismiss()
            onSaved()
        } catch { self.error = error.localizedDescription }
    }
}
