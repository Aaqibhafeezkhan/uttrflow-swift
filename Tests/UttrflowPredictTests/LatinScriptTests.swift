import Testing

@testable import UttrflowPredict

@Suite("Which script a suggestion may write")
struct LatinScriptTests {
    @Test(
        "Latin with accents, emoji, symbols and any script's punctuation is Latin text.",
        arguments: [
            "haan theek hai", "café naïve Zoë", "cafe\u{301}", "on my way 🚗 👍🏽 🇮🇳 1️⃣ ❤️ 👨‍👩‍👧",
            "MitoActive™ ®©", "₹500 — “quoted” ½ ²", "ﬁne Ｆｕｌｌ ① 𝐚𝟏", "done।", "ok。", "",
            "git commit -m 'fix'",
        ])
    func latinTextIsLatin(text: String) {
        #expect(LatinScript.writes(text))
    }

    @Test(
        "A letter, mark or digit of any other script makes the text not Latin, however little of it there is.",
        arguments: [
            "नहीं", "ok नहीं", "ज़िंदगी", "abc ०१२", "你好", "こんにちは", "مرحبا", "Привет", "γειά", "٣", "𝛼", "𝐚𝛼",
            "a\u{93C}",
        ])
    func otherScriptsAreNot(text: String) {
        #expect(!LatinScript.writes(text))
    }

    @Test(
        "The person's earlier lines in another script are not part of the situation a suggestion is written from."
    )
    func recentLinesKeepOnlyLatin() {
        let situation = GenerationSituation(
            application: "Chat", recentLines: ["haan bilkul", "नहीं जाना", "kal milte hain", "ok 你好"])
        #expect(situation.recentLines == ["haan bilkul", "kal milte hain"])
        #expect(situation.choosing(["a"]).recentLines == ["haan bilkul", "kal milte hain"])
    }
}

@Suite("The suggestion filter's verdict at each edge of the shared Latin table")
struct LatinScriptBoundaryTests {
    @Test(
        "Each scalar keeps the verdict it had before the table was shared.",
        arguments: [
            (0x00E9, false), (0x0301, false), (0x0370, true), (0x0966, true), (0x1AB0, false),
            (0x1D00, false), (0x1EFF, false), (0x00B2, false), (0x2460, false), (0x2C60, false),
            (0xA720, false), (0xAB30, false), (0xFB00, false), (0xFE0F, false), (0xFE20, false),
            (0xFF10, false), (0xFF19, false), (0xFF21, false), (0xFF5A, false), (0xFF66, true),
            (0x1D400, false), (0x1D6A5, false), (0x1D6A8, true), (0x1D7CE, false), (0x1F1E6, false),
            (0xE0020, false), (0x0660, true), (0x3007, true),
        ] as [(UInt32, Bool)])
    func boundaries(value: UInt32, foreign: Bool) throws {
        let scalar = try #require(Unicode.Scalar(value))
        #expect(LatinScript.isForeign(scalar) == foreign)
    }
}
