import SwiftUI

/// Explicit VStack layout, not Form/List: a MenuBarExtra(.window) popover has
/// no real hosting window frame, and Form/List's auto-sizing collapses badly
/// inside one. Section "cards" use system semantic materials (`.quaternary`)
/// so they still adapt correctly to Light/Dark and the Tahoe Clear/Tinted
/// appearance styles, without depending on Form's layout machinery.
struct MenuBarContentView: View {
    @EnvironmentObject private var audio: AudioEngine
    @EnvironmentObject private var apps: PerAppAudioController

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionCard("Sound") {
                HStack(spacing: 10) {
                    Button {
                        audio.toggleMute()
                    } label: {
                        Image(systemName: audio.isMuted ? "speaker.slash.fill" : "speaker.fill")
                            .foregroundStyle(.secondary)
                            .frame(width: 16)
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
                        .foregroundStyle(.secondary)
                        .frame(width: 16)
                }
            }

            sectionCard("Output") {
                if audio.devices.isEmpty {
                    Text("No output devices found")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(spacing: 2) {
                        ForEach(audio.devices) { device in
                            DeviceRow(device: device, isSelected: device.id == audio.defaultDeviceID) {
                                audio.selectDevice(device)
                            }
                        }
                    }
                }
            }

            sectionCard("Applications") {
                if apps.items.isEmpty {
                    Text("No open applications")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(spacing: 14) {
                        ForEach(apps.items) { item in
                            AppVolumeRow(item: item, devices: audio.devices)
                        }
                    }
                }
            }
        }
        .padding(14)
        .frame(width: 320)
    }

    @ViewBuilder
    private func sectionCard<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 2)

            VStack(alignment: .leading, spacing: 6) {
                content()
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}

private struct DeviceRow: View {
    let device: AudioDevice
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: device.kind.symbolName)
                    .frame(width: 18)
                    .foregroundStyle(isSelected ? Color.accentColor : .primary)

                Text(device.name)
                    .font(.callout)
                    .lineLimit(1)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }
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
        VStack(alignment: .leading, spacing: 6) {
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
