import AppKit
import Combine
import Foundation

@MainActor
final class AppState: ObservableObject {
    private let defaults = UserDefaults.standard
    private let assertions = PowerAssertions()
    private var ticker: Timer?
    private var isRestoringSettings = true
    private var brightnessBeforeDim: Float?

    @Published var isAwake = false {
        didSet { handleAwakeChange(from: oldValue) }
    }

    @Published var allowLockAndSleep = false {
        didSet { persist(allowLockAndSleep, DefaultsKey.allowLockAndSleep); evaluate() }
    }

    @Published var dimDelay: DimDelay = .off {
        didSet { persist(dimDelay.rawValue, DefaultsKey.dimDelay); evaluate() }
    }

    @Published var dimLevel: Double = 0.05 {
        didSet { persist(dimLevel, DefaultsKey.dimLevel) }
    }

    @Published var autoOff: AutoOff = .never {
        didSet { handleAutoOffChange() }
    }

    @Published var batteryFloor: BatteryFloor = .ten {
        didSet { persist(batteryFloor.rawValue, DefaultsKey.batteryFloor); evaluate() }
    }

    @Published var launchAtLogin = false {
        didSet { handleLaunchAtLoginChange(from: oldValue) }
    }

    @Published private(set) var allowClosedLid = false
    @Published private(set) var isChangingLidSetting = false
    @Published private(set) var power = PowerSnapshot.unknown
    @Published private(set) var isPausedForBattery = false
    @Published private(set) var isDimmed = false
    @Published private(set) var expiresAt: Date?
    @Published private(set) var now = Date()
    @Published var notice: String?

    var isActive: Bool { isAwake && !isPausedForBattery }

    var remaining: TimeInterval? {
        guard let expiresAt else { return nil }
        return max(0, expiresAt.timeIntervalSince(now))
    }

    var menuBarState: MenuBarGlyph.State {
        if isPausedForBattery { return .paused }
        return isAwake ? .awake : .sleeping
    }

    var statusHeadline: String {
        if isPausedForBattery { return "Paused — battery low" }
        guard isAwake else { return "Sleep allowed" }
        return allowLockAndSleep ? "Awake, display may sleep" : "Awake, display stays on"
    }

    static let shared = AppState()

    private init() {
        allowLockAndSleep = defaults.bool(forKey: DefaultsKey.allowLockAndSleep)
        dimDelay = DimDelay(rawValue: defaults.integer(forKey: DefaultsKey.dimDelay)) ?? .off
        autoOff = AutoOff(rawValue: defaults.integer(forKey: DefaultsKey.autoOff)) ?? .never
        batteryFloor = defaults.object(forKey: DefaultsKey.batteryFloor) == nil
            ? .ten
            : BatteryFloor(rawValue: defaults.integer(forKey: DefaultsKey.batteryFloor)) ?? .ten
        let storedDimLevel = defaults.double(forKey: DefaultsKey.dimLevel)
        dimLevel = storedDimLevel > 0 ? storedDimLevel : 0.05
        launchAtLogin = LaunchAtLogin.isEnabled
        allowClosedLid = LidSleepControl.isSleepDisabled()
        power = BatteryMonitor.snapshot()
        isAwake = defaults.bool(forKey: DefaultsKey.keepAwake)
        expiresAt = isAwake ? autoOff.duration.map { Date().addingTimeInterval($0) } : nil

        isRestoringSettings = false
        startTicking()
    }

    func setAllowClosedLid(_ enabled: Bool) {
        guard enabled != allowClosedLid, !isChangingLidSetting else { return }
        isChangingLidSetting = true
        notice = nil

        Task {
            let outcome = await Task.detached { LidSleepControl.set(enabled) }.value

            switch outcome {
            case .changed:
                allowClosedLid = enabled
                persist(enabled, DefaultsKey.lidOverrideActive)
                notice = enabled
                    ? "Closed-lid mode is a system setting and stays on until turned off."
                    : nil
            case .cancelled:
                notice = "Administrator approval is required to change closed-lid mode."
            case .failed(let message):
                notice = "Could not change closed-lid mode: \(message)"
            }

            isChangingLidSetting = false
        }
    }

    func prepareForTermination() {
        ticker?.invalidate()
        ticker = nil
        restoreBrightness()
        assertions.releaseAll()

        if allowClosedLid {
            _ = LidSleepControl.set(false)
            persist(false, DefaultsKey.lidOverrideActive)
        }
    }

    private func startTicking() {
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.evaluate() }
        }
        timer.tolerance = 0.5
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
        evaluate()
    }

    private func handleAwakeChange(from oldValue: Bool) {
        guard !isRestoringSettings, oldValue != isAwake else { return }
        persist(isAwake, DefaultsKey.keepAwake)
        expiresAt = isAwake ? autoOff.duration.map { Date().addingTimeInterval($0) } : nil
        if !isAwake { notice = nil }
        evaluate()
    }

    private func handleAutoOffChange() {
        guard !isRestoringSettings else { return }
        persist(autoOff.rawValue, DefaultsKey.autoOff)
        expiresAt = isAwake ? autoOff.duration.map { Date().addingTimeInterval($0) } : nil
        evaluate()
    }

    private func handleLaunchAtLoginChange(from oldValue: Bool) {
        guard !isRestoringSettings, oldValue != launchAtLogin else { return }
        let applied = LaunchAtLogin.set(launchAtLogin)
        if applied != launchAtLogin {
            isRestoringSettings = true
            launchAtLogin = applied
            isRestoringSettings = false
            notice = "macOS declined the login item. Approve MacNoSleep in System Settings › General › Login Items."
        }
    }

    private func evaluate() {
        if expiresAt != nil { now = Date() }

        let snapshot = BatteryMonitor.snapshot()
        if snapshot != power { power = snapshot }

        if let expiresAt, Date() >= expiresAt {
            isAwake = false
            return
        }

        let paused = isAwake && shouldPauseForBattery
        if paused != isPausedForBattery { isPausedForBattery = paused }

        let keepDisplayAwake = isActive && !allowLockAndSleep
        assertions.apply(keepSystemAwake: isActive, keepDisplayAwake: keepDisplayAwake)
        updateDimming(displayHeldAwake: keepDisplayAwake)
    }

    private var shouldPauseForBattery: Bool {
        guard batteryFloor != .disabled, power.isOnBattery, let percentage = power.percentage else {
            return false
        }
        return percentage <= batteryFloor.rawValue
    }

    private func updateDimming(displayHeldAwake: Bool) {
        guard displayHeldAwake, let threshold = dimDelay.interval else {
            restoreBrightness()
            return
        }

        if UserIdle.seconds >= threshold {
            dimBrightness()
        } else {
            restoreBrightness()
        }
    }

    private func dimBrightness() {
        guard !isDimmed else { return }
        brightnessBeforeDim = BrightnessControl.current()
        guard BrightnessControl.set(Float(dimLevel)) else { return }
        isDimmed = true
    }

    private func restoreBrightness() {
        guard isDimmed else { return }
        BrightnessControl.set(brightnessBeforeDim ?? 0.5)
        brightnessBeforeDim = nil
        isDimmed = false
    }

    private func persist(_ value: Any, _ key: String) {
        guard !isRestoringSettings else { return }
        defaults.set(value, forKey: key)
    }
}
