import Foundation

/// One backup file saved by `AutomaticBackups`, dated by its name.
struct SavedBackup: Identifiable, Equatable, Sendable {
    /// The backup's real name. For a placeholder this file isn't on the phone yet.
    let url: URL
    let date: Date
    /// iCloud Drive shows a file that isn't downloaded as a hidden `.name.icloud` stand-in.
    var isPlaceholder = false
    var id: URL { url }
    /// The file that is actually in the folder.
    var fileURL: URL { isPlaceholder ? AutomaticBackups.placeholderURL(for: url) : url }
}

/// Pro keeps a weekly copy of the notebook. It writes the same file "Back up everything" makes, to the app's
/// iCloud Drive folder, or to the phone when iCloud Drive is off, and keeps the newest five. The folder, clock,
/// Pro state and file writer are passed in so all of it can be tested without iCloud.
// @unchecked only because UserDefaults isn't marked Sendable; Apple documents it as safe from any thread, and every other property is Sendable.
struct AutomaticBackups: @unchecked Sendable {
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
    var now: @Sendable () -> Date = { .now }
    var isPro: Bool
    var defaults: UserDefaults = .standard
    var write: @Sendable (Data, URL) throws -> Void = { try $0.write(to: $1, options: .atomic) }

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
    /// The notebook is read here, on the main actor; encoding, writing and pruning happen on a background task.
    /// The attempt is marked before anything suspends, so a second call at launch finds it and skips.
    @MainActor func runIfDue(store: LocaliserStore) async -> Outcome {
        guard isPro, enabled, isDue() else { return .skipped }
        let current = now()
        defaults.set(current.timeIntervalSince1970, forKey: Self.attemptKey)
        let backup: LibraryBackup
        do { backup = try store.backup(attachmentIDs: Self.savedSelection(in: defaults)) } catch { return .failed(error) }
        let maker = self
        return await Task.detached { maker.save(backup, at: current) }.value
    }

    private func save(_ backup: LibraryBackup, at current: Date) -> Outcome {
        do {
            let data = try backup.encoded()
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let url = folder.appendingPathComponent(Self.fileName(for: current))
            try Self.coordinate(writing: url, .forReplacing) { try write(data, $0) }
            defaults.set(current.timeIntervalSince1970, forKey: Self.lastKey)
            prune()
            return .wrote(url)
        } catch { return .failed(error) }
    }

    private func prune() {
        for old in saved().dropFirst(Self.keep) {
            try? Self.coordinate(writing: old.fileURL, .forDeleting) { try FileManager.default.removeItem(at: $0) }
        }
    }

    /// iCloud Drive files are changed through a file coordinator, so a sync in progress isn't cut across.
    private static func coordinate(writing url: URL, _ options: NSFileCoordinator.WritingOptions, _ body: (URL) throws -> Void) throws {
        var coordinationError: NSError?
        var result: Result<Void, Error> = .success(())
        NSFileCoordinator(filePresenter: nil).coordinate(writingItemAt: url, options: options, error: &coordinationError) { safe in
            result = Result { try body(safe) }
        }
        if let coordinationError { throw coordinationError }
        try result.get()
    }

    /// The backups in this folder, newest first.
    func saved() -> [SavedBackup] { Self.saved(in: folder) }
    static func saved(in folder: URL) -> [SavedBackup] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        var found: [String: SavedBackup] = [:]
        for name in names {
            guard let date = Self.date(fromFileName: name) else { continue }
            let placeholder = realName(ofPlaceholder: name)
            let real = placeholder ?? name
            // A downloaded file wins over its placeholder.
            if placeholder != nil, found[real] != nil { continue }
            found[real] = SavedBackup(url: folder.appendingPathComponent(real), date: date, isPlaceholder: placeholder != nil)
        }
        return found.values.sorted { $0.date > $1.date }
    }

    /// Reads a saved backup, with the same size limit as a file chosen by hand. A backup that is still in iCloud is
    /// downloaded first; the coordinated read waits for it. The read happens off the main thread.
    static func load(_ saved: SavedBackup) async throws -> LibraryBackup {
        try await Task.detached { try read(saved) }.value
    }
    private static func read(_ saved: SavedBackup) throws -> LibraryBackup {
        let downloading = LocaliserError.invalidBackup("This backup is still downloading from iCloud. Try again in a moment.")
        if saved.isPlaceholder { try? FileManager.default.startDownloadingUbiquitousItem(at: saved.url) }
        var coordinationError: NSError?
        var result: Result<Data, Error> = .failure(downloading)
        NSFileCoordinator(filePresenter: nil).coordinate(readingItemAt: saved.url, options: [], error: &coordinationError) { safe in
            result = Result {
                let size = try safe.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                guard size <= LibraryBackup.maximumBytes else { throw LocaliserError.invalidBackup("Choose a backup under 200 MB.") }
                return try Data(contentsOf: safe)
            }
        }
        let data: Data
        do {
            if let coordinationError { throw coordinationError }
            data = try result.get()
        } catch let error as LocaliserError { throw error }
        catch { throw saved.isPlaceholder ? downloading : error }
        return try LibraryBackup.decoded(data)
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
    /// iCloud Drive's stand-in for a file that isn't downloaded: ".Hereabouts backup ….json.icloud".
    static func realName(ofPlaceholder name: String) -> String? {
        guard name.hasPrefix("."), name.hasSuffix(".icloud") else { return nil }
        return String(name.dropFirst().dropLast(".icloud".count))
    }
    static func placeholderURL(for url: URL) -> URL {
        url.deletingLastPathComponent().appendingPathComponent("." + url.lastPathComponent + ".icloud")
    }
    /// The date in a backup's name, whether it is the real file or its placeholder.
    static func date(fromFileName rawName: String) -> Date? {
        let name = realName(ofPlaceholder: rawName) ?? rawName
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
