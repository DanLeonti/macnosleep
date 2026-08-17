import Foundation

/// Controls the system-wide `SleepDisabled` power setting, which is what keeps a laptop running
/// with the lid shut.
///
/// No public or private API exposes this to an unprivileged process, so the change is made through
/// `pmset`, which requires an administrator authorisation prompt. The setting survives quitting and
/// rebooting, so callers are responsible for turning it back off.
enum LidSleepControl {
    enum Outcome: Sendable {
        case changed
        case cancelled
        case failed(String)
    }

    static func isSleepDisabled() -> Bool {
        guard let output = run("/usr/bin/pmset", ["-g"])?.standardOutput else { return false }

        for line in output.split(separator: "\n") where line.contains("SleepDisabled") {
            return line.split(separator: " ").last.map { $0 == "1" } ?? false
        }
        return false
    }

    static func set(_ disableSleep: Bool) -> Outcome {
        let command = "/usr/bin/pmset -a disablesleep \(disableSleep ? 1 : 0)"
        let script = "do shell script \"\(command)\" with administrator privileges"

        guard let result = run("/usr/bin/osascript", ["-e", script]) else {
            return .failed("Could not launch osascript")
        }

        if result.exitCode == 0 { return .changed }

        // osascript reports a cancelled authorisation dialog as AppleScript error -128.
        if result.standardError.contains("-128") { return .cancelled }

        let message = result.standardError
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
        return .failed(message.isEmpty ? "pmset exited with code \(result.exitCode)" : message)
    }

    private struct CommandResult {
        var exitCode: Int32
        var standardOutput: String
        var standardError: String
    }

    private static func run(_ launchPath: String, _ arguments: [String]) -> CommandResult? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        do {
            try process.run()
        } catch {
            return nil
        }

        let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        return CommandResult(
            exitCode: process.terminationStatus,
            standardOutput: String(decoding: outData, as: UTF8.self),
            standardError: String(decoding: errData, as: UTF8.self)
        )
    }
}
