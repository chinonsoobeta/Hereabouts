import XCTest
@testable import Localiser

/// Every catalog entry is translated in every shipped language, keeps the same format specifiers
/// as English, and keeps the names that never translate.
final class LocalizationTests: XCTestCase {
    static let languages = ["en-GB", "fr", "es", "pt-BR"]
    static let catalogs = ["Localiser/Localizable.xcstrings", "Localiser/InfoPlist.xcstrings", "Localiser/AppShortcuts.xcstrings",
                           "HereaboutsWidget/Localizable.xcstrings", "HereaboutsControls/Localizable.xcstrings"]

    private struct Entry { let catalog: String; let key: String; let english: [String: String]; let translations: [String: [String: String]] }

    private static var root: URL { URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent() }

    /// Values of one localization: "" for a plain string, or the plural category names.
    /// A string that varies by device is read as it is on iPhone ("other"); `device: "ipad"` reads the iPad text.
    private static func values(_ localization: [String: Any]?, device: String = "other") -> [String: String]? {
        guard let localization else { return nil }
        if let byDevice = (localization["variations"] as? [String: Any])?["device"] as? [String: Any] {
            // A plural string keeps its forms under "iphone" and "ipad", with a plain "other" as the fallback.
            let choice = device == "ipad" ? byDevice["ipad"] : byDevice["iphone"] ?? byDevice["other"]
            return values(choice as? [String: Any], device: device)
        }
        if let unit = localization["stringUnit"] as? [String: Any] {
            guard unit["state"] as? String == "translated", let value = unit["value"] as? String else { return nil }
            return ["": value]
        }
        if let plural = (localization["variations"] as? [String: Any])?["plural"] as? [String: Any] {
            var out: [String: String] = [:]
            for (category, body) in plural {
                // The device variation sits inside each plural category.
                guard let text = values(body as? [String: Any], device: device)?[""] else { return nil }
                out[category] = text
            }
            return out
        }
        return nil
    }

    /// Whether a localization varies by device, at its top or inside its plural categories.
    private static func variesByDevice(_ localization: [String: Any]?) -> Bool {
        guard let variations = localization?["variations"] as? [String: Any] else { return false }
        if variations["device"] != nil { return true }
        return (variations["plural"] as? [String: Any])?.values.contains { variesByDevice($0 as? [String: Any]) } ?? false
    }

    private func entries() throws -> [Entry] {
        var result: [Entry] = []
        for catalog in Self.catalogs {
            let data = try Data(contentsOf: Self.root.appendingPathComponent(catalog))
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
            let strings = try XCTUnwrap(json["strings"] as? [String: [String: Any]])
            for (key, body) in strings where body["shouldTranslate"] as? Bool != false {
                let locs = body["localizations"] as? [String: [String: Any]] ?? [:]
                let english = Self.values(locs["en"]) ?? ["": key]
                var translations: [String: [String: String]] = [:]
                for language in Self.languages { translations[language] = Self.values(locs[language]) }
                result.append(Entry(catalog: catalog, key: key, english: english, translations: translations))
            }
        }
        return result
    }

