import SwiftUI

@MainActor
enum PreviewRender {
    static func runIfRequested() {
        showWindowIfRequested()
        renderMenuBarIfRequested()
        renderIfRequested()
    }

    /// Writes a contact sheet of the three status item states, at menu bar scale and magnified,
    /// on both a light and a dark strip.
    private static func renderMenuBarIfRequested() {
        let arguments = CommandLine.arguments
        guard let index = arguments.firstIndex(of: "--menubar"), index + 1 < arguments.count else {
            return
        }

        let states: [MenuBarGlyph.State] = [.sleeping, .awake, .paused]
        let scales: [CGFloat] = [2, 8]
        let padding: CGFloat = 10
        let cell = MenuBarGlyph.size

        let rowHeights = scales.map { cell.height * $0 + padding * 2 }
        let rowWidths = scales.map { (cell.width * $0 + padding) * CGFloat(states.count) + padding }
        let width = Int(rowWidths.max() ?? 0)
        let height = Int(rowHeights.reduce(0, +)) * 2

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
        else { exit(1) }

        var y = CGFloat(height)
        for (background, foreground) in [
            (CGColor(gray: 0.96, alpha: 1), CGColor(gray: 0.1, alpha: 1)),
            (CGColor(gray: 0.12, alpha: 1), CGColor(gray: 1, alpha: 1)),
        ] {
            for scale in scales {
                let rowHeight = cell.height * scale + padding * 2
                y -= rowHeight

                context.setFillColor(background)
                context.fill(CGRect(x: 0, y: y, width: CGFloat(width), height: rowHeight))

                var x = padding
                for state in states {
                    context.saveGState()
                    context.translateBy(x: x, y: y + padding)
                    context.scaleBy(x: scale, y: scale)
                    MenuBarGlyph.draw(state, in: context, color: foreground)
                    context.restoreGState()
                    x += cell.width * scale + padding
                }
            }
        }

        guard
            let image = context.makeImage(),
            let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
        else { exit(1) }

        try? data.write(to: URL(fileURLWithPath: arguments[index + 1]))
        exit(0)
    }

    private static func showWindowIfRequested() {
        guard CommandLine.arguments.contains("--window") else { return }

        NSApp.setActivationPolicy(.regular)
        if CommandLine.arguments.contains("--dark") {
            NSApp.appearance = NSAppearance(named: .darkAqua)
        }

        let controller = NSHostingController(
            rootView: MenuContentView()
                .environmentObject(AppState.shared)
                .background(Color(nsColor: .windowBackgroundColor))
        )
        let window = NSWindow(contentViewController: controller)
        window.title = "MacNoSleep"
        window.styleMask = [.titled, .closable]
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        print("WINDOW_ID \(window.windowNumber)")
        fflush(stdout)

        guard
            let index = CommandLine.arguments.firstIndex(of: "--window"),
            index + 1 < CommandLine.arguments.count
        else { return }

        let path = CommandLine.arguments[index + 1]
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            snapshot(window: window, to: path)
            exit(0)
        }
    }

    private static func snapshot(window: NSWindow, to path: String) {
        guard
            let view = window.contentView,
            let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds)
        else { return }

        view.cacheDisplay(in: view.bounds, to: rep)
        guard let data = rep.representation(using: .png, properties: [:]) else { return }
        try? data.write(to: URL(fileURLWithPath: path))
    }

    private static func renderIfRequested() {
        let arguments = CommandLine.arguments
        guard let index = arguments.firstIndex(of: "--render"), index + 1 < arguments.count else {
            return
        }

        let view = MenuContentView()
            .environmentObject(AppState.shared)
            .padding(20)
            .background(Color(nsColor: .windowBackgroundColor))

        let renderer = ImageRenderer(content: view)
        renderer.scale = 2

        guard
            let image = renderer.nsImage,
            let tiff = image.tiffRepresentation,
            let rep = NSBitmapImageRep(data: tiff),
            let data = rep.representation(using: .png, properties: [:])
        else {
            exit(1)
        }

        try? data.write(to: URL(fileURLWithPath: arguments[index + 1]))
        exit(0)
    }
}
