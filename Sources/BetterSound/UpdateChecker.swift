import Foundation

/// Checks GitHub Releases for a newer version — no dependency, no silent
/// install. Since this build is ad-hoc signed and not notarized, a freshly
/// downloaded update would still hit the same Gatekeeper quarantine block
/// as a manual download, so a background auto-installer wouldn't actually
/// save the user anything; this just tells you a new version exists and
/// links straight to it.
@MainActor
final class UpdateChecker: ObservableObject {
    struct Release {
        let version: String
        let htmlURL: URL
    }

    @Published private(set) var availableUpdate: Release?
    @Published private(set) var isChecking = false
    @Published private(set) var lastCheckedAt: Date?
    @Published private(set) var checkFailed = false

    private let repo = "FernandoVD/BetterSound"
    private var timer: Timer?
    private let checkInterval: TimeInterval = 24 * 60 * 60

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    init() {
        syncPeriodicChecks(enabled: UserDefaults.standard.bool(forKey: "autoCheckForUpdates"))
    }

    func syncPeriodicChecks(enabled: Bool) {
        timer?.invalidate()
        timer = nil
        guard enabled else { return }

        Task { await check() }
        timer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.check() }
        }
    }

    func check() async {
        isChecking = true
        checkFailed = false
        defer { isChecking = false }
        lastCheckedAt = Date()

        guard let url = URL(string: "https://api.github.com/repos/\(repo)/releases/latest") else { return }
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tagName = json["tag_name"] as? String,
                  let htmlURLString = json["html_url"] as? String,
                  let htmlURL = URL(string: htmlURLString) else {
                checkFailed = true
                return
            }

            let latestVersion = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName
            availableUpdate = Self.isVersion(latestVersion, newerThan: currentVersion)
                ? Release(version: latestVersion, htmlURL: htmlURL)
                : nil
        } catch {
            checkFailed = true
        }
    }

    private static func isVersion(_ a: String, newerThan b: String) -> Bool {
        let aParts = a.split(separator: ".").compactMap { Int($0) }
        let bParts = b.split(separator: ".").compactMap { Int($0) }
        for i in 0..<max(aParts.count, bParts.count) {
            let x = i < aParts.count ? aParts[i] : 0
            let y = i < bParts.count ? bParts[i] : 0
            if x != y { return x > y }
        }
        return false
    }
}
