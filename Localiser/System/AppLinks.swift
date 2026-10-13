import SwiftUI
import UIKit

/// The app's own links: hereabouts://find, hereabouts://new, hereabouts://putaway, hereabouts://due and
/// hereabouts://item/<id>. Used by app icon shortcuts, the widget and the controls. Box labels carry
/// hereabouts://place/<id>.
enum AppLink: Equatable {
    case find, new, putAway, due
    case item(UUID)
    case place(UUID)

    init?(url: URL) {
        guard url.scheme == "hereabouts" else { return nil }
        switch url.host() {
        case "find": self = .find
        case "new": self = .new
        case "putaway": self = .putAway
        case "due": self = .due
        case "item":
            guard let id = UUID(uuidString: url.lastPathComponent) else { return nil }
            self = .item(id)
        case "place":
            guard let id = UUID(uuidString: url.lastPathComponent) else { return nil }
            self = .place(id)
        default: return nil
        }
    }

    var url: URL {
        switch self {
        case .find: URL(string: "hereabouts://find")!
        case .new: URL(string: "hereabouts://new")!
        case .putAway: URL(string: "hereabouts://putaway")!
        case .due: URL(string: "hereabouts://due")!
        case .item(let id): URL(string: "hereabouts://item/\(id.uuidString)")!
        case .place(let id): URL(string: "hereabouts://place/\(id.uuidString)")!
        }
    }
}

/// App icon shortcuts arrive through the scene delegate; the root view picks them up from here.
@MainActor @Observable final class QuickActions {
    static let shared = QuickActions()
    var link: AppLink?

    /// The shortcut types in Info.plist are the links themselves. They're fixed, so nothing private shows.
    @discardableResult func handle(_ item: UIApplicationShortcutItem) -> Bool {
        guard let url = URL(string: item.type), let link = AppLink(url: url) else { return false }
        self.link = link
        return true
    }
}

final class HereaboutsAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = HereaboutsSceneDelegate.self
        return configuration
    }
}

final class HereaboutsSceneDelegate: NSObject, UIWindowSceneDelegate {
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let item = connectionOptions.shortcutItem else { return }
        MainActor.assumeIsolated { _ = QuickActions.shared.handle(item) }
    }

    func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        completionHandler(MainActor.assumeIsolated { QuickActions.shared.handle(shortcutItem) })
    }
}

extension Belonging {
    /// What "Send where it is" sends: "Spare key is in Hall › Key bowl." Nil when there's nothing to say.
    var whereItIsSentence: String? {
        if isLent { return "\(name) is with \(lentTo)." }
        guard let place else { return nil }
        return "\(name) is in \(place.path)."
    }
}
