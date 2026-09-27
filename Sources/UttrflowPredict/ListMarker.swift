/// The marker a list line starts with, which a notes app writes on Return before any of the item is typed.
public enum ListMarker {
    /// The glyphs that mark a bulleted item.
    public static let bullets: Set<Character> = ["-", "*", "+", "•", "◦", "‣", "▪", "–"]

    /// The checkbox states a task list writes after its bullet.
    public static let checkboxes: Set<String> = ["[]", "[ ]", "[x]", "[X]"]

    /// Whether `line` holds only list markers and whitespace, so nothing of the item has been typed.
    public static func isAlone(_ line: String) -> Bool {
        var rest = Substring(line)
        var markers = 0
        while true {
            rest = rest.drop(while: \.isWhitespace)
            guard !rest.isEmpty else { return markers > 0 }
            guard let length = marker(at: rest) else { return false }
            rest = rest.dropFirst(length)
            // A marker is a whole token, so `--` or `1.5` is text, not two markers.
            guard rest.first.map(\.isWhitespace) ?? true else { return false }
            markers += 1
        }
    }

    /// How many characters the marker at the start of `text` takes, or nil when it does not start with one.
    private static func marker(at text: Substring) -> Int? {
        if let first = text.first, bullets.contains(first) { return 1 }
        if let box = checkboxes.first(where: { text.hasPrefix($0) }) { return box.count }
        let digits = text.prefix(while: \.isASCIIDigit)
        guard !digits.isEmpty, digits.count <= 9 else { return nil }
        let after = text.dropFirst(digits.count).first
        return after == "." || after == ")" ? digits.count + 1 : nil
    }
}

extension Character {
    /// Whether this is one of `0` to `9`, which is what numbers an ordered list.
    fileprivate var isASCIIDigit: Bool { isASCII && isNumber }
}
