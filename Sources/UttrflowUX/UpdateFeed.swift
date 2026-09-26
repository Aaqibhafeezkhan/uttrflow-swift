// Which update feed this build will trust, which is a different question from when an update may install.
public import struct Foundation.URL

/// The feed an updater may read from: `https`, or `http` to this machine, so a release can be rehearsed.
public enum UpdateFeed {
    /// The hosts that are this Mac, and the only ones a plain-`http` feed may name.
    static let loopbackHosts: Set<String> = ["127.0.0.1", "localhost", "::1"]

    /// Whether a feed at this URL may be read; anything not understood is refused rather than guessed at.
    public static func isAcceptable(_ url: URL) -> Bool {
        // Both are compared lower-cased: a scheme and a host are case-insensitive, and a feed is configuration.
        guard let scheme = url.scheme?.lowercased(), let host = url.host?.lowercased(), !host.isEmpty else {
            return false
        }
        if scheme == "https" { return true }
        return scheme == "http" && loopbackHosts.contains(host)
    }
}
