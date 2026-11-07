import Foundation
import Vision
import ImageIO

enum PhotoError: LocalizedError {
    case tooLarge, unreadable
    var errorDescription: String? {
        switch self {
        case .tooLarge: "Choose a photo under 20 MB or 25 megapixels."
        case .unreadable: "This photo couldn't be read."
        }
    }
}

/// Text in a photo of a thing, read on the device. Used for name ideas.
enum PhotoText {
    static func read(_ data: Data) throws -> String {
        guard !data.isEmpty else { throw PhotoError.unreadable }
        guard data.count <= LibraryBackup.maximumFileBytes else { throw PhotoError.tooLarge }
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int else { throw PhotoError.unreadable }
        guard width > 0, height > 0, width <= 25_000_000 / height else { throw PhotoError.tooLarge }
        let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceCreateThumbnailWithTransform: true, kCGImageSourceThumbnailMaxPixelSize: 1600]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { throw PhotoError.unreadable }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate; request.usesLanguageCorrection = true
        // Read in the person's own languages first, then English.
        let supported = (try? request.supportedRecognitionLanguages()) ?? ["en-US"]
        let preferred = Locale.preferredLanguages.compactMap { language in
            supported.first { $0 == language } ?? supported.first { $0.hasPrefix(String(language.prefix(2))) }
        }
        var languages: [String] = []
        for language in preferred + ["en-US"] where !languages.contains(language) { languages.append(language) }
        request.recognitionLanguages = languages
        try VNImageRequestHandler(cgImage: image).perform([request])
        return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
    }

    /// True when the line holds something shaped like a date, which makes a poor name.
    static func containsDate(_ line: String) -> Bool {
        let pattern = #"\b(?:\d{4}-\d{1,2}-\d{1,2}|\d{1,2}[/-]\d{1,2}[/-]\d{2,4}|\d{1,2}\.?\s+\p{L}{3,10}\.?\s+\d{4}|\p{L}{3,10}\.?\s+\d{1,2},?\s+\d{4})\b"#
        return line.range(of: pattern, options: .regularExpression) != nil
    }
}
