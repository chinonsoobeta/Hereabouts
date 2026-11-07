import Foundation

/// One backup file saved by `AutomaticBackups`, dated by its name.
struct SavedBackup: Identifiable, Equatable {
    let url: URL
    let date: Date
    var id: URL { url }
}

/// Pro keeps a weekly copy of the notebook. It writes the same file "Back up everything" makes, to the app's
/// iCloud Drive folder, or to the phone when iCloud Drive is off, and keeps the newest five. The folder, clock,
/// Pro state and file writer are passed in so all of it can be tested without iCloud.
struct AutomaticBackups {
    static let enabledKey = "automaticBackupsOn"
    static let lastKey = "automaticBackupLast"
    static let attemptKey = "automaticBackupAttempt"
    /// The photos chosen under "Photos and documents to include", which the automatic backups carry too.
    static let filesKey = "backupFileIDs"
    static let keep = 5
    static let interval: TimeInterval = 7 * 86_400
    /// A try that failed isn't repeated until the next day.
    static let retryGap: TimeInterval = 86_400
    static let container = "iCloud.dev.hereabouts.app"
    private static let prefix = "Hereabouts backup "

    enum Outcome { case skipped, wrote(URL), failed(Error) }

    var folder: URL
    var now: () -> Date = { .now }
    var isPro: Bool
    var defaults: UserDefaults = .standard
    var write: (Data, URL) throws -> Void = { try $0.write(to: $1, options: .atomic) }

    var enabled: Bool {
        get { defaults.object(forKey: Self.enabledKey) as? Bool ?? true }
        nonmutating set { defaults.set(newValue, forKey: Self.enabledKey) }
    }
    var lastBackup: Date? { date(forKey: Self.lastKey) }
    private func date(forKey key: String) -> Date? {
        let time = defaults.double(forKey: key)
        return time > 0 ? Date(timeIntervalSince1970: time) : nil
    }

    /// Due when a week has passed since the last backup, and never twice in a day.
    func isDue() -> Bool {
        let current = now()
        if let last = lastBackup, current.timeIntervalSince(last) < Self.interval { return false }
        if let attempt = date(forKey: Self.attemptKey), current.timeIntervalSince(attempt) < Self.retryGap { return false }
        return true
    }

    /// Writes a backup if Pro is on, the switch is on and one is due. Older backups are only pruned once the new one has landed.
    @MainActor func runIfDue(store: LocaliserStore) -> Outcome {
        guard isPro, enabled, isDue() else { return .skipped }
        let current = now()
        defaults.set(current.timeIntervalSince1970, forKey: Self.attemptKey)
        do {
            let data = try store.backup(attachmentIDs: Self.savedSelection(in: defaults)).encoded()
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let url = folder.appendingPathComponent(Self.fileName(for: current))
            try write(data, url)
            defaults.set(current.timeIntervalSince1970, forKey: Self.lastKey)
            prune()
            return .wrote(url)
        } catch { return .failed(error) }
    }

    private func prune() {
        for old in saved().dropFirst(Self.keep) { try? FileManager.default.removeItem(at: old.url) }
    }

    /// The backups in this folder, newest first.
    func saved() -> [SavedBackup] { Self.saved(in: folder) }
    static func saved(in folder: URL) -> [SavedBackup] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        return names.compactMap { name in
            Self.date(fromFileName: name).map { SavedBackup(url: folder.appendingPathComponent(name), date: $0) }
        }.sorted { $0.date > $1.date }
    }

    /// Reads a saved backup, with the same size limit as a file chosen by hand.
    static func load(_ saved: SavedBackup) throws -> LibraryBackup {
        let size = try saved.url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size <= LibraryBackup.maximumBytes else { throw LocaliserError.invalidBackup("Choose a backup under 200 MB.") }
        return try LibraryBackup.decoded(Data(contentsOf: saved.url))
    }

    // MARK: Names, so files sort by date

    private static var nameFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd'T'HHmmss'Z'"
        return formatter
    }
    static func fileName(for date: Date) -> String { prefix + nameFormatter.string(from: date) + ".json" }
    static func date(fromFileName name: String) -> Date? {
        guard name.hasPrefix(prefix), name.hasSuffix(".json") else { return nil }
        return nameFormatter.date(from: String(name.dropFirst(prefix.count).dropLast(".json".count)))
    }

    // MARK: Photos chosen for backups

    static func savedSelection(in defaults: UserDefaults = .standard) -> Set<UUID> {
        Set((defaults.stringArray(forKey: filesKey) ?? []).compactMap(UUID.init(uuidString:)))
    }
    static func saveSelection(_ ids: Set<UUID>, in defaults: UserDefaults = .standard) {
        defaults.set(ids.map(\.uuidString).sorted(), forKey: filesKey)
    }

    // MARK: Where backups live

    /// The app's iCloud Drive folder, or the phone when iCloud Drive isn't available. Looking up the container can take a while.
    static func resolveFolder() async -> URL {
        let cloud = await Task.detached { cloudFolder() }.value
        return cloud ?? localFolder
    }
    static var localFolder: URL {
        URL.applicationSupportDirectory.appendingPathComponent("Backups", isDirectory: true)
    }
    private static func cloudFolder() -> URL? {
        FileManager.default.url(forUbiquityContainerIdentifier: container)?
            .appendingPathComponent("Documents", isDirectory: true).appendingPathComponent("Backups", isDirectory: true)
    }
    /// Saved backups from iCloud Drive and from the phone, newest first.
    static func savedEverywhere() async -> [SavedBackup] {
        let cloud = await Task.detached { cloudFolder() }.value
        return ([cloud, localFolder].compactMap { $0 }.flatMap { saved(in: $0) }).sorted { $0.date > $1.date }
    }
}
