// Tests that a piece the recogniser looped is written once, and a sentence really said twice is kept twice.
import Testing

@testable import UttrflowCore
@testable import UttrflowSpeech

@Suite("A piece the recogniser looped")
struct RecognitionLoopTests {
    private let sentence = "Kal meeting hai, please slides ready rakhna."

    private func heard(_ text: String, seconds: Double) -> Transcription {
        Transcription(
            text: text,
            segments: [
                TranscriptionSegment(
                    text: text, start: .zero, end: .seconds(seconds),
                    words: text.split(separator: " ").map {
                        TranscribedWord(text: String($0), confidence: 0.9)
                    })
            ],
            audioDuration: .seconds(seconds))
    }

    @Test("a quoted sentence written twice in under three seconds is written once, without the quotes")
    func quotedLoopIsWrittenOnce() {
        let looped = "\"\(sentence)\" \"\(sentence)\""

        let undone = RecognitionLoop.undone(heard(looped, seconds: 2.76), speechDuration: .seconds(2.76))

        #expect(undone.text == sentence)
        #expect(undone.segments.map(\.text) == [sentence])
        #expect(undone.segments.first?.words.map(\.text) == sentence.split(separator: " ").map(String.init))
    }

    @Test("a loop whose second copy was heard slightly differently is still written once")
    func nearCopyIsWrittenOnce() {
        let looped =
            "KAL MEETING HAI PLEASE SLIDES READY RAKHNA KAL MEETING HAYE PLEASE SLIDES READY RAKHNA"

        let undone = RecognitionLoop.undone(heard(looped, seconds: 2.76), speechDuration: .seconds(2.76))

        #expect(undone.text == "KAL MEETING HAI PLEASE SLIDES READY RAKHNA")
    }

    @Test("a sentence said twice in a piece long enough to hold both is kept twice")
    func realRepeatIsKept() {
        let twice = "I will send the file today. I will send the file today."

        let undone = RecognitionLoop.undone(heard(twice, seconds: 6), speechDuration: .seconds(6))

        #expect(undone.text == twice)
    }

    @Test("two different sentences spoken fast are left alone")
    func differentHalvesAreKept() {
        let fast = "send the file today and call me back tonight"

        let undone = RecognitionLoop.undone(heard(fast, seconds: 1.5), speechDuration: .seconds(1.5))

        #expect(undone.text == fast)
    }

    @Test("a short word said twice quickly is ordinary speech")
    func shortRepeatIsKept() {
        let undone = RecognitionLoop.undone(heard("no no", seconds: 0.3), speechDuration: .seconds(0.3))

        #expect(undone.text == "no no")
    }

    @Test(
        "quotes are taken off only when they wrap the whole piece and no other quote is there",
        arguments: [
            ("\"Ship it today.\"", "Ship it today."),
            ("\u{201C}Ship it today.\u{201D}", "Ship it today."),
            ("\"Ship it\" today.", "\"Ship it\" today."),
            ("He said \"ship it\" and \"test it\".", "He said \"ship it\" and \"test it\"."),
        ])
    func wrappingQuotesOnly(text: String, expected: String) {
        let undone = RecognitionLoop.undone(heard(text, seconds: 3), speechDuration: .seconds(3))

        #expect(undone.text == expected)
    }
}
