import Foundation
import IOKit.pwr_mgt

/// Holds the IOKit power assertions that keep the machine (and optionally the display) awake.
///
/// Two independent assertions are used so the display can be allowed to sleep and lock while the
/// system itself keeps running background work.
final class PowerAssertions {
    private var systemAssertion: IOPMAssertionID?
    private var displayAssertion: IOPMAssertionID?

    var isHoldingSystem: Bool { systemAssertion != nil }
    var isHoldingDisplay: Bool { displayAssertion != nil }

    func apply(keepSystemAwake: Bool, keepDisplayAwake: Bool) {
        if keepSystemAwake {
            acquireSystem()
        } else {
            releaseSystem()
        }

        if keepDisplayAwake {
            acquireDisplay()
        } else {
            releaseDisplay()
        }
    }

    func releaseAll() {
        releaseSystem()
        releaseDisplay()
    }

    private func acquireSystem() {
        guard systemAssertion == nil else { return }
        systemAssertion = Self.create(
            type: kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
            reason: "MacNoSleep is keeping this Mac awake"
        )
    }

    private func acquireDisplay() {
        guard displayAssertion == nil else { return }
        displayAssertion = Self.create(
            type: kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            reason: "MacNoSleep is keeping the display on"
        )
    }

    private func releaseSystem() {
        guard let id = systemAssertion else { return }
        IOPMAssertionRelease(id)
        systemAssertion = nil
    }

    private func releaseDisplay() {
        guard let id = displayAssertion else { return }
        IOPMAssertionRelease(id)
        displayAssertion = nil
    }

    private static func create(type: CFString, reason: String) -> IOPMAssertionID? {
        var id = IOPMAssertionID(0)
        let result = IOPMAssertionCreateWithName(
            type,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason as CFString,
            &id
        )
        return result == kIOReturnSuccess ? id : nil
    }
}
