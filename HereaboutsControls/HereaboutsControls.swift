import AppIntents
import SwiftUI
import WidgetKit

/// Control Centre and Lock Screen buttons. They only open the app and read nothing from the notebook.
@main
struct HereaboutsControls: WidgetBundle {
    var body: some Widget { PutAwayControl() }
}

struct PutAwayControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "dev.hereabouts.app.controls.putaway") {
            ControlWidgetButton(action: PutAwayIntent()) {
                Label("Put away", systemImage: "tray.and.arrow.down")
            }
        }
        .displayName("Put something away")
        .description("Opens Hereabouts on the camera.")
    }
}
