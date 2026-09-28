private import Synchronization

/// How many characters were read while this was bound to `ShellPrompt.tally`.
package final class CharacterTally: Sendable {
    private let read = Mutex(0)

    package init() {}

    /// The characters read so far.
    package var count: Int { read.withLock { $0 } }

    func record(_ characters: Int) { read.withLock { $0 += characters } }
}

/// The user's own input on a terminal line, which Accessibility reports with the shell prompt in front of it.
public enum ShellPrompt {
    /// The characters a prompt ends with, every one of which a command may also legitimately contain.
    private static let terminators: Set<Character> = ["%", "$", "#", ">", "✗", "✔", "✓", "❯"]

    /// How far into a line a prompt is looked for, since a prompt is short and a pasted line need not be.
    package static let searchLimit = 4_096

    /// Counts the characters read while bound, so a test can bound the work without a clock.
    @TaskLocal package static var tally: CharacterTally?

    /// What the user typed on this line, or the whole line where no prompt stands in front of it.
    public static func input(in line: String) -> String {
        if let typed = afterArrowPrompt(in: line) { return typed }
        guard let terminator = promptEnd(in: line) else { return line }
        return String(line[line.index(after: terminator)...].drop(while: \.isWhitespace))
    }

    /// The marks an arrow prompt draws after the branch when the tree has changes, or has none.
    private static let changeMarks: Set<Character> = ["✗", "✔", "✓"]

    /// What follows a leading `➜  directory` prompt, with the `git:(branch)` and change mark a repository adds; absent where the line does not begin with one.
    private static func afterArrowPrompt(in line: String) -> String? {
        var rest = line.drop(while: \.isWhitespace)
        guard rest.first == "➜" else { return nil }
        rest = rest.dropFirst()
        // The theme draws the arrow and then two spaces, which a lone arrow typed as text never has.
        guard rest.prefix(while: \.isWhitespace).count >= 2 else { return nil }
        rest = rest.drop(while: \.isWhitespace).drop { !$0.isWhitespace }.drop(while: \.isWhitespace)
        let branch = rest.prefix { !$0.isWhitespace }
        if branch.hasSuffix(")"), let open = branch.firstIndex(of: "("), branch[..<open].hasSuffix(":"),
            branch[..<open].dropLast().allSatisfy(\.isLetter)
        {
            rest = rest.dropFirst(branch.count).drop(while: \.isWhitespace)
        }
        if let mark = rest.first, changeMarks.contains(mark), rest.dropFirst().first?.isWhitespace ?? true {
            rest = rest.dropFirst().drop(while: \.isWhitespace)
        }
        return String(rest)
    }

    /// What has been read of the line so far, carried forward so no terminator rereads the text before it.
    private struct Prefix {
        /// The character just before the one being read.
        var last: Character?
        /// Whether everything so far is whitespace.
        var isBlank = true
        /// Whether everything so far is whitespace or a chevron.
        var isChevrons = true
        /// Whether an at sign has been seen outside every quote.
        var hasAt = false

        /// Takes one more character into what has been read, noting whether a quote holds it.
        mutating func append(_ character: Character, quoted: Bool) {
            last = character
            isBlank = isBlank && character.isWhitespace
            isChevrons = isChevrons && (character == ">" || character.isWhitespace)
            hasAt = hasAt || (!quoted && character == "@")
        }
    }

    /// The first terminator within the search limit that is outside every quote and carries the evidence its character needs.
    private static func promptEnd(in line: String) -> String.Index? {
        var prefix = Prefix()
        var quote: Character?
        var escaped = false
        var read = 0
        defer { tally?.record(read) }
        var index = line.startIndex
        while index < line.endIndex, read < searchLimit {
            let character = line[index]
            let next = line.index(after: index)
            read += 1
            if escaped {
                escaped = false
            } else if let open = quote {
                if character == open {
                    quote = nil
                } else if open == "\"", character == "\\" {
                    escaped = true
                }
            } else if character == "'" || character == "\"" {
                quote = character
            } else if character == "\\" {
                escaped = true
            } else if terminators.contains(character),
                next == line.endIndex || line[next].isWhitespace,
                isPlausible(character, after: prefix)
            {
                return index
            }
            prefix.append(character, quoted: quote != nil)
            index = next
        }
        return nil
    }

    /// What each terminator demands of the text before it, since each is typed for other reasons too.
    private static func isPlausible(_ terminator: Character, after prefix: Prefix) -> Bool {
        switch terminator {
        // zsh puts a space before its `%`, and a percentage never does.
        case "%": prefix.last?.isWhitespace ?? true
        // A shell expands a bare `$` before a name, so one before a space is a prompt rather than a sigil.
        case "$": !(prefix.last?.isWhitespace ?? false)
        // A root prompt names a host or a database and touches its hash, which is what tells it from a trailing comment.
        case "#":
            prefix.isBlank || prefix.last == "=" || (prefix.hasAt && !(prefix.last?.isWhitespace ?? true))
        // A `>` is a redirection unless it is a run of them, or the tail of a `=>` prompt.
        case ">": prefix.isChevrons || prefix.last == "="
        // A tick, a cross and a chevron are drawn by prompt themes and typed by nobody.
        default: true
        }
    }
}
