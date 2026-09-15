import SwiftUI

struct SettingsView: View {
    @AppStorage("showDockIcon") private var showDockIcon = false
    @State private var launchAtLogin = LoginItemManager.isEnabled

    var body: some View {
        Form {
            Toggle("Show icon in Dock", isOn: Binding(
                get: { showDockIcon },
                set: { newValue in
                    showDockIcon = newValue
                    NSApp.setActivationPolicy(newValue ? .regular : .accessory)
                }
            ))

            Toggle("Launch at login", isOn: Binding(
                get: { launchAtLogin },
                set: { newValue in
                    launchAtLogin = newValue
                    LoginItemManager.setEnabled(newValue)
                }
            ))
        }
        .padding(20)
        .frame(width: 320)
    }
}
