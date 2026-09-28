import Testing

@testable import UttrflowCore

/// The words of `text` as the passes see them.
private func shapes(_ text: String) -> [WordShape] {
    text.split(separator: " ").map { WordShape(String($0)) }
}

@Suite("QuestionShape")
struct QuestionShapeTests {
    @Test(
        "reads a direct question from its word order",
        arguments: [
            "where did you put the keys", "which branch should I merge into",
            "what time is the meeting tomorrow", "how many people are coming",
            "what's the status of the release", "can you review the pull request", "did the build go green",
            "is anyone using the room", "do you have a minute", "have you seen the numbers",
            "Would you like some coffee", "it's a long weekend isn't it",
            "you know the answer don\u{2019}t you",
            "so did you finish the slides", "okay can we start the call", "I sent the file, did you get it",
            "kya tum aa rahe ho", "kab tak ho jayega", "tum aa rahe ho kya",
        ])
    func asks(text: String) {
        #expect(QuestionShape.asks(shapes(text)))
    }

    @Test(
        "leaves a statement, an indirect question and a command alone",
        arguments: [
            "I wonder if the build passed", "what we need is more time", "where I put the keys is a mystery",
            "I don't know why the build failed", "when the build finishes we ship",
            "do the dishes before you leave",
            "have a great weekend", "tell me what you think", "that's right", "turn right at the station",
            "if it rains, we stay in", "", "kya baat hai",
            // Two clauses run together, so where the question ends cannot be told.
            "are you around yet i should be there in ten",
        ])
    func leaves(text: String) {
        #expect(!QuestionShape.asks(shapes(text)))
    }
}
