import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "speaker.wave.3.fill")
                .font(.system(size: 52))
                .foregroundStyle(Color.accentColor.gradient)
                .padding(.bottom, 4)

            Text("BetterSound")
                .font(.system(size: 20, weight: .semibold))

            Text("Version \(Bundle.main.shortVersion) (\(Bundle.main.buildNumber))")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            Text("A lightweight, open-source volume mixer for the menu bar.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 10)
                .padding(.horizontal, 20)

            Spacer().frame(height: 14)

            HStack(spacing: 4) {
                Text("Created by")
                    .foregroundStyle(.secondary)
                Link("FernandoVD", destination: URL(string: "https://github.com/FernandoVD")!)
                Text("· 2026")
                    .foregroundStyle(.secondary)
            }
            .font(.system(size: 12))

            Link("View source on GitHub", destination: URL(string: "https://github.com/FernandoVD/BetterSound")!)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(28)
        .frame(width: 300)
        .fixedSize()
    }
}

private extension Bundle {
    var shortVersion: String { infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0" }
    var buildNumber: String { infoDictionary?["CFBundleVersion"] as? String ?? "1" }
}
