// Recognises a web address that is itself a credential.

/// A URL whose holder can act with it: a chat webhook, or one signed or carrying a token. See Docs/clipboard-secrets.md.
enum BearerURLShape {
    /// Whether any URL in the text is a bearer credential, reading each byte of it a bounded number of times.
    static func matches(_ text: String, read: inout Int) -> Bool {
        var count = 0
        defer { read += count }
        return ClipBytes.read(text) { _, bytes in
            var from = 0
            while let separator = find(bytes, from: from) {
                let start = separator + 3
                var end = start
                while end < bytes.count, !endsURL(bytes[end]) { end += 1 }
                count += end - separator
                if isBearer(URLParts(bytes, from: start, to: end)) { return true }
                from = end
            }
            return false
        }
    }

    /// Where the next `://` starts at or after `from`.
    private static func find(_ bytes: UnsafeBufferPointer<UInt8>, from: Int) -> Int? {
        var offset = from
        while offset + 3 <= bytes.count {
            if bytes[offset] == UInt8(ascii: ":"), bytes[offset + 1] == UInt8(ascii: "/"),
                bytes[offset + 2] == UInt8(ascii: "/")
            {
                return offset
            }
            offset += 1
        }
        return nil
    }

    /// Whether a byte cannot stand in a URL as copied: ASCII space or control, a quote or an angle bracket.
    private static func endsURL(_ byte: UInt8) -> Bool {
        byte <= 0x20 || byte == 0x7F || byte == UInt8(ascii: "\"") || byte == UInt8(ascii: "'")
            || byte == UInt8(ascii: "<") || byte == UInt8(ascii: ">") || byte == UInt8(ascii: "`")
    }

    private static func isBearer(_ url: URLParts) -> Bool {
        isWebhook(host: url.host, path: url.path)
            || url.parameters.contains { name, value in
                value.count >= shortestValue && credentialParameters.contains(name)
            }
    }

    /// The fewest characters a parameter's value needs to be a credential rather than a placeholder.
    private static let shortestValue = 8

    /// Query and fragment parameters that carry a signature or a token, lowercase.
    private static let credentialParameters: Set<String> = [
        "sig", "signature", "x-amz-signature", "x-goog-signature",
        "access_token", "id_token", "refresh_token", "token",
    ]

    /// Incoming-webhook addresses of the chat services, which post as whoever holds them.
    private static func isWebhook(host: String, path: [Substring]) -> Bool {
        switch host {
        case "hooks.slack.com":
            return ["services", "workflows", "triggers"].contains(path.first ?? "") && path.count >= 3
        case "discord.com", "discordapp.com", "ptb.discord.com", "canary.discord.com":
            guard path.first == "api", let hook = path.firstIndex(of: "webhooks") else { return false }
            return path.count - hook >= 3
        case "outlook.office.com":
            return path.first == "webhook" && path.count >= 2
        default:
            return host.hasSuffix(".webhook.office.com") && path.first == "webhookb2" && path.count >= 2
        }
    }
}

/// The pieces of one URL's bytes after `://`: its host lowercased, its path's segments and its parameters.
private struct URLParts {
    var host = ""
    var path: [Substring] = []
    var parameters: [(name: String, value: Substring)] = []

    init(_ bytes: UnsafeBufferPointer<UInt8>, from start: Int, to end: Int) {
        let text = String(decoding: UnsafeBufferPointer(rebasing: bytes[start..<end]), as: UTF8.self)
        let beforeQuery = text.prefix { $0 != "?" && $0 != "#" }
        let authority = beforeQuery.prefix { $0 != "/" }
        let hostAndPort = authority.split(separator: "@", omittingEmptySubsequences: false).last ?? ""
        host = String(hostAndPort.prefix { $0 != ":" }).lowercased()
        path = beforeQuery.dropFirst(authority.count).split(separator: "/")
        let rest = text.dropFirst(beforeQuery.count).dropFirst()
        parameters = rest.split { $0 == "&" || $0 == ";" || $0 == "#" || $0 == "?" }.map { pair in
            let name = pair.prefix { $0 != "=" }
            return (name.lowercased(), pair.dropFirst(name.count + 1))
        }
    }
}
