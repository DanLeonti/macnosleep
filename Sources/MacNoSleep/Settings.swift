import Foundation

enum DimDelay: Int, CaseIterable, Identifiable {
    case off = 0
    case oneMinute = 60
    case fiveMinutes = 300
    case fifteenMinutes = 900
    case thirtyMinutes = 1800

    var id: Int { rawValue }

    var interval: TimeInterval? { rawValue == 0 ? nil : TimeInterval(rawValue) }

    var title: String {
        switch self {
        case .off: "Off"
        case .oneMinute: "After 1 min"
        case .fiveMinutes: "After 5 min"
        case .fifteenMinutes: "After 15 min"
        case .thirtyMinutes: "After 30 min"
        }
    }
}

enum AutoOff: Int, CaseIterable, Identifiable {
    case never = 0
    case thirtyMinutes = 1800
    case oneHour = 3600
    case twoHours = 7200
    case threeHours = 10800
    case fourHours = 14400
    case sixHours = 21600
    case eightHours = 28800
    case twelveHours = 43200

    var id: Int { rawValue }

    var duration: TimeInterval? { rawValue == 0 ? nil : TimeInterval(rawValue) }

    var title: String {
        switch self {
        case .never: "Never"
        case .thirtyMinutes: "After 30 min"
        case .oneHour: "After 1 hour"
        case .twoHours: "After 2 hours"
        case .threeHours: "After 3 hours"
        case .fourHours: "After 4 hours"
        case .sixHours: "After 6 hours"
        case .eightHours: "After 8 hours"
        case .twelveHours: "After 12 hours"
        }
    }

    var shortTitle: String {
        switch self {
        case .never: "∞"
        case .thirtyMinutes: "30m"
        case .oneHour: "1h"
        case .twoHours: "2h"
        case .threeHours: "3h"
        case .fourHours: "4h"
        case .sixHours: "6h"
        case .eightHours: "8h"
        case .twelveHours: "12h"
        }
    }
}

enum BatteryFloor: Int, CaseIterable, Identifiable {
    case disabled = 0
    case five = 5
    case ten = 10
    case fifteen = 15
    case twenty = 20

    var id: Int { rawValue }

    var title: String { self == .disabled ? "Never pause" : "Below \(rawValue)%" }
}

enum DefaultsKey {
    static let keepAwake = "keepAwake"
    static let allowLockAndSleep = "allowLockAndSleep"
    static let allowClosedLid = "allowClosedLid"
    static let dimDelay = "dimDelay"
    static let autoOff = "autoOff"
    static let batteryFloor = "batteryFloor"
    static let dimLevel = "dimLevel"
    static let lidOverrideActive = "lidOverrideActive"
}
