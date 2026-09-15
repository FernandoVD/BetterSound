import SwiftUI

/// Matches Apple's own Control Center Sound module directly: bold section
/// title, a custom pill slider (see PillSlider.swift), and no boxed "card"
/// backgrounds — everything just sits on the popover's own vibrant
/// background with dividers between sections. Output/Input device pickers
/// are a compact single row at rest (icon + name + chevron); tapping it
/// expands an inline list of rich rows (circular icon badge, tinted green
/// when active) matching the real Control Center's own device list — built
/// as an inline expand/collapse rather than a SwiftUI `Menu`, since a
/// native Menu can't host custom circular-badge rows, and mixing a custom
/// icon label with Menu's own automatic disclosure indicator was exactly
/// what caused the earlier chevron-overlap bug.
struct MenuBarContentView: View {
    @EnvironmentObject private var audio: AudioEngine
    @EnvironmentObject private var apps: PerAppAudioController
    @EnvironmentObject private var updates: UpdateChecker
    @Environment(\.openWindow) private var openWindow

    @State private var isOutputExpanded = false
    @State private var isInputExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            volumeSection
            Divider()
            outputSection
            Divider()
            inputSection

            if !apps.items.isEmpty {
                Divider()
                appsSection
            }

            Divider()

            if let update = updates.availableUpdate {
                VStack(alignment: .leading, spacing: 4) {
                    Link(destination: update.htmlURL) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.up.circle.fill")
                            Text("Update available: v\(update.version)")
                        }
                    }
                    .font(.system(size: 12, weight: .semibold))

                    // brew install a second time silently does nothing —
                    // give the actual upgrade command, not just a link.
                    CopyableCommand(command: "brew upgrade --cask bettersound")

