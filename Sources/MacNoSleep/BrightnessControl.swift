import CoreGraphics
import Foundation
import IOKit

/// Reads and writes the built-in display's backlight level.
///
/// macOS has no public API for this. `DisplayServices` works on Apple Silicon and recent Intel
/// machines, `CoreDisplay` covers older releases, and the `IODisplayConnect` path is the last
/// resort for legacy Intel hardware. Each backend is resolved lazily via `dlopen`.
enum BrightnessControl {
    private typealias GetBrightness = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private typealias SetBrightness = @convention(c) (CGDirectDisplayID, Float) -> Int32
    private typealias CoreDisplayGet = @convention(c) (CGDirectDisplayID) -> Double
    private typealias CoreDisplaySet = @convention(c) (CGDirectDisplayID, Double) -> Void

    private static let displayServices: (get: GetBrightness, set: SetBrightness)? = {
        guard
            let handle = dlopen(
                "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices",
                RTLD_LAZY
            ),
            let getSymbol = dlsym(handle, "DisplayServicesGetBrightness"),
            let setSymbol = dlsym(handle, "DisplayServicesSetBrightness")
        else { return nil }

        return (
            unsafeBitCast(getSymbol, to: GetBrightness.self),
            unsafeBitCast(setSymbol, to: SetBrightness.self)
        )
    }()

    private static let coreDisplay: (get: CoreDisplayGet, set: CoreDisplaySet)? = {
        guard
            let handle = dlopen("/System/Library/Frameworks/CoreDisplay.framework/CoreDisplay", RTLD_LAZY),
            let getSymbol = dlsym(handle, "CoreDisplay_Display_GetUserBrightness"),
            let setSymbol = dlsym(handle, "CoreDisplay_Display_SetUserBrightness")
        else { return nil }

        return (
            unsafeBitCast(getSymbol, to: CoreDisplayGet.self),
            unsafeBitCast(setSymbol, to: CoreDisplaySet.self)
        )
    }()

    static var isSupported: Bool {
        displayServices != nil || coreDisplay != nil || legacyDisplayService() != IO_OBJECT_NULL
    }

    static func current() -> Float? {
        let display = CGMainDisplayID()

        if let services = displayServices {
            var value: Float = 0
            if services.get(display, &value) == 0, value.isFinite {
                return clamp(value)
            }
        }

        if let core = coreDisplay {
            let value = Float(core.get(display))
            if value.isFinite, value > 0 || value == 0 {
                return clamp(value)
            }
        }

        let service = legacyDisplayService()
        guard service != IO_OBJECT_NULL else { return nil }
        defer { IOObjectRelease(service) }

        var value: Float = 0
        guard IODisplayGetFloatParameter(service, 0, kIODisplayBrightnessKey as CFString, &value) == kIOReturnSuccess
        else { return nil }
        return clamp(value)
    }

    @discardableResult
    static func set(_ level: Float) -> Bool {
        let display = CGMainDisplayID()
        let target = clamp(level)

        if let services = displayServices, services.set(display, target) == 0 {
            return true
        }

        if let core = coreDisplay {
            core.set(display, Double(target))
            return true
        }

        let service = legacyDisplayService()
        guard service != IO_OBJECT_NULL else { return false }
        defer { IOObjectRelease(service) }

        return IODisplaySetFloatParameter(service, 0, kIODisplayBrightnessKey as CFString, target) == kIOReturnSuccess
    }

    private static func legacyDisplayService() -> io_service_t {
        var iterator: io_iterator_t = IO_OBJECT_NULL
        guard
            IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IODisplayConnect"), &iterator)
                == kIOReturnSuccess
        else { return IO_OBJECT_NULL }
        defer { IOObjectRelease(iterator) }

        return IOIteratorNext(iterator)
    }

    private static func clamp(_ value: Float) -> Float {
        min(1, max(0, value))
    }
}
