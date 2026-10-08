import Foundation
import Vision
import PDFKit
import ImageIO
import UIKit
import UniformTypeIdentifiers

enum ScanError: LocalizedError {
    case tooLarge, tooManyPages, unreadable, lockedPDF
    var errorDescription: String? {
        switch self {
        case .tooLarge: "Choose a document under 20 MB or an image under 25 megapixels."
        case .tooManyPages: "Choose a document with at most ten pages."
        case .unreadable: "This document could not be read. Try a clear photo, a PDF, or enter the date manually."
        case .lockedPDF: "Unlock the PDF before importing it."
        }
    }
}

struct DateCandidate: Identifiable, Sendable {
    let id: String
    let raw: String
    let line: String
    let day: CalendarDay
    let hint: DeadlineKind?
    let ambiguous: Bool
}

struct ScanDraft: Sendable {
    let data: Data
    let filename: String
    let mime: String
    let preview: Data?
    let text: String
    let candidates: [DateCandidate]
}

enum ScanDates {
    static func candidates(_ text: String) -> [DateCandidate] {
        let pattern = #"\b(?:\d{4}-\d{1,2}-\d{1,2}|\d{1,2}[/-]\d{1,2}[/-]\d{2,4}|\d{1,2}\s+[A-Za-z]{3,9}\s+\d{4}|[A-Za-z]{3,9}\s+\d{1,2},?\s+\d{4})\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        return text.components(separatedBy: .newlines).enumerated().flatMap { index, line -> [DateCandidate] in
            let lower = line.lowercased()
            let hint: DeadlineKind? = lower.contains("expir") || lower.contains("valid until") ? .expiry : lower.contains("warranty") ? .warranty : lower.contains("return") ? .returns : nil
            return regex.matches(in: line, range: NSRange(line.startIndex..., in: line)).flatMap { match -> [DateCandidate] in
                guard let range = Range(match.range, in: line) else { return [] }
                let raw = String(line[range])
                let days = interpretations(raw)
                return days.map { day in DateCandidate(id: "\(index).\(match.range.location).\(day.stored)", raw: raw, line: line, day: day, hint: hint, ambiguous: days.count > 1) }
            }
        }
    }

    static func interpretations(_ raw: String) -> [CalendarDay] {
        if let day = CalendarDay(stored: raw), raw.first?.isNumber == true, raw.prefix(4).allSatisfy(\.isNumber) { return [day] }
        let parts = raw.split(whereSeparator: { $0 == "/" || $0 == "-" })
        if parts.count == 3, let a = Int(parts[0]), let b = Int(parts[1]), let yearRaw = Int(parts[2]) {
            // Two-digit years are displayed as provisional 2000–2099 interpretations for explicit review.
            let year = parts[2].count == 2 ? 2000 + yearRaw : yearRaw
            return [(a, b), (b, a)].compactMap { month, day in CalendarDay(stored: String(format: "%04d-%02d-%02d", year, month, day)) }.reduce(into: []) { result, day in if !result.contains(day) { result.append(day) } }
        }
        return ["d MMM yyyy", "d MMMM yyyy", "MMM d yyyy", "MMMM d yyyy", "MMM d, yyyy", "MMMM d, yyyy"].compactMap { format -> CalendarDay? in
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.dateFormat = format; formatter.isLenient = false
            guard let date = formatter.date(from: raw) else { return nil }
            return CalendarDay(date)
        }.reduce(into: []) { result, day in if !result.contains(day) { result.append(day) } }
    }
}

enum ScanReader {
    static let maximumBytes = 20 * 1024 * 1024

    static func read(data: Data, filename: String, mime: String) throws -> ScanDraft {
        guard !data.isEmpty else { throw ScanError.unreadable }
        guard data.count <= maximumBytes else { throw ScanError.tooLarge }
        var lines: [String] = []
        var preview: Data?
        var detectedMime = mime
        var retainedName = filename
        if mime == "application/pdf" {
            guard let document = PDFDocument(data: data) else { throw ScanError.unreadable }
            guard !document.isLocked else { throw ScanError.lockedPDF }
            guard document.pageCount > 0, document.pageCount <= 10 else { throw ScanError.tooManyPages }
            for index in 0..<document.pageCount {
                guard let page = document.page(at: index) else { throw ScanError.unreadable }
                let bounds = page.bounds(for: .mediaBox)
                guard bounds.width.isFinite, bounds.height.isFinite, bounds.width > 0, bounds.height > 0 else { throw ScanError.unreadable }
                let image = page.thumbnail(of: CGSize(width: 1600, height: 1600), for: .mediaBox)
                if preview == nil { preview = image.jpegData(compressionQuality: 0.7) }
                let native = page.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if !native.isEmpty { lines.append(String(native.prefix(100_000))) }
                else if let cgImage = image.cgImage { lines.append(try recognize(cgImage)) }
            }
        } else {
            guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
                  let width = properties[kCGImagePropertyPixelWidth] as? Int,
                  let height = properties[kCGImagePropertyPixelHeight] as? Int else { throw ScanError.unreadable }
            guard width > 0, height > 0, width <= 25_000_000 / height else { throw ScanError.tooLarge }
            if let typeID = CGImageSourceGetType(source), let type = UTType(typeID as String) {
                detectedMime = type.preferredMIMEType ?? "application/octet-stream"
                if filename == "Photo.jpg", let ext = type.preferredFilenameExtension { retainedName = "Photo.\(ext)" }
            }
            let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceCreateThumbnailWithTransform: true, kCGImageSourceThumbnailMaxPixelSize: 1600]
            guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { throw ScanError.unreadable }
            lines.append(try recognize(image)); preview = UIImage(cgImage: image).jpegData(compressionQuality: 0.7)
        }
        let text = lines.joined(separator: "\n\n")
        return ScanDraft(data: data, filename: retainedName, mime: detectedMime, preview: preview, text: text, candidates: ScanDates.candidates(text))
    }

    private static func recognize(_ image: CGImage) throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate; request.usesLanguageCorrection = true
        request.recognitionLanguages = ["en-US"]
        try VNImageRequestHandler(cgImage: image).perform([request])
        return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
    }
}
