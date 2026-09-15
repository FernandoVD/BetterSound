import SwiftUI

@main
struct BetterSoundApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var audio = AudioEngine()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView()
                .environmentObject(audio)
        } label: {
            Image(systemName: audio.menuBarIcon)
        }
        .menuBarExtraStyle(.window)

        Window("About BetterSound", id: "about") {
            AboutView()
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }
}
