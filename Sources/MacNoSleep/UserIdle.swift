import CoreGraphics
import Foundation

enum UserIdle {
    private static let anyInputEvent = CGEventType(rawValue: ~UInt32(0))!

    /// Seconds since the last keyboard, mouse, or trackpad event.
    static var seconds: TimeInterval {
        CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: anyInputEvent)
    }
}
