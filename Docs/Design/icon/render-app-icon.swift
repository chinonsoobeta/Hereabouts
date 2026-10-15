// Draws the Hereabouts app icon, B1 "Circled stamp", into the AppIcon set: a purple HERE stamp
// tilted 8 degrees, circled by a marigold pen loop, on paper (light) or night (dark).
// Geometry is in the 1024-unit, y-down space of the design canvas's SVG, so the two match.
// Run from the repository root: swift Docs/Design/icon/render-app-icon.swift
import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct Palette {
    let ground: CGColor
    let stamp: CGColor
    let loop: CGColor
    let dot: CGColor
}

func colour(_ hex: UInt32) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
}

let purple = colour(0x5B3DB8)
let marigold = colour(0xF4A63A)
let light = Palette(ground: colour(0xF6F1E9), stamp: purple, loop: marigold, dot: marigold)
let dark = Palette(ground: colour(0x15111C), stamp: colour(0xB59CF5), loop: marigold, dot: marigold)

let fontURL = URL(fileURLWithPath: "Localiser/Design/Fonts/AtkinsonHyperlegible-Bold.ttf")
guard let descriptors = CTFontManagerCreateFontDescriptorsFromURL(fontURL as CFURL) as? [CTFontDescriptor],
      let descriptor = descriptors.first else {
    fatalError("Run from the repository root; Atkinson Hyperlegible Bold wasn't found.")
}
let font = CTFontCreateWithFontDescriptor(descriptor, 176, nil)

func loopPath() -> CGPath {
    // M770 286 C600 214 300 222 178 336 C92 416 104 640 290 730 C470 816 780 800 890 680
    // C966 598 940 380 812 300 C770 274 720 262 668 258
    let path = CGMutablePath()
    path.move(to: CGPoint(x: 770, y: 286))
    path.addCurve(to: CGPoint(x: 178, y: 336), control1: CGPoint(x: 600, y: 214), control2: CGPoint(x: 300, y: 222))
    path.addCurve(to: CGPoint(x: 290, y: 730), control1: CGPoint(x: 92, y: 416), control2: CGPoint(x: 104, y: 640))
    path.addCurve(to: CGPoint(x: 890, y: 680), control1: CGPoint(x: 470, y: 816), control2: CGPoint(x: 780, y: 800))
    path.addCurve(to: CGPoint(x: 812, y: 300), control1: CGPoint(x: 966, y: 598), control2: CGPoint(x: 940, y: 380))
    path.addCurve(to: CGPoint(x: 668, y: 258), control1: CGPoint(x: 770, y: 274), control2: CGPoint(x: 720, y: 262))
    return path
}

/// HERE, centred on x 494 with its baseline at 571 and 12 units between letters, like the SVG text.
func wordPath() -> CGPath {
    let attributes: [NSAttributedString.Key: Any] = [
        NSAttributedString.Key(kCTFontAttributeName as String): font,
        NSAttributedString.Key(kCTKernAttributeName as String): 12,
    ]
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: "HERE", attributes: attributes))
    let startX = 494 - CTLineGetTypographicBounds(line, nil, nil, nil) / 2
    let path = CGMutablePath()
    for run in CTLineGetGlyphRuns(line) as! [CTRun] {
        let count = CTRunGetGlyphCount(run)
        var glyphs = [CGGlyph](repeating: 0, count: count)
        var positions = [CGPoint](repeating: .zero, count: count)
        CTRunGetGlyphs(run, CFRange(location: 0, length: count), &glyphs)
        CTRunGetPositions(run, CFRange(location: 0, length: count), &positions)
        for index in 0..<count {
            guard let outline = CTFontCreatePathForGlyph(font, glyphs[index], nil) else { continue }
            // Glyph outlines point y up; the icon space points y down.
            let place = CGAffineTransform(translationX: startX + positions[index].x, y: 571).scaledBy(x: 1, y: -1)
            path.addPath(outline, transform: place)
        }
    }
    return path
}

func render(_ palette: Palette, to url: URL) {
    // No alpha channel: App Store icons must be opaque.
    guard let context = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
        fatalError("Couldn't make a drawing context.")
    }
    context.translateBy(x: 0, y: 1024)
    context.scaleBy(x: 1, y: -1)

    context.setFillColor(palette.ground)
    context.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024))

    context.setLineCap(.round)
    context.setLineJoin(.round)
    context.setStrokeColor(palette.loop)
    context.setLineWidth(46)
    context.addPath(loopPath())
    context.strokePath()

    // The stamp: rotate(-8 512 512).
    context.translateBy(x: 512, y: 512)
    context.rotate(by: -8 * .pi / 180)
    context.translateBy(x: -512, y: -512)
    context.setStrokeColor(palette.stamp)
    context.setLineWidth(34)
    context.addPath(CGPath(roundedRect: CGRect(x: 162, y: 362, width: 700, height: 300),
                           cornerWidth: 40, cornerHeight: 40, transform: nil))
    context.strokePath()
    context.setLineWidth(11)
    context.addPath(CGPath(roundedRect: CGRect(x: 204, y: 404, width: 616, height: 216),
                           cornerWidth: 18, cornerHeight: 18, transform: nil))
    context.strokePath()
    context.setFillColor(palette.stamp)
    context.addPath(wordPath())
    context.fillPath()
    context.setFillColor(palette.dot)
    context.fillEllipse(in: CGRect(x: 756 - 22, y: 549 - 22, width: 44, height: 44))

    guard let image = context.makeImage(),
          let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        fatalError("Couldn't write \(url.path).")
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { fatalError("Couldn't write \(url.path).") }
    print("Wrote \(url.path)")
}

let iconSet = URL(fileURLWithPath: "Localiser/Assets.xcassets/AppIcon.appiconset")
render(light, to: iconSet.appendingPathComponent("AppIcon.png"))
render(dark, to: iconSet.appendingPathComponent("AppIcon-Dark.png"))
