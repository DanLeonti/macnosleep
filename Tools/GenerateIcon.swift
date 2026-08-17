import AppKit
import CoreGraphics
import Foundation

// Renders the MacNoSleep app icon into an .iconset directory.
// Compiled together with Sources/MacNoSleep/IconArtwork.swift by build.sh.
//
//   generate-icon <output.iconset> [--strike none|marks|full]

@main
enum GenerateIcon {
    static let variants: [(name: String, size: CGFloat)] = [
        ("icon_16x16", 16), ("icon_16x16@2x", 32),
        ("icon_32x32", 32), ("icon_32x32@2x", 64),
        ("icon_128x128", 128), ("icon_128x128@2x", 256),
        ("icon_256x256", 256), ("icon_256x256@2x", 512),
        ("icon_512x512", 512), ("icon_512x512@2x", 1024),
    ]

    static func main() throws {
        let arguments = CommandLine.arguments
        let outputPath = arguments.count > 1 && !arguments[1].hasPrefix("--")
            ? arguments[1]
            : "build/AppIcon.iconset"
        let strike = parseStrike(arguments)

        let outputURL = URL(fileURLWithPath: outputPath)
        try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)

        for variant in variants {
            guard let image = render(size: variant.size, strike: strike) else {
                FileHandle.standardError.write(Data("Failed to render \(variant.name)\n".utf8))
                exit(1)
            }
            try write(image, to: outputURL.appendingPathComponent("\(variant.name).png"))
        }

        print("Wrote \(variants.count) icon variants to \(outputURL.path)")
    }

    private static func parseStrike(_ arguments: [String]) -> IconArtwork.Strike {
        guard
            let index = arguments.firstIndex(of: "--strike"),
            index + 1 < arguments.count
        else { return .none }

        switch arguments[index + 1] {
        case "marks": return .marks
        case "full": return .full
        default: return .none
        }
    }

    private static func render(size: CGFloat, strike: IconArtwork.Strike) -> CGImage? {
        let pixels = Int(size)
        guard
            let context = CGContext(
                data: nil,
                width: pixels,
                height: pixels,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        else { return nil }

        IconArtwork.draw(in: context, canvas: size, palette: .active, strike: strike)
        return context.makeImage()
    }

    private static func write(_ image: CGImage, to url: URL) throws {
        let representation = NSBitmapImageRep(cgImage: image)
        representation.size = NSSize(width: image.width, height: image.height)
        guard let data = representation.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "GenerateIcon", code: 1)
        }
        try data.write(to: url)
    }
}
