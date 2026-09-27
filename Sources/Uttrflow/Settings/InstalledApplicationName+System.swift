import AppKit
import Synchronization
import UttrflowPredict

/// Finds the name an application shows the user, from the running copy or its bundle on disk.
enum InstalledApplicationName {
    /// Names already found, so a list redraw does not ask LaunchServices again.
    private static let found = Mutex<[String: String]>([:])

    /// Hands this lookup to the suggestions list, which otherwise names an application by its identifier.
    static func install() {
        SuggestionApplications.lookUpInstalledNames(with: lookUp)
    }

    /// The running application's name, else the bundle's display name, bundle name or file name.
    @Sendable static func lookUp(_ bundleIdentifier: String) -> String? {
        let key = bundleIdentifier.lowercased()
        if let known = found.withLock({ $0[key] }) { return known }
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
            .first?.localizedName
        let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)
        let bundle = url.flatMap { Bundle(url: $0) }
        let name = SuggestionApplications.firstUsable([
            running,
            bundle?.localizedInfoDictionary?["CFBundleDisplayName"] as? String,
            bundle?.infoDictionary?["CFBundleDisplayName"] as? String,
            bundle?.localizedInfoDictionary?["CFBundleName"] as? String,
            bundle?.infoDictionary?["CFBundleName"] as? String,
            url.map { FileManager.default.displayName(atPath: $0.path(percentEncoded: false)) },
        ])
        if let name { found.withLock { $0[key] = name } }
        return name
    }
}
