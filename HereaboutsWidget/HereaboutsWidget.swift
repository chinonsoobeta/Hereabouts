import AppIntents
import SwiftUI
import WidgetKit

/// Home screen and Lock Screen buttons. They only open the app and read nothing from the notebook.
@main
struct HereaboutsWidgets: WidgetBundle {
    var body: some Widget { FindButtonsWidget(); LentOutWidget() }
}

struct ButtonsEntry: TimelineEntry { let date: Date }

struct ButtonsProvider: TimelineProvider {
    func placeholder(in context: Context) -> ButtonsEntry { ButtonsEntry(date: .now) }
    func getSnapshot(in context: Context, completion: @escaping (ButtonsEntry) -> Void) { completion(ButtonsEntry(date: .now)) }
    /// Nothing changes with time. The buttons check the phone's language each time they're drawn.
    func getTimeline(in context: Context, completion: @escaping (Timeline<ButtonsEntry>) -> Void) {
        completion(Timeline(entries: [ButtonsEntry(date: .now)], policy: .never))
    }
}

struct FindButtonsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "dev.hereabouts.app.widget.buttons", provider: ButtonsProvider()) { _ in
            ButtonsView().containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Find and say where")
        .description("Find a thing or say where you put it.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular])
    }
}

struct ButtonsView: View {
    @Environment(\.widgetFamily) private var family
    private var voice: Bool { WidgetButtons.voiceWorks() }

    var body: some View {
        switch family {
        case .accessoryCircular:
            // One tap target on the Lock Screen's circle, so it's Find.
            ZStack { AccessoryWidgetBackground(); Image(systemName: "magnifyingglass").font(.title2) }
                .widgetURL(WidgetButtons.find)
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 4) {
                ButtonRow(title: "Find", symbol: "magnifyingglass", url: WidgetButtons.find)
                if voice { ButtonRow(title: "Say where", symbol: "mic", url: WidgetButtons.say) }
            }
        default:
            VStack(spacing: 8) {
                ButtonRow(title: "Find", symbol: "magnifyingglass", url: WidgetButtons.find, prominent: true)
                if voice { ButtonRow(title: "Say where", symbol: "mic", url: WidgetButtons.say, prominent: true) }
            }
        }
    }
}

/// A button that opens one of the app's links.
struct ButtonRow: View {
    let title: LocalizedStringKey
    let symbol: String
    let url: URL
    var prominent = false

    var body: some View {
        Button(intent: OpenURLIntent(url)) {
            Label(title, systemImage: symbol)
                .font(prominent ? .headline : .caption.weight(.semibold))
                .frame(maxWidth: .infinity, maxHeight: prominent ? .infinity : nil, alignment: prominent ? .center : .leading)
        }
        .buttonStyle(.plain)
        .background(prominent ? AnyShapeStyle(.fill.secondary) : AnyShapeStyle(.clear), in: RoundedRectangle(cornerRadius: 12))
    }
}
