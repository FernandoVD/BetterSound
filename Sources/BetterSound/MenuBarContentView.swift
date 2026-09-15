import SwiftUI

/// Matches Apple's own Control Center Sound module directly: bold section
/// title, a custom pill slider (see PillSlider.swift), device rows with a
/// circular icon badge tinted green when active (no trailing checkmark), and
/// no boxed "card" backgrounds — everything just sits on the popover's own
/// vibrant background with dividers between sections.
struct MenuBarContentView: View {
    @EnvironmentObject private var audio: AudioEngine
    @EnvironmentObject private var apps: PerAppAudioController

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            volumeSection
            Divider()
            outputSection

            if !apps.items.isEmpty {
                Divider()
                appsSection
            }
        }
        .padding(16)
        .frame(width: 300)
    }

    // MARK: - Master volume

    private var volumeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Sound")
                .font(.system(size: 18, weight: .bold))

            HStack(spacing: 10) {
                Button {
                    audio.toggleMute()
                } label: {
                    Image(systemName: audio.isMuted ? "speaker.slash.fill" : "speaker.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(.primary)
                        .frame(width: 20)
                }
                .buttonStyle(.plain)

                PillSlider(value: Binding(
                    get: { audio.isMuted ? 0 : audio.masterVolume },
                    set: { audio.setMasterVolume($0) }
                ))

                Image(systemName: "speaker.wave.3.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(.primary)
                    .frame(width: 20)
            }
        }
    }

    // MARK: - Output devices

    private var outputSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Output")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.bottom, 2)

            if audio.devices.isEmpty {
                Text("No output devices found")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(audio.devices) { device in
                    DeviceRow(device: device, isSelected: device.id == audio.defaultDeviceID) {
                        audio.selectDevice(device)
                    }
                }
            }
        }
    }

    // MARK: - Per-app volume

    private var appsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Applications")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)

            ForEach(apps.items) { item in
                AppVolumeRow(item: item, devices: audio.devices)
            }
        }
    }
}

private struct DeviceRow: View {
    let device: AudioDevice
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(.quaternary)
                        .frame(width: 32, height: 32)
                    Image(systemName: device.kind.symbolName)
                        .font(.system(size: 14))
                        .foregroundStyle(isSelected ? Color.green : Color.primary)
                }

                Text(device.name)
                    .font(.system(size: 14))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 4)
    }
}

private struct AppVolumeRow: View {
    let item: AppAudioItem
    let devices: [AudioDevice]

    @EnvironmentObject private var apps: PerAppAudioController

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                appIcon
                    .resizable()
                    .frame(width: 20, height: 20)
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))

                Text(item.name)
                    .font(.system(size: 14))
                    .lineLimit(1)

                Spacer()

                outputMenu
            }

            PillSlider(
                value: Binding(
                    get: { item.volume },
                    set: { apps.setVolume($0, for: item) }
                ),
                height: 20
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
