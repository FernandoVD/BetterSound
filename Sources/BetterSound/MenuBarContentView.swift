import SwiftUI

/// Matches Apple's own Control Center Sound module directly: bold section
/// title, a custom pill slider (see PillSlider.swift) using real Liquid Glass
/// for its track, device rows with a glass circular icon badge tinted green
/// when active (no trailing checkmark), and no boxed "card" backgrounds —
/// everything just sits on the popover's own vibrant background with
/// dividers between sections.
struct MenuBarContentView: View {
    @EnvironmentObject private var audio: AudioEngine
    @EnvironmentObject private var apps: PerAppAudioController
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

                PillSlider(value: Binding(
                    get: { audio.isMuted ? 0 : audio.masterVolume },
                    set: { audio.setMasterVolume($0) }
                ), height: 20)

                Image(systemName: "speaker.wave.3.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.primary)
                    .frame(width: 16)
            }
        }
    }

    // MARK: - Output devices

    private var outputSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Output")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.bottom, 2)

            if audio.devices.isEmpty {
                Text("No output devices found")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            } else {
                GlassEffectContainer {
                    ForEach(audio.devices) { device in
                        DeviceRow(
                            symbolName: device.kind.symbolName,
                            name: device.name,
                            isSelected: device.id == audio.defaultDeviceID
                        ) {
                            audio.selectDevice(device)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Input

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Input")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.primary)
                    .frame(width: 16)

                PillSlider(value: Binding(
                    get: { audio.inputVolume },
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
            ForEach(audio.inputDevices) { device in
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
                        .fill(.clear)
                        .glassEffect(.regular, in: .circle)
                    Image(systemName: symbolName)
                        .font(.system(size: 12))
                        .foregroundStyle(isSelected ? Color.green : Color.primary)
                }
                .frame(width: 26, height: 26)

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

            PillSlider(
                value: Binding(
                    get: { item.volume },
                    set: { apps.setVolume($0, for: item) }
                ),
                height: 12
            )
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
