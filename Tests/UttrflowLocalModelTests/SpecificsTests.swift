import Testing
import UttrflowPredict

@testable import UttrflowLocalModel

/// A chat field with a screen and the person's own lines, which is where a made-up specific does harm.
private func chat(screen: String? = nil, own: [String] = [], choices: [String] = []) -> GenerationSituation {
    GenerationSituation(
        application: "Chat", field: "Message", surroundings: screen, recentLines: own, isMultiline: true,
        choices: choices)
}

@Suite("A model's line never adds a number, an amount or an address nobody gave it")
struct SpecificsTests {
    @Test(
        "A made-up specific is refused.",
        arguments: [
            ("Can we meet tomorrow at ", "Can we meet tomorrow at 3pm to go over it?"),
            ("The total comes to ", "The total comes to $120 before tax."),
            ("Call me on 98", "Call me on 9876543210"),
            ("Send it to ", "Send it to sam@example.com please"),
            ("The docs are at ", "The docs are at https://example.com/guide"),
            ("See github.com/", "See github.com/example/tool"),
            ("Growth was ", "Growth was 12% this quarter"),
            ("The meeting is on the ", "The meeting is on the 14th"),
            ("Fixed in ", "Fixed in #2041"),
        ])
    func madeUpSpecificsAreRefused(typed: String, line: String) {
        #expect(!Specifics.areGrounded(line, typed: typed, in: chat()))
        #expect(CompletionText.finished([line], typed: typed, in: chat()).isEmpty)
    }

    @Test("A specific copied from the screen, the person's lines, the typed text or the machine is kept.")
    func groundedSpecificsAreKept() {
        let line = "Can we meet tomorrow at 3pm to go over it?"
        let typed = "Can we meet tomorrow at "
        #expect(Specifics.areGrounded(line, typed: typed, in: chat(screen: "Priya: free at 3pm?")))
        #expect(Specifics.areGrounded(line, typed: typed, in: chat(own: ["3pm works"])))
        #expect(Specifics.areGrounded(line, typed: typed, in: chat(choices: ["3pm"])))
        #expect(Specifics.areGrounded("Invoice 1,250 is paid", typed: "Invoice 1,250 ", in: chat()))
        #expect(
            !Specifics.areGrounded("Invoice 1,250.00 is paid", typed: "Invoice ", in: chat(own: ["1,250"])))
    }

    @Test("Words with no specific in them, and names that carry a digit, are left alone.")
    func ordinaryWordsAreLeftAlone() {
        #expect(Specifics.areGrounded("Sounds good, see you then", typed: "Sounds", in: chat()))
        #expect(Specifics.areGrounded("I use python3 for that", typed: "I use", in: chat()))
        #expect(Specifics.areGrounded("Open docs/guide.md first", typed: "Open", in: chat()))
        #expect(Specifics.areGrounded("Ping me @ noon", typed: "Ping", in: chat()))
        #expect(Specifics.specifics(in: "It costs 12.50", after: "It costs 12.50") == [])
    }

    @Test("Each shape of specific is recognised on its own.")
    func shapesAreRecognised() {
        for token in [
            "3pm", "12.50", "#12", "$5", "€20", "50%", "a@b", "http://x", "www.example.com", "example.com/a",
        ] {
            #expect(Specifics.isSpecific(token), "\(token)")
        }
        for token in ["python3", "utf8", "hello", "docs/guide.md", "e.g", "@", "readme.md"] {
            #expect(!Specifics.isSpecific(token), "\(token)")
        }
    }
}
