import Foundation
import UIKit

/// Public links and contact details. Values come from Info.plist, set in project.yml,
/// so the website and support address can change without touching code.
enum Support {
    private static func value(_ key: String, _ fallback: String) -> String {
        let raw = Bundle.main.object(forInfoDictionaryKey: key) as? String ?? ""
        return raw.isEmpty || raw.hasPrefix("$(") ? fallback : raw
    }
    static var site: URL { URL(string: value("HereaboutsSiteURL", "https://hereabouts.app"))! }
    static var privacy: URL { site.appendingPathComponent("privacy") }
    static var terms: URL { URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")! }
    static var supportPage: URL { site.appendingPathComponent("support") }
    static var email: String { value("HereaboutsSupportEmail", "support@hereabouts.app") }

    static var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }

    /// A pre-filled feedback email with the app and system versions, and nothing from the library.
    @MainActor static func mail(subject: String, body: String = "") -> URL {
        let device = "\n\n—\nHereabouts \(version) · iOS \(UIDevice.current.systemVersion)"
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = email
        components.queryItems = [URLQueryItem(name: "subject", value: subject), URLQueryItem(name: "body", value: body + device)]
        return components.url ?? URL(string: "mailto:\(email)")!
    }
}