                    // Every update re-quarantines the app (no stable
                    // Developer ID signature), so this step recurs too.
                    CopyableCommand(command: "xattr -cr /Applications/BetterSound.app")
                }
            }

            Button("BetterSound Settings…") {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "settings")
            }
            .buttonStyle(.plain)
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(width: 280)
    }

    // MARK: - Master volume

    private var volumeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Sound")
                    .font(.system(size: 15, weight: .bold))

                Spacer()

                // The one authoritative number in the popover — this is
                // "the actual volume level," as opposed to Input/per-app
                // controls, which is also why this row stays visually the
                // largest: it's the only true master reading.
                Text("\(Int((audio.isMuted ? 0 : audio.masterVolume) * 100))%")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            HStack(spacing: 8) {
                Button {
                    audio.toggleMute()
                } label: {
                    Image(systemName: audio.isMuted ? "speaker.slash.fill" : "speaker.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.primary)
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(.plain)
                .disabled(!audio.supportsMasterVolume)

                PillSlider(value: Binding(
                    get: { audio.isMuted ? 0 : audio.masterVolume },
                    set: { audio.setMasterVolume($0) }
                ), height: 20)
                .disabled(!audio.supportsMasterVolume)
                .opacity(audio.supportsMasterVolume ? 1 : 0.35)

                Image(systemName: "speaker.wave.3.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.primary)
                    .frame(width: 16, height: 16)
            }

            if !audio.supportsMasterVolume {
                Text("No single volume control for this output")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var currentDeviceName: String {
        audio.devices.first(where: { $0.id == audio.defaultDeviceID })?.name ?? "This device"
    }

    // MARK: - Output devices

    private var outputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Output")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)

            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    isOutputExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: currentOutputSymbolName)
                        .font(.system(size: 11))
                        .foregroundStyle(.primary)
                        .frame(width: 16, height: 16)

                    Text(currentDeviceName)
                        .font(.system(size: 13))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Spacer()

                    if !audio.devices.isEmpty {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .rotationEffect(.degrees(isOutputExpanded ? 180 : 0))
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(audio.devices.isEmpty)

            if isOutputExpanded {
                VStack(spacing: 2) {
                    // Devices that can't actually be set as the system
                    // default (e.g. Microsoft Teams' virtual audio device)
                    // are left out entirely — macOS silently no-ops a
                    // switch to one, so offering it would just look broken.
                    ForEach(audio.devices.filter(\.canBeDefault)) { device in
                        DeviceRow(
                            symbolName: device.kind.symbolName,
                            name: device.name,
                            isSelected: device.id == audio.defaultDeviceID
                        ) {
                            audio.selectDevice(device)
                            withAnimation(.easeInOut(duration: 0.15)) {
                                isOutputExpanded = false
                            }
                        }
                    }
                }
            }
        }
    }

    private var currentOutputSymbolName: String {
        audio.devices.first(where: { $0.id == audio.defaultDeviceID })?.kind.symbolName ?? "speaker.wave.2.fill"
    }

    // MARK: - Input

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Input")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(Int((audio.isInputMuted ? 0 : audio.inputVolume) * 100))%")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            HStack(spacing: 8) {
                Button {
                    audio.toggleInputMute()
                } label: {
                    Image(systemName: audio.isInputMuted ? "mic.slash.fill" : "mic.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.primary)
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(.plain)

                // Deliberately smaller than the master Sound slider — Input
                // is one control among several, not the one authoritative
                // "this is the volume" reading Sound represents.
                PillSlider(value: Binding(
                    get: { audio.isInputMuted ? 0 : audio.inputVolume },
                    set: { audio.setInputVolume($0) }
                ), height: 14)

                if !audio.inputDevices.isEmpty {
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            isInputExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .rotationEffect(.degrees(isInputExpanded ? 180 : 0))
                            .frame(width: 16, height: 16)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }

            if isInputExpanded {
                VStack(spacing: 2) {
                    ForEach(audio.inputDevices.filter(\.canBeDefault)) { device in
                        DeviceRow(
                            symbolName: device.kind.inputSymbolName,
                            name: device.name,
                            isSelected: device.id == audio.defaultInputDeviceID
                        ) {
                            audio.selectInputDevice(device)
                            withAnimation(.easeInOut(duration: 0.15)) {
                                isInputExpanded = false
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Per-app volume

    private var appsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Applications")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)

            ForEach(apps.items) { item in
                AppVolumeRow(item: item, devices: audio.devices)
            }
        }
    }
}

private struct AppVolumeRow: View {
    let item: AppAudioItem
    let devices: [AudioDevice]

    @EnvironmentObject private var apps: PerAppAudioController

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                appIcon
                    .resizable()
                    .frame(width: 16, height: 16)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))

                Text(item.name)
                    .font(.system(size: 13))
                    .lineLimit(1)

                Spacer()

                Text("\(Int((item.isMuted ? 0 : item.volume) * 100))%")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()

                outputMenu
            }

            HStack(spacing: 8) {
                Button {
                    apps.toggleMute(for: item)
                } label: {
                    Image(systemName: item.isMuted ? "speaker.slash.fill" : "speaker.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .frame(width: 16)
                }
                .buttonStyle(.plain)

                PillSlider(
                    value: Binding(
                        get: { item.isMuted ? 0 : item.volume },
                        set: { apps.setVolume($0, for: item) }
                    ),
                    height: 12
                )
            }
        }
    }

    private var appIcon: Image {
        if let icon = item.icon {
            return Image(nsImage: icon)
        }
        return Image(systemName: "app.fill")
    }

    private var outputMenu: some View {
        Menu {
            Button {
                apps.setOutputDevice(nil, for: item)
            } label: {
                HStack {
                    Text("Default")
                    if item.outputDeviceID == nil {
                        Image(systemName: "checkmark")
                    }
                }
            }

            ForEach(devices) { device in
                Button {
                    apps.setOutputDevice(device.id, for: item)
                } label: {
                    HStack {
                        Text(device.name)
                        if item.outputDeviceID == device.id {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Image(systemName: outputIconName)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: 20, height: 16)
    }

    private var outputIconName: String {
        if let id = item.outputDeviceID, let device = devices.first(where: { $0.id == id }) {
            return device.kind.symbolName
        }
        return "arrow.triangle.branch"
    }
}

/// A device row for the expanded Output/Input lists, matching Control
/// Center's own device rows: a circular icon badge that itself changes —
/// white background, green icon — when active, rather than a trailing
/// checkmark.
private struct DeviceRow: View {
    let symbolName: String
    let name: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.quaternary))
                        .frame(width: 28, height: 28)
                    Image(systemName: symbolName)
                        .font(.system(size: 12))
                        .foregroundStyle(isSelected ? Color.green : Color.primary)
                }

                Text(name)
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 3)
    }
}
