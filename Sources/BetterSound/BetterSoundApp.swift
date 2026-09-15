import SwiftUI

@main
struct BetterSoundApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var audio = AudioEngine()
    @StateObject private var apps = PerAppAudioController()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView()
                .environmentObject(audio)
                .environmentObject(apps)
        } label: {
            Image(systemName: audio.menuBarIcon)
        }
        .menuBarExtraStyle(.window)
        .commands {
            CommandGroup(replacing: .appInfo) {
                AboutMenuCommand()
            }
        }

        Window("About BetterSound", id: "about") {
            AboutView()
        }
        .windowResizability(.contentSize)

        Settings {
            SettingsView()
        }
    }
}

private struct AboutMenuCommand: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("About BetterSound") {
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: "about")
        }
    }
}
