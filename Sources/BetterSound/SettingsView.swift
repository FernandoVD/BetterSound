import SwiftUI

struct SettingsView: View {
    @AppStorage("showDockIcon") private var showDockIcon = false
    @State private var launchAtLogin = LoginItemManager.isEnabled

    var body: some View {
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
        .frame(width: 360, height: 160)
    }
}
