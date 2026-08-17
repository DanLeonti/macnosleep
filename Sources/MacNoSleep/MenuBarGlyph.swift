import AppKit

/// The status item glyph: a simplified version of the app mark, drawn as a template image so macOS
/// can tint it for light, dark, and highlighted menu bars.
///
/// The full icon artwork is too detailed at this size, so the laptop is reduced to a frame and a
/// deck, and the session state is carried by the screen: hollow with rising "z"s when the Mac is
/// free to sleep, solid when a session is running, and struck with a warning when it is paused.
enum MenuBarGlyph {
    enum State {
        case sleeping
        case awake
        case paused
    }

    /// The geometry below is authored in a 19x12 box; this scales it to sit alongside the
    /// system's own status items, which are noticeably taller.
    private static let scale: CGFloat = 1.3

    static let size = NSSize(width: 19 * scale, height: 12 * scale)

    static func image(for state: State) -> NSImage {
        let image = NSImage(size: size, flipped: false) { _ in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            draw(state, in: context, color: CGColor(gray: 0, alpha: 1))
            return true
        }
        image.isTemplate = true
        return image
    }

    static func draw(_ state: State, in context: CGContext, color: CGColor) {
        context.saveGState()
        defer { context.restoreGState() }

        context.setShouldAntialias(true)
        context.scaleBy(x: scale, y: scale)
        context.setFillColor(color)
        context.setStrokeColor(color)

        let deck = CGRect(x: 1.0, y: 0.8, width: 13.2, height: 1.3)
        let lid = CGRect(x: 2.8, y: 2.1, width: 9.6, height: 7.0)

        context.addPath(
            CGPath(roundedRect: deck, cornerWidth: 0.65, cornerHeight: 0.65, transform: nil)
        )
        context.fillPath()

        let lidPath = CGMutablePath()
        lidPath.addPath(CGPath(roundedRect: lid, cornerWidth: 1.1, cornerHeight: 1.1, transform: nil))

        switch state {
        case .sleeping:
            lidPath.addPath(
                CGPath(
                    roundedRect: lid.insetBy(dx: 1.25, dy: 1.25),
                    cornerWidth: 0.45,
                    cornerHeight: 0.45,
                    transform: nil
                )
            )
            context.addPath(lidPath)
            context.fillPath(using: .evenOdd)
            drawSleepMarks(in: context)

        case .awake:
            context.addPath(lidPath)
            context.fillPath()

        case .paused:
            lidPath.addPath(warningPath(in: lid))
            context.addPath(lidPath)
            context.fillPath(using: .evenOdd)
        }
    }

    private static func drawSleepMarks(in context: CGContext) {
        let marks: [(box: CGRect, thickness: CGFloat)] = [
            (CGRect(x: 13.4, y: 5.7, width: 2.7, height: 2.7), 0.9),
            (CGRect(x: 16.5, y: 8.8, width: 2.0, height: 2.0), 0.72),
        ]

        context.setLineCap(.round)
        context.setLineJoin(.round)

        for mark in marks {
            context.setLineWidth(mark.thickness)
            context.move(to: CGPoint(x: mark.box.minX, y: mark.box.maxY))
            context.addLine(to: CGPoint(x: mark.box.maxX, y: mark.box.maxY))
            context.addLine(to: CGPoint(x: mark.box.minX, y: mark.box.minY))
            context.addLine(to: CGPoint(x: mark.box.maxX, y: mark.box.minY))
            context.strokePath()
        }
    }

    private static func warningPath(in lid: CGRect) -> CGPath {
        let path = CGMutablePath()
        let width: CGFloat = 1.15
        let x = lid.midX - width / 2

        path.addPath(
            CGPath(
                roundedRect: CGRect(x: x, y: lid.minY + 2.5, width: width, height: 2.6),
                cornerWidth: width / 2,
                cornerHeight: width / 2,
                transform: nil
            )
        )
        path.addEllipse(in: CGRect(x: x, y: lid.minY + 1.2, width: width, height: width))

        return path
    }
}
