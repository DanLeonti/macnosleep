import Foundation
import IOKit.ps

struct PowerSnapshot: Equatable {
    var percentage: Int?
    var isOnBattery: Bool
    var hasInternalBattery: Bool

    static let unknown = PowerSnapshot(percentage: nil, isOnBattery: false, hasInternalBattery: false)
}

enum BatteryMonitor {
    static func snapshot() -> PowerSnapshot {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else {
            return .unknown
        }

        let providingType = IOPSGetProvidingPowerSourceType(blob)?.takeRetainedValue() as String?
        let onBattery = providingType == kIOPSBatteryPowerValue

        guard let sources = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef] else {
            return PowerSnapshot(percentage: nil, isOnBattery: onBattery, hasInternalBattery: false)
        }

        for source in sources {
            guard
                let description = IOPSGetPowerSourceDescription(blob, source)?.takeUnretainedValue()
                    as? [String: Any],
                description[kIOPSTypeKey] as? String == kIOPSInternalBatteryType,
                let current = description[kIOPSCurrentCapacityKey] as? Int,
                let maximum = description[kIOPSMaxCapacityKey] as? Int,
                maximum > 0
            else { continue }

            let percentage = Int((Double(current) / Double(maximum) * 100).rounded())
            return PowerSnapshot(
                percentage: min(100, max(0, percentage)),
                isOnBattery: onBattery,
                hasInternalBattery: true
            )
        }

        return PowerSnapshot(percentage: nil, isOnBattery: onBattery, hasInternalBattery: false)
    }
}
