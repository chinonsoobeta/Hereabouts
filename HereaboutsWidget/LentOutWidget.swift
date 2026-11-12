import SwiftUI
import WidgetKit

/// Who has what. Medium size. It reads the notebook from the App Group, read-only, and never writes.
struct LentOutEntry: TimelineEntry {
    let date: Date
    let rows: [LentOutRow]
}

struct LentOutProvider: TimelineProvider {
    private func entry() -> LentOutEntry {
        let group = (Bundle.main.object(forInfoDictionaryKey: "HereaboutsAppGroup") as? String) ?? ""
        let records = LentOutReader.groupStoreURL(group: group).map(LentOutReader.records(at:)) ?? []
        return LentOutEntry(date: .now, rows: LentOutRows.rows(records))
    }

    func placeholder(in context: Context) -> LentOutEntry {
        LentOutEntry(date: .now, rows: LentOutRows.rows([
            LentOutRecord(name: String(localized: "Drill"), isPrivate: false, person: "Sam", since: .now, askBackDay: nil),
        ]))
    }
    func getSnapshot(in context: Context, completion: @escaping (LentOutEntry) -> Void) { completion(entry()) }
    /// The app reloads this after every save; the hourly refresh covers changes made anywhere else.
    func getTimeline(in context: Context, completion: @escaping (Timeline<LentOutEntry>) -> Void) {
        completion(Timeline(entries: [entry()], policy: .after(.now.addingTimeInterval(3_600))))
    }
}

struct LentOutWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: LentOutRows.widgetKind, provider: LentOutProvider()) { entry in
            LentOutView(entry: entry)
                .widgetURL(WidgetButtons.lent)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Lent out")
        .description("See who has it, since when, and when to ask for it back.")
        .supportedFamilies([.systemMedium])
    }
}

struct LentOutView: View {
    let entry: LentOutEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Lent out", systemImage: "arrow.uturn.right").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            if entry.rows.isEmpty {
                Spacer()
                Text("Nothing is lent out.").font(.headline)
                Text("You'll see things you lend here.").font(.caption).foregroundStyle(.secondary)
                Spacer()
            } else {
                ForEach(entry.rows) { row in
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Text(row.title).font(.subheadline.weight(.semibold)).lineLimit(1)
                            Spacer(minLength: 4)
                            Text(row.person).font(.subheadline).lineLimit(1)
                        }
                        Text([row.sinceText, row.askBackText].compactMap { $0 }.joined(separator: " · "))
                            .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }
}
