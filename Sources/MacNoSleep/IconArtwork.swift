import AppKit
import CoreGraphics

/// Draws the MacNoSleep mark: a MacBook with rising "z"s, struck through.
///
/// Shared by the `.icns` generator in `Tools/GenerateIcon.swift` and the panel header, so the app
/// and its icon can never drift apart. Every dimension is a fraction of the plate width.
enum IconArtwork {
    /// Where the "no" stroke goes. Striking the whole mark buries the MacBook, so the default
    /// crosses out only the rising "z"s.
    enum Strike {
        case none
        case marks
        case full
    }

    struct Palette {
        var start: CGColor
        var middle: CGColor
        var end: CGColor

        static let active = Palette(
            start: CGColor(srgbRed: 1.00, green: 0.69, blue: 0.13, alpha: 1),
            middle: CGColor(srgbRed: 1.00, green: 0.48, blue: 0.10, alpha: 1),
            end: CGColor(srgbRed: 0.85, green: 0.26, blue: 0.05, alpha: 1)
        )

        static let idle = Palette(
            start: CGColor(srgbRed: 0.56, green: 0.57, blue: 0.60, alpha: 1),
            middle: CGColor(srgbRed: 0.47, green: 0.48, blue: 0.52, alpha: 1),
            end: CGColor(srgbRed: 0.34, green: 0.35, blue: 0.39, alpha: 1)
        )
    }

    static func draw(
        in context: CGContext,
        canvas: CGFloat,
        palette: Palette = .active,
        strike: Strike = .none,
        insetFraction: CGFloat = 0.085
    ) {
        let inset = canvas * insetFraction
        let plate = CGRect(x: inset, y: inset, width: canvas - inset * 2, height: canvas - inset * 2)

        context.interpolationQuality = .high
        context.setShouldAntialias(true)

        drawPlate(in: context, plate: plate, palette: palette)

        let line = strikeLine(for: strike, plate: plate)

        context.beginTransparencyLayer(auxiliaryInfo: nil)
        drawLaptop(in: context, plate: plate)
        drawSleepMarks(in: context, plate: plate)
        if let line {
            context.setBlendMode(.clear)
            stroke(line, in: context, plate: plate, widthFraction: line.width + 0.026 * 2)
            context.setBlendMode(.normal)
        }
        context.endTransparencyLayer()

        if let line {
            context.setStrokeColor(white)
            stroke(line, in: context, plate: plate, widthFraction: line.width)
        }
    }

    static func image(
        size: CGFloat,
        palette: Palette = .active,
        strike: Strike = .none,
        insetFraction: CGFloat = 0.085
    ) -> NSImage {
        NSImage(size: NSSize(width: size, height: size), flipped: false) { _ in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            draw(
                in: context,
                canvas: size,
                palette: palette,
                strike: strike,
                insetFraction: insetFraction
            )
            return true
        }
    }

