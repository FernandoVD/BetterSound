import SwiftUI

/// Matches Apple's own Control Center Sound module directly: bold section
/// title, a custom pill slider (see PillSlider.swift) using real Liquid Glass
/// for its track, and no boxed "card" backgrounds — everything just sits on
/// the popover's own vibrant background with dividers between sections.
/// Output/Input device pickers are single compact rows (icon + name + a
/// small trailing chevron menu) rather than an expanded list of rows.
struct MenuBarContentView: View {
    @EnvironmentObject private var audio: AudioEngine
    @EnvironmentObject private var apps: PerAppAudioController
    @EnvironmentObject private var updates: UpdateChecker
    @Environment(\.openWindow) private var openWindow

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
            Text("Sound")
                .font(.system(size: 15, weight: .bold))

            HStack(spacing: 8) {
                Button {
                    audio.toggleMute()
                } label: {
                    Image(systemName: audio.isMuted ? "speaker.slash.fill" : "speaker.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.primary)
                        .frame(width: 16)
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
                    .font(.system(size: 12))
                    .foregroundStyle(.primary)
                    .frame(width: 16)
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

            HStack(spacing: 8) {
                Image(systemName: currentOutputSymbolName)
                    .font(.system(size: 12))
                    .foregroundStyle(.primary)
                    .frame(width: 16)

                Text(currentDeviceName)
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer()

                if !audio.devices.isEmpty {
                    outputDeviceMenu
                }
            }
        }
    }

    private var outputDeviceMenu: some View {
        Menu {
            // Devices that can't actually be set as the system default (e.g.
            // Microsoft Teams' virtual audio device) are left out entirely —
            // macOS silently no-ops a switch to one, so offering it as a
            // choice would just look broken.
            ForEach(audio.devices.filter(\.canBeDefault)) { device in
                Button {
                    audio.selectDevice(device)
                } label: {
                    HStack {
                        Text(device.name)
                        if device.id == audio.defaultDeviceID {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "chevron.down")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .menuStyle(.borderlessButton)
        .frame(width: 16)
    }

    private var currentOutputSymbolName: String {
        audio.devices.first(where: { $0.id == audio.defaultDeviceID })?.kind.symbolName ?? "speaker.wave.2.fill"
    }

    // MARK: - Input

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Input")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Button {
                    audio.toggleInputMute()
                } label: {
                    Image(systemName: audio.isInputMuted ? "mic.slash.fill" : "mic.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.primary)
                        .frame(width: 16)
                }
                .buttonStyle(.plain)

                PillSlider(value: Binding(
                    get: { audio.isInputMuted ? 0 : audio.inputVolume },
                    set: { audio.setInputVolume($0) }
                ), height: 20)

                if !audio.inputDevices.isEmpty {
                    inputDeviceMenu
                }
            }
        }
    }

    private var inputDeviceMenu: some View {
        Menu {
            ForEach(audio.inputDevices.filter(\.canBeDefault)) { device in
                Button {
                    audio.selectInputDevice(device)
                } label: {
                    HStack {
                        Text(device.name)
                        if device.id == audio.defaultInputDeviceID {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "chevron.down")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .menuStyle(.borderlessButton)
        .frame(width: 16)
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
        .frame(width: 20)
    }

    private var outputIconName: String {
        if let id = item.outputDeviceID, let device = devices.first(where: { $0.id == id }) {
            return device.kind.symbolName
        }
        return "arrow.triangle.branch"
    }
}