    private static func specifiers(_ text: String) -> [String] {
        let regex = try! NSRegularExpression(pattern: "%(?:\\d+\\$)?(?:lld|ld|d|@|f|%)")
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).map { match -> String in
            // Positional and plain forms of the same specifier count as the same.
            String(text[Range(match.range, in: text)!]).replacingOccurrences(of: "\\d+\\$", with: "", options: .regularExpression)
        }.sorted()
    }

    func testEveryEntryIsTranslatedInEveryLanguage() throws {
        let all = try entries()
        XCTAssertGreaterThan(all.count, 700)
        for language in Self.languages {
            let missing = all.filter { $0.translations[language] == nil }.map { "\($0.catalog): \($0.key)" }
            XCTAssertEqual(missing, [], "\(language) is missing \(missing.count) entries")
        }
    }

    func testFormatSpecifiersMatchEnglish() throws {
        for entry in try entries() {
            let english = Self.specifiers(entry.english["other"] ?? entry.english[""] ?? entry.key)
            for language in Self.languages {
                guard let values = entry.translations[language] else { continue }
                for (category, value) in values {
                    let found = Self.specifiers(value)
                    if category == "one" {
                        // The singular may spell out the number instead of showing it.
                        XCTAssertTrue(found == english || found == english.filter { $0 != "%lld" },
                                      "\(language) \(entry.key) [one]: \(value)")
                    } else {
                        XCTAssertEqual(found, english, "\(language) \(entry.key): \(value)")
                    }
                }
            }
        }
    }

    func testSiriPhrasesKeepTheAppNameAndParameters() throws {
        for entry in try entries() where entry.catalog.hasSuffix("AppShortcuts.xcstrings") {
            for language in Self.languages {
                let value = try XCTUnwrap(entry.translations[language]?[""], "\(language) \(entry.key)")
                XCTAssertTrue(value.contains("${applicationName}"), "\(language) \(entry.key): \(value)")
                for parameter in ["${thing}", "${place}", "${name}"] where entry.key.contains(parameter) {
                    XCTAssertTrue(value.contains(parameter), "\(language) \(entry.key): \(value)")
                }
            }
        }
    }

    func testHereaboutsAndProAreNeverTranslated() throws {
        for entry in try entries() {
            let english = entry.english[""] ?? entry.english["other"] ?? entry.key
            for language in Self.languages {
                guard let values = entry.translations[language] else { continue }
                for name in ["Hereabouts", "Pro"] where english.range(of: "\\b\(name)\\b", options: .regularExpression) != nil {
                    XCTAssertTrue(values.values.allSatisfy { $0.contains(name) }, "\(language) \(entry.key) drops \(name)")
                }
            }
        }
    }

    /// Text that names the iPhone reads "iPad" on an iPad, in every language, with the same format specifiers.
    func testIPadTextNamesTheIPadInEveryLanguage() throws {
        var varied = 0
        for catalog in Self.catalogs {
            let data = try Data(contentsOf: Self.root.appendingPathComponent(catalog))
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
            let strings = try XCTUnwrap(json["strings"] as? [String: [String: Any]])
            for (key, body) in strings where body["shouldTranslate"] as? Bool != false {
                let locs = body["localizations"] as? [String: [String: Any]] ?? [:]
                let onIPhone = Self.values(locs["en"]) ?? ["": key]
                let namesIPhone = onIPhone.values.contains { $0.contains("iPhone") || $0.contains("this phone") || $0.contains("another phone") }
                for language in ["en"] + Self.languages {
                    if !namesIPhone && !Self.variesByDevice(locs[language]) { continue }
                    let ipad = try XCTUnwrap(Self.values(locs[language], device: "ipad"), "\(catalog) \(language) has no iPad text for \(key)")
                    let other = try XCTUnwrap(Self.values(locs[language]), "\(catalog) \(language) has no iPhone text for \(key)")
                    XCTAssertTrue(Self.variesByDevice(locs[language]), "\(catalog) \(language) \(key) doesn't vary by device")
                    XCTAssertEqual(Set(ipad.keys), Set(other.keys), "\(language) \(key)")
                    for (category, text) in ipad {
                        XCTAssertNotEqual(text, other[category], "\(language) \(key) reads the same on iPad")
                        if key.contains("iPhone") { XCTAssertTrue(text.contains("iPad"), "\(language) \(key): \(text)") }
                        XCTAssertEqual(Self.specifiers(text), Self.specifiers(other[category] ?? ""), "\(language) \(key): \(text)")
                        if !key.hasPrefix("Scan with your iPhone camera") { XCTAssertFalse(text.contains("iPhone"), "\(language) \(key): \(text)") }
                    }
                }
                if locs.values.contains(where: { Self.variesByDevice($0) }) { varied += 1 }
            }
        }
        XCTAssertEqual(varied, 15, "13 strings that name the iPhone and 2 that say phone; the camera prompt says device, because the system reads it without device variations")
    }

    func testRoomIconsMatchEveryLanguage() {
        let cases: [(String, String)] = [
            ("Cuisine", "fork.knife"), ("Cocina", "fork.knife"), ("Cozinha", "fork.knife"), ("Kitchen", "fork.knife"),
            ("Chambre", "bed.double"), ("Habitación", "bed.double"), ("habitacion", "bed.double"), ("Quarto", "bed.double"),
            ("Salle de bain", "shower"), ("Baño", "shower"), ("Banheiro", "shower"),
            ("Bureau", "desktopcomputer"), ("Escritório", "desktopcomputer"), ("Placard", "hanger"), ("Armário", "hanger"),
            ("Entrée", "door.left.hand.closed"), ("entree", "door.left.hand.closed"), ("Pasillo", "door.left.hand.closed"),
            ("Salon", "sofa"), ("Sala", "sofa"), ("Sous-sol", "stairs"), ("Sótano", "stairs"), ("Porão", "stairs"),
            ("Grenier", "house"), ("Desván", "house"), ("Ático", "house"), ("Sótão", "house"),
            ("Tiroir", "rectangle.split.1x2"), ("Cajón", "rectangle.split.1x2"), ("Gaveta", "rectangle.split.1x2"),
            ("Étagère", "books.vertical"), ("Estante", "books.vertical"), ("Prateleira", "books.vertical"),
            ("Carton", "shippingbox"), ("Boîte", "shippingbox"), ("Caja", "shippingbox"), ("Caixa", "shippingbox"),
            ("Voiture", "car"), ("Coche", "car"), ("Carro", "car"), ("Car", "car"), ("Carnet", "square.grid.2x2"),
            ("Hall closet", "hanger"), ("Hall cupboard", "hanger"), ("Wardrobe", "hanger"),
        ]
        for (name, symbol) in cases { XCTAssertEqual(PlaceTile.symbol(for: name), symbol, name) }
    }

    func testSearchIgnoresAccents() {
        XCTAssertNotNil(ItemSearch.score(query: "cafe", name: "Café", aliases: "", place: "", notes: ""))
        XCTAssertNotNil(ItemSearch.score(query: "PERCEUSE", name: "perceuse", aliases: "", place: "", notes: ""))
        XCTAssertNotNil(ItemSearch.score(query: "lampara", name: "Lámpara", aliases: "", place: "", notes: ""))
    }
}
