import SwiftUI

/// Styled to sit next to Control Center's own Sound module: a floating rounded
/// panel, a big master slider up top, then a plain list of output devices.
struct MenuBarContentView: View {
    @EnvironmentObject private var audio: AudioEngine
    @Environment(\.openWindow) private var openWindow
    @AppStorage("launchAtLogin") private var launchAtLoginStored = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            volumeSection
            Divider()
            outputSection
            Divider()
            footer
        }
        .padding(14)
        .frame(width: 280)
        .onAppear {
            launchAtLoginStored = LoginItemManager.isEnabled
        }
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

    // MARK: - Footer

    private var footer: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("Launch at Login", isOn: Binding(
                get: { launchAtLoginStored },
                set: { newValue in
                    launchAtLoginStored = newValue
                    LoginItemManager.setEnabled(newValue)
                }
            ))
            .toggleStyle(.switch)
            .font(.callout)

            HStack {
                Button("About BetterSound") {
                    openWindow(id: "about")
                    NSApp.activate(ignoringOtherApps: true)
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.secondary)

                Spacer()

                Button("Quit") {
                    NSApp.terminate(nil)
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.secondary)
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
