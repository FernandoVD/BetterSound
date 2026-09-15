import SwiftUI

/// Styled to sit next to Control Center's own Sound module: a floating rounded
/// panel, a master slider up top, the output picker below, then per-app volume.
/// About/Settings live in the app's own menu (top-left, next to the Apple menu)
/// instead of cluttering this popover — this stays audio-controls-only.
struct MenuBarContentView: View {
    @EnvironmentObject private var audio: AudioEngine
    @EnvironmentObject private var apps: PerAppAudioController

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            volumeSection
            Divider()
            outputSection
            Divider()
            appsSection
        }
        .padding(14)
        .frame(width: 300)
    }

    // MARK: - Master volume

    private var volumeSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Sound")
                .font(.headline)

            HStack(spacing: 10) {
                Button {
                    audio.toggleMute()
                } label: {
                    Image(systemName: audio.isMuted ? "speaker.slash.fill" : "speaker.fill")
                        .font(.system(size: 13))
                        .frame(width: 16)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Slider(
                    value: Binding(
                        get: { audio.isMuted ? 0 : audio.masterVolume },
                        set: { audio.setMasterVolume($0) }
                    ),
                    in: 0...1
                )

                Image(systemName: "speaker.wave.3.fill")
                    .font(.system(size: 13))
                    .frame(width: 16)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Output devices

    private var outputSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Output")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
                .padding(.bottom, 2)

            if audio.devices.isEmpty {
                Text("No output devices found")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
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
        VStack(alignment: .leading, spacing: 2) {
            Text("Applications")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
                .padding(.bottom, 2)

            if apps.items.isEmpty {
                Text("No open applications")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(apps.items) { item in
                            AppVolumeRow(item: item, devices: audio.devices)
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .frame(maxHeight: 220)
            }
        }
    }
}

private struct DeviceRow: View {
    let device: AudioDevice
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: device.kind.symbolName)
                    .font(.system(size: 13))
                    .frame(width: 18)
                    .foregroundStyle(isSelected ? Color.accentColor : .primary)

                Text(device.name)
                    .font(.callout)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isHovering ? Color.primary.opacity(0.08) : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}

private struct AppVolumeRow: View {
    let item: AppAudioItem
    let devices: [AudioDevice]

    @EnvironmentObject private var apps: PerAppAudioController

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                appIcon
                    .resizable()
                    .frame(width: 16, height: 16)

                Text(item.name)
                    .font(.callout)
                    .lineLimit(1)

                Spacer()

                outputMenu
            }

            Slider(
                value: Binding(
                    get: { item.volume },
                    set: { apps.setVolume($0, for: item) }
                ),
                in: 0...1
            )
            .padding(.leading, 24)
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
