import SwiftUI

struct SettingsView: View {
    @AppStorage("showDockIcon") private var showDockIcon = false
    @AppStorage("autoCheckForUpdates") private var autoCheckForUpdates = false
    @State private var launchAtLogin = LoginItemManager.isEnabled
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var updates: UpdateChecker

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

                Section {
                    Toggle(isOn: Binding(
                        get: { autoCheckForUpdates },
                        set: { newValue in
                            autoCheckForUpdates = newValue
                            updates.syncPeriodicChecks(enabled: newValue)
                        }
                    )) {
                        Label("Automatically check for updates", systemImage: "arrow.triangle.2.circlepath")
                    }

                    HStack {
                        Label("Check for Updates…", systemImage: "arrow.down.circle")
                        Spacer()
                        if updates.isChecking {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard !updates.isChecking else { return }
                        Task { await updates.check() }
                    }

                    if let update = updates.availableUpdate {
                        VStack(alignment: .leading, spacing: 4) {
                            Link(destination: update.htmlURL) {
                                Label("Update available: v\(update.version)", systemImage: "arrow.up.circle.fill")
                                    .foregroundStyle(Color.accentColor)
                            }

                            // brew install a second time silently does
                            // nothing — give the actual upgrade command.
                            CopyableCommand(command: "brew upgrade --cask bettersound")
                        }
                    } else if updates.checkFailed {
                        Label("Couldn't check for updates", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.secondary)
                    } else if updates.lastCheckedAt != nil {
                        Label("You're up to date (v\(updates.currentVersion))", systemImage: "checkmark.circle")
                            .foregroundStyle(.secondary)
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
        .frame(width: 360, height: 360)
    }
}
