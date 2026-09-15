import SwiftUI

/// Built from SwiftUI's native grouped Form — the same building block System
/// Settings.app itself uses — so it automatically matches whatever appearance
/// mode is active (Light/Dark, and the Tahoe Icon & Window styles like Clear
/// or Tinted) without us hand-drawing any of it.
struct MenuBarContentView: View {
    @EnvironmentObject private var audio: AudioEngine
    @EnvironmentObject private var apps: PerAppAudioController

    var body: some View {
        Form {
            Section("Sound") {
                HStack(spacing: 10) {
                    Button {
                        audio.toggleMute()
                    } label: {
                        Image(systemName: audio.isMuted ? "speaker.slash.fill" : "speaker.fill")
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
                        .foregroundStyle(.secondary)
                }
            }

            Section("Output") {
                if audio.devices.isEmpty {
                    Text("No output devices found")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(audio.devices) { device in
                        Button {
                            audio.selectDevice(device)
                        } label: {
                            HStack {
                                Label(device.name, systemImage: device.kind.symbolName)
                                Spacer()
                                if device.id == audio.defaultDeviceID {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Section("Applications") {
                if apps.items.isEmpty {
                    Text("No open applications")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(apps.items) { item in
                        AppVolumeRow(item: item, devices: audio.devices)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 340)
        .frame(maxHeight: 560)
    }
}

private struct AppVolumeRow: View {
    let item: AppAudioItem
    let devices: [AudioDevice]

    @EnvironmentObject private var apps: PerAppAudioController

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label {
                    Text(item.name).lineLimit(1)
                } icon: {
                    appIcon
                        .resizable()
                        .frame(width: 18, height: 18)
                }

                Spacer()

                outputMenu
            }

            HStack(spacing: 8) {
                Image(systemName: "speaker.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Slider(
                    value: Binding(
                        get: { item.volume },
                        set: { apps.setVolume($0, for: item) }
                    ),
                    in: 0...1
                )
            }
        }
        .padding(.vertical, 2)
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
                .foregroundStyle(.secondary)
        }
        .menuStyle(.borderlessButton)
        .frame(width: 24)
    }

    private var outputIconName: String {
        if let id = item.outputDeviceID, let device = devices.first(where: { $0.id == id }) {
            return device.kind.symbolName
        }
        return "arrow.triangle.branch"
    }
}
