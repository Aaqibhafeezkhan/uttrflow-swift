// Keeps a sign-off from being signed with a name the person never wrote.

import Foundation

/// A closing such as "Kind regards," and the signature a completion may hang after it.
enum SignOff {
    /// Closings a signature follows, compared lowercased with the comma and outer spaces removed.
    static let closings: Set<String> = [
        "all the best", "best", "best regards", "best wishes", "cheers", "kind regards", "many thanks",
        "regards", "sincerely", "take care", "thank you", "thanks", "thanks again", "warm regards",
        "warmly", "with thanks", "yours", "yours sincerely", "yours truly",
    ]

    /// The line cut back to its closing unless the name after it is one the person wrote, or nothing when that leaves no continuation.
    static func unsigned(_ line: String, typed: String, ownLines: [String]) -> String? {
        guard let comma = line.firstIndex(of: ","),
            closings.contains(line[..<comma].trimmingCharacters(in: .whitespaces).lowercased())
        else { return line }
        let signature = words(of: String(line[line.index(after: comma)...]))
        // A signature is a name: a capitalised word or three, never a sentence.
        guard (1...longestSignature).contains(signature.count),
            signature.allSatisfy({ $0.first?.isUppercase == true })
        else { return line }
        let own = Set((ownLines + [typed]).flatMap(words(of:)).map { $0.lowercased() })
        // Only a name the person has written is theirs to sign with; any other was read on screen or made up.
        guard !signature.allSatisfy({ own.contains($0.lowercased()) }) else { return line }
        let closing = String(line[...comma])
        return closing.count > typed.count ? closing : nil
    }

    /// The most words a signature after a closing runs to.
    static let longestSignature = 3

    /// The words of a text, with the punctuation around them dropped.
    private static func words(of text: String) -> [String] {
        text.split { !$0.isLetter && !$0.isNumber && $0 != "'" && $0 != "-" }.map(String.init)
    }
}
