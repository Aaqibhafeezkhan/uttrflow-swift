import Testing

@testable import UttrflowContext

@Suite("Reading a terminal line for its prompt costs one pass over a bounded stretch")
struct ShellPromptScalingTests {
    /// The characters one reading of this line takes.
    private static func charactersRead(_ line: String) -> Int {
        let tally = CharacterTally()
        ShellPrompt.$tally.withValue(tally) { _ = ShellPrompt.input(in: line) }
        return tally.count
    }

    /// A line of hashes and chevrons, each a terminator whose evidence is the text before it.
    private static func terminators(_ length: Int) -> String {
        String(String(repeating: "ab# a > ", count: length / 8 + 1).prefix(length))
    }

    @Test("A line under the limit is read once, a character at a time, however many terminators it holds.")
    func readsEachCharacterOnce() {
        for length in [100, 1_000, 4_000] {
            let read = Self.charactersRead(Self.terminators(length))
            #expect(read == length, "\(length) characters took \(read) reads")
        }
    }

    @Test("A line past the limit costs what the limit costs, so a pasted megabyte reads like four kilobytes.")
    func longLinesCostTheLimit() {
        let limit = ShellPrompt.searchLimit
        for length in [10_000, 100_000, 1_000_000] {
            #expect(Self.charactersRead(Self.terminators(length)) == limit)
        }
    }

    @Test("A prompt is found up to the limit and not past it.")
    func promptsEndInsideTheLimit() {
        let near = String(repeating: "a", count: ShellPrompt.searchLimit - 1) + "$ ls"
        let far = String(repeating: "a", count: ShellPrompt.searchLimit) + "$ ls"

        #expect(ShellPrompt.input(in: near) == "ls")
        #expect(ShellPrompt.input(in: far) == far)
    }

    @Test("Every short line reads the same as the rescanning reading it replaces.")
    func agreesWithTheRescan() {
        let pieces: [String] = [
            "a", "@", "=", "#", ">", "$", "%", "'", "\"", "\\", " ", "\t", "✗", "❯", "✔", "e\u{301}",
            "\u{301}",
        ]
        var random = Seeded(seed: 405)
        for _ in 0..<5_000 {
            let line = (0..<Int.random(in: 0...24, using: &random)).map { _ in random.pick(pieces) }.joined()
            #expect(
                ShellPrompt.input(in: line) == RescanningShellPrompt.input(in: line),
                "\(line.debugDescription)")
        }
    }
}

/// The reading that rescanned the prefix at each terminator, kept as the oracle for the single pass.
private enum RescanningShellPrompt {
    private static let terminators: Set<Character> = ["%", "$", "#", ">", "✗", "✔", "✓", "❯"]

    static func input(in line: String) -> String {
        let characters = Array(line)
        guard let terminator = promptEnd(in: characters) else { return line }
        return String(characters[(terminator + 1)...].drop(while: \.isWhitespace))
    }

    private static func promptEnd(in characters: [Character]) -> Int? {
        var quote: Character?
        var unquotedAt = false
        var index = 0
        while index < characters.count {
            let character = characters[index]
            let wasQuoted = quote != nil
            defer { unquotedAt = unquotedAt || (!wasQuoted && character == "@") }
            if let open = quote {
                if character == open { quote = nil }
            } else if character == "'" || character == "\"" {
                quote = character
            } else if character == "\\" {
                if index + 1 < characters.count, characters[index + 1] == "@" { unquotedAt = true }
                index += 1
            } else if endsAPrompt(characters, at: index, unquotedAt: unquotedAt) {
                return index
            }
            index += 1
        }
        return nil
    }

    private static func endsAPrompt(_ characters: [Character], at index: Int, unquotedAt: Bool) -> Bool {
        guard terminators.contains(characters[index]) else { return false }
        let next = index + 1 < characters.count ? characters[index + 1] : nil
        guard next?.isWhitespace ?? true else { return false }
        let prefix = characters[..<index]
        return switch characters[index] {
        case "%": prefix.last?.isWhitespace ?? true
        case "$": !(prefix.last?.isWhitespace ?? false)
        case "#":
            prefix.allSatisfy(\.isWhitespace) || prefix.last == "="
                || (unquotedAt && !(prefix.last?.isWhitespace ?? true))
        case ">": prefix.allSatisfy { $0 == ">" || $0.isWhitespace } || prefix.last == "="
        default: true
        }
    }
}
