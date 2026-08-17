import AppKit
import CoreGraphics
import Foundation

// Renders the favicons and social preview image for the landing page.
// Compiled together with Sources/MacNoSleep/IconArtwork.swift by site/build.sh.
//
//   generate-site-assets <output-directory>

@main
enum GenerateSiteAssets {
    static func main() throws {
        let directory = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "site/assets"
        let outputURL = URL(fileURLWithPath: directory)
        try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)

        for size in [512, 180, 64, 32] {
            let image = try render(width: size, height: size) { context in
                IconArtwork.draw(in: context, canvas: CGFloat(size), insetFraction: 0)
            }
            try write(image, to: outputURL.appendingPathComponent("icon-\(size).png"))
        }

        let social = try render(width: 1200, height: 630, drawSocialPreview)
        try write(social, to: outputURL.appendingPathComponent("og.png"))

        print("Wrote site assets to \(outputURL.path)")
    }

    private static func drawSocialPreview(in context: CGContext) {
        let bounds = CGRect(x: 0, y: 0, width: 1200, height: 630)
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!

        let background = CGGradient(
            colorsSpace: colorSpace,
            colors: [
                CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1),
                CGColor(srgbRed: 0.99, green: 0.96, blue: 0.93, alpha: 1),
            ] as CFArray,
            locations: [0, 1]
        )!
        context.drawLinearGradient(
            background,
            start: CGPoint(x: 0, y: bounds.maxY),
            end: CGPoint(x: bounds.maxX, y: 0),
            options: []
        )

        let glow = CGGradient(
            colorsSpace: colorSpace,
            colors: [
                CGColor(srgbRed: 0.98, green: 0.57, blue: 0.24, alpha: 0.26),
                CGColor(srgbRed: 0.98, green: 0.57, blue: 0.24, alpha: 0),
            ] as CFArray,
            locations: [0, 1]
        )!
        let glowCentre = CGPoint(x: 300, y: 470)
        context.drawRadialGradient(
            glow,
            startCenter: glowCentre,
            startRadius: 0,
            endCenter: glowCentre,
            endRadius: 560,
            options: []
        )

        context.saveGState()
        context.translateBy(x: 96, y: 315 - 96)
        IconArtwork.draw(in: context, canvas: 192, insetFraction: 0)
        context.restoreGState()

        draw(
            "MacNoSleep",
            at: CGPoint(x: 328, y: 336),
            font: .systemFont(ofSize: 82, weight: .bold),
            color: NSColor(srgbRed: 0.09, green: 0.06, blue: 0.20, alpha: 1),
            in: context
        )
        draw(
            "Keep your Mac awake.",
            at: CGPoint(x: 332, y: 268),
            font: .systemFont(ofSize: 40, weight: .medium),
            color: NSColor(srgbRed: 0.34, green: 0.31, blue: 0.43, alpha: 1),
            in: context
        )
        draw(
            "A tiny macOS menu bar utility · Free · Universal",
            at: CGPoint(x: 334, y: 214),
            font: .systemFont(ofSize: 24, weight: .regular),
            color: NSColor(srgbRed: 0.52, green: 0.49, blue: 0.61, alpha: 1),
            in: context
        )
    }

    private static func draw(
        _ text: String,
        at origin: CGPoint,
        font: NSFont,
        color: NSColor,
        in context: CGContext
    ) {
        let previous = NSGraphicsContext.current
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        defer { NSGraphicsContext.current = previous }

        NSAttributedString(
            string: text,
            attributes: [.font: font, .foregroundColor: color]
        ).draw(at: origin)
    }

    private static func render(
        width: Int,
        height: Int,
        _ body: (CGContext) -> Void
    ) throws -> CGImage {
        guard
            let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        else { throw NSError(domain: "GenerateSiteAssets", code: 1) }

        context.interpolationQuality = .high
        body(context)

        guard let image = context.makeImage() else {
            throw NSError(domain: "GenerateSiteAssets", code: 2)
        }
        return image
    }

    private static func write(_ image: CGImage, to url: URL) throws {
        let representation = NSBitmapImageRep(cgImage: image)
        representation.size = NSSize(width: image.width, height: image.height)
        guard let data = representation.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "GenerateSiteAssets", code: 3)
        }
        try data.write(to: url)
    }
}
