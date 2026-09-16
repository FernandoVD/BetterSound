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
                            // nothing, and plain `brew update` can skip
                            // resyncing a third-party tap like this one and
                            // leave upgrade seeing a stale "already
                            // installed" — --force is what actually
                            // guarantees a real check.
                            CopyableCommand(command: "brew update --force && brew upgrade --cask bettersound")

                            // Every update re-quarantines the app (no
                            // stable Developer ID signature), so this
                            // recurs too, not just on first install.
                            CopyableCommand(command: "xattr -cr /Applications/BetterSound.app")

                            // brew upgrade can insist nothing's new when a
                            // user's local tap clone just hasn't resynced —
                            // link straight to the fix instead of leaving
                            // them stuck on "already installed".
                            Link(destination: URL(string: "https://github.com/FernandoVD/BetterSound#updating")!) {
                                Text("Still says \"already installed\"?")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
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

            HStack {
                Button {
                    openWindow(id: "about")
                } label: {
                    Text("About BetterSound")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    NSApp.terminate(nil)
                } label: {
                    Text("Quit BetterSound")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
        .frame(width: 360, height: 360)
    }
}
