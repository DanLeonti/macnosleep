import SwiftUI

struct MenuContentView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            VStack(spacing: 12) {
                primaryToggle
                if let notice = state.notice { noticeBanner(notice) }
                displaySection
                systemSection
            }
            .padding(14)

            Divider()
            footer
        }
        .frame(width: 322)
    }

    private var header: some View {
        HStack(spacing: 10) {
            AppGlyph(isActive: state.isActive)

            VStack(alignment: .leading, spacing: 1) {
                Text(AppInfo.name)
                    .font(.system(size: 13, weight: .semibold))
                Text(state.statusHeadline)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)
            batteryChip
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var batteryChip: some View {
        if let percentage = state.power.percentage {
            HStack(spacing: 4) {
                Image(systemName: state.power.isOnBattery ? "battery.50" : "bolt.fill")
                    .font(.system(size: 9, weight: .semibold))
                Text("\(percentage)%")
                    .font(.system(size: 10, weight: .medium).monospacedDigit())
            }
            .foregroundStyle(state.isPausedForBattery ? Color.red : Color.secondary)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(.quaternary, in: Capsule())
        }
    }

    private var primaryToggle: some View {
        Card {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Keep Mac Awake")
                        .font(.system(size: 13, weight: .semibold))
                    Text(primaryCaption)
                        .font(.system(size: 10.5).monospacedDigit())
                        .foregroundStyle(state.isPausedForBattery ? Color.red : Color.secondary)
                }

                Spacer(minLength: 8)

                Toggle("", isOn: $state.isAwake)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
        }
    }

    private var primaryCaption: String {
        if state.isPausedForBattery {
            return "Paused until you plug in or charge above \(state.batteryFloor.rawValue)%"
        }
        if let remaining = state.remaining {
            return "Turns off in \(AppInfo.countdown(remaining))"
        }
        return state.isAwake ? "Running until you turn it off" : "Your Mac sleeps normally"
    }

    private var displaySection: some View {
        SettingsGroup(title: "Display") {
            PickerRow(title: "Dim display when idle", selection: $state.dimDelay) { $0.title }

            if state.dimDelay != .off {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Dim level")
                            .font(.system(size: 11.5))
                        Spacer()
                        Text("\(Int(state.dimLevel * 100))%")
                            .font(.system(size: 10.5).monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $state.dimLevel, in: 0.01...0.5)
                        .controlSize(.mini)
                }
                .disabled(state.isDimmed)
            }

            ToggleRow(
                title: "Allow lock & sleep",
                subtitle: "Let the display sleep and lock while the Mac keeps working",
                isOn: $state.allowLockAndSleep
            )
        }
    }

    private var systemSection: some View {
        SettingsGroup(title: "System") {
            ToggleRow(
                title: "Allow closed lid",
                subtitle: "Requires an administrator password and persists until turned off",
                isOn: Binding(
                    get: { state.allowClosedLid },
                    set: { state.setAllowClosedLid($0) }
                ),
                isBusy: state.isChangingLidSetting
            )

            PickerRow(title: "Auto turn off", selection: $state.autoOff) { $0.title }

            PickerRow(title: "Pause on low battery", selection: $state.batteryFloor) { $0.title }
                .disabled(!state.power.hasInternalBattery)
        }
    }

    private func noticeBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 7) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 10))
                .foregroundStyle(.red)
                .padding(.top, 1)

            Text(message)
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            Button {
                state.notice = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(9)
        .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Toggle("Launch at login", isOn: $state.launchAtLogin)
                .toggleStyle(.checkbox)
                .font(.system(size: 11.5))

            Spacer(minLength: 8)

            Text("v\(AppInfo.version)")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .controlSize(.small)
            .keyboardShortcut("q")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

private struct AppGlyph: View {
    let isActive: Bool

    var body: some View {
        Image(
            nsImage: IconArtwork.image(
                size: 30,
                palette: isActive ? .active : .idle,
                insetFraction: 0
            )
        )
        .frame(width: 30, height: 30)
        .animation(.easeInOut(duration: 0.2), value: isActive)
    }
}

private struct Card<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct SettingsGroup<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(.tertiary)
                .tracking(0.6)

            VStack(spacing: 10) {
                content
            }
            .padding(12)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}

private struct ToggleRow: View {
    let title: String
    var subtitle: String?
    @Binding var isOn: Bool
    var isBusy = false

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11.5))
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 8)

            if isBusy {
                ProgressView()
                    .controlSize(.small)
                    .scaleEffect(0.6)
            }

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.mini)
                .disabled(isBusy)
        }
    }
}

private struct PickerRow<Value>: View where Value: Hashable & CaseIterable & Identifiable, Value.AllCases: RandomAccessCollection {
    let title: String
    @Binding var selection: Value
    let label: (Value) -> String

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.system(size: 11.5))

            Spacer(minLength: 8)

            Picker("", selection: $selection) {
                ForEach(Array(Value.allCases)) { option in
                    Text(label(option)).tag(option)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .controlSize(.small)
            .fixedSize()
        }
    }
}