    private static let white = CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1)
    private static let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!

    private static func drawPlate(in context: CGContext, plate: CGRect, palette: Palette) {
        let radius = plate.width * 0.2237

        context.saveGState()
        context.addPath(
            CGPath(roundedRect: plate, cornerWidth: radius, cornerHeight: radius, transform: nil)
        )
        context.clip()

        let gradient = CGGradient(
            colorsSpace: colorSpace,
            colors: [palette.start, palette.middle, palette.end] as CFArray,
            locations: [0, 0.55, 1]
        )!
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: plate.minX, y: plate.maxY),
            end: CGPoint(x: plate.maxX, y: plate.minY),
            options: []
        )

        let sheen = CGGradient(
            colorsSpace: colorSpace,
            colors: [
                CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.18),
                CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0),
            ] as CFArray,
            locations: [0, 1]
        )!
        let sheenCentre = CGPoint(
            x: plate.minX + plate.width * 0.28,
            y: plate.maxY - plate.height * 0.18
        )
        context.drawRadialGradient(
            sheen,
            startCenter: sheenCentre,
            startRadius: 0,
            endCenter: sheenCentre,
            endRadius: plate.width * 0.8,
            options: []
        )
        context.restoreGState()
    }

    private static func drawLaptop(in context: CGContext, plate: CGRect) {
        let unit = plate.width
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: plate.minX + x * unit, y: plate.minY + y * unit)
        }
        func rect(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> CGRect {
            CGRect(origin: point(x, y), size: CGSize(width: width * unit, height: height * unit))
        }

        context.setFillColor(white)

        let lidOuter = rect(0.155, 0.375, 0.44, 0.30)
        context.addPath(
            CGPath(
                roundedRect: lidOuter,
                cornerWidth: unit * 0.035,
                cornerHeight: unit * 0.035,
                transform: nil
            )
        )
        context.fillPath()

        context.setBlendMode(.clear)
        let bezel = unit * 0.038
        let screen = lidOuter.insetBy(dx: bezel, dy: bezel)
        context.addPath(
            CGPath(
                roundedRect: screen,
                cornerWidth: unit * 0.014,
                cornerHeight: unit * 0.014,
                transform: nil
            )
        )
        context.fillPath()
        context.setBlendMode(.normal)

        let deck = rect(0.095, 0.315, 0.56, 0.052)
        context.addPath(
            CGPath(
                roundedRect: deck,
                cornerWidth: unit * 0.026,
                cornerHeight: unit * 0.026,
                transform: nil
            )
        )
        context.fillPath()

        context.setBlendMode(.clear)
        let notch = CGRect(
            x: deck.midX - unit * 0.058,
            y: deck.maxY - unit * 0.016,
            width: unit * 0.116,
            height: unit * 0.016
        )
        context.addPath(
            CGPath(
                roundedRect: notch,
                cornerWidth: unit * 0.008,
                cornerHeight: unit * 0.008,
                transform: nil
            )
        )
        context.fillPath()
        context.setBlendMode(.normal)
    }

    private static func drawSleepMarks(in context: CGContext, plate: CGRect) {
        let unit = plate.width
        let marks: [(x: CGFloat, y: CGFloat, size: CGFloat, thickness: CGFloat)] = [
            (0.615, 0.545, 0.115, 0.030),
            (0.757, 0.690, 0.085, 0.023),
            (0.864, 0.807, 0.060, 0.017),
        ]

        context.setStrokeColor(white)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        for mark in marks {
            let box = CGRect(
                x: plate.minX + mark.x * unit,
                y: plate.minY + mark.y * unit,
                width: mark.size * unit,
                height: mark.size * unit
            )
            context.setLineWidth(mark.thickness * unit)
            context.move(to: CGPoint(x: box.minX, y: box.maxY))
            context.addLine(to: CGPoint(x: box.maxX, y: box.maxY))
            context.addLine(to: CGPoint(x: box.minX, y: box.minY))
            context.addLine(to: CGPoint(x: box.maxX, y: box.minY))
            context.strokePath()
        }
    }

    private struct StrikeLine {
        var start: CGPoint
        var end: CGPoint
        var width: CGFloat
    }

    private static func strikeLine(for strike: Strike, plate: CGRect) -> StrikeLine? {
        let unit = plate.width

        switch strike {
        case .none:
            return nil
        case .full:
            let reach = unit * 0.315
            return StrikeLine(
                start: CGPoint(x: plate.midX - reach, y: plate.midY - reach),
                end: CGPoint(x: plate.midX + reach, y: plate.midY + reach),
                width: 0.058
            )
        case .marks:
            let centre = CGPoint(x: plate.minX + 0.762 * unit, y: plate.minY + 0.700 * unit)
            let offset = unit * 0.135
            return StrikeLine(
                start: CGPoint(x: centre.x - offset, y: centre.y + offset),
                end: CGPoint(x: centre.x + offset, y: centre.y - offset),
                width: 0.046
            )
        }
    }

    private static func stroke(
        _ line: StrikeLine,
        in context: CGContext,
        plate: CGRect,
        widthFraction: CGFloat
    ) {
        context.setLineWidth(plate.width * widthFraction)
        context.setLineCap(.round)
        context.move(to: line.start)
        context.addLine(to: line.end)
        context.strokePath()
    }
}
