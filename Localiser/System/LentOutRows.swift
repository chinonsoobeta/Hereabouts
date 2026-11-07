import Foundation
import SQLite3

/// One lent-out thing, as the widget needs it. Plain Foundation only: the app and the widget both
/// compile this file, so the rows are built one way.
struct LentOutRecord: Equatable, Sendable {
    var name: String
    var isPrivate: Bool
    var person: String
    var since: Date
    /// The ask-back day as stored, "2026-11-12", if one was set.
    var askBackDay: String?
}

struct LentOutRow: Equatable, Identifiable, Sendable {
    var id: Int
    var title: String
    var person: String
    var sinceText: String
    var askBackText: String?
}

enum LentOutRows {
    /// The widget's kind, for `WidgetCenter.reloadTimelines(ofKind:)`.
    static let widgetKind = "dev.hereabouts.app.widget.lentout"
    static let privateName = "A private thing"
    /// What fits in a medium widget.
    static let fits = 4

    /// Newest first, at most `limit`. A private thing shows as "A private thing"; who has it still shows.
    static func rows(_ records: [LentOutRecord], limit: Int = fits, locale: Locale = .current, calendar: Calendar = .current) -> [LentOutRow] {
        func written(_ date: Date) -> String { date.formatted(Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone).month(.abbreviated).day()) }
        let newest = records.sorted { $0.since != $1.since ? $0.since > $1.since : $0.name < $1.name }.prefix(limit)
        return newest.enumerated().map { index, record in
            LentOutRow(id: index,
                       title: record.isPrivate || record.name.isEmpty ? privateName : record.name,
                       person: record.person,
                       sinceText: "Since \(written(record.since))",
                       askBackText: askBackDate(record.askBackDay, calendar: calendar).map { "Ask for it back \(written($0))" })
        }
    }

    private static func askBackDate(_ stored: String?, calendar: Calendar) -> Date? {
        guard let parts = stored?.split(separator: "-", omittingEmptySubsequences: false).map({ Int($0) }), parts.count == 3,
              let year = parts[0], let month = parts[1], let day = parts[2] else { return nil }
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = calendar.timeZone
        guard let date = gregorian.date(from: DateComponents(year: year, month: month, day: day, hour: 12)),
              gregorian.component(.day, from: date) == day, gregorian.component(.month, from: date) == month else { return nil }
        return date
    }
}

/// Reads who has what out of the notebook file. The widget calls this; it opens the file read-only
/// and never writes. A private thing's name is not read at all.
enum LentOutReader {
    static func records(at url: URL) -> [LentOutRecord] {
        var db: OpaquePointer?
        guard sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK, let db else { sqlite3_close(db); return [] }
        defer { sqlite3_close(db) }
        let sql = """
            SELECT CASE WHEN b.ZISPRIVATE THEN '' ELSE b.ZNAME END, b.ZISPRIVATE, b.ZLENTTO, b.ZLENTAT,
                   (SELECT MIN(d.ZDAYSTRING) FROM ZDEADLINE d WHERE d.ZITEM = b.Z_PK AND d.ZKINDRAW = 'askBack' AND d.ZDECISIONRAW = 'open')
            FROM ZBELONGING b
            WHERE b.ZLENTTO IS NOT NULL AND b.ZLENTTO != '' AND b.ZLENTAT IS NOT NULL AND b.ZARCHIVED = 0
            ORDER BY b.ZLENTAT DESC
            """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(statement) }
        func text(_ column: Int32) -> String? { sqlite3_column_text(statement, column).map { String(cString: $0) } }
        var records: [LentOutRecord] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            records.append(LentOutRecord(name: text(0) ?? "", isPrivate: sqlite3_column_int(statement, 1) != 0, person: text(2) ?? "",
                                         since: Date(timeIntervalSinceReferenceDate: sqlite3_column_double(statement, 3)), askBackDay: text(4)))
        }
        return records
    }

    /// Where the widget finds the notebook: the App Group folder, the same file the app moves it to.
    static func groupStoreURL(group: String) -> URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)?.appendingPathComponent("Library/Application Support/Localiser.sqlite")
    }
}
