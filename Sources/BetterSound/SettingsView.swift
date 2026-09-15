import SwiftUI

struct SettingsView: View {
    @AppStorage("showDockIcon") private var showDockIcon = false
    @State private var launchAtLogin = LoginItemManager.isEnabled
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    Toggle(isOn: Binding(
                        get: { showDockIcon },
                        set: { newValue in
                            showDockIcon = newValue
                            NSApp.setActivationPolicy(newValue ? .regular : .accessory)
                        }
                    )) {
                        Label("Show icon in Dock", systemImage: "dock.rectangle")
                    }

                    Toggle(isOn: Binding(
                        get: { launchAtLogin },
                        set: { newValue in
                            launchAtLogin = newValue
                            LoginItemManager.setEnabled(newValue)
                        }
                    )) {
                        Label("Launch at login", systemImage: "power")
                    }
                }
            }
            .formStyle(.grouped)

            Divider()

            Button {
                openWindow(id: "about")
            } label: {
                Text("About BetterSound")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .padding(.vertical, 10)
        }
        .frame(width: 360, height: 210)
    }
}
