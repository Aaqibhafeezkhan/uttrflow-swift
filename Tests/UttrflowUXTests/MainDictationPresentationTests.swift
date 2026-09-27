// Tests for the dictation figures: words, streak, pace and the share left as dictated.
import Foundation
import UttrflowCore
import UttrflowHistory
import UttrflowSettings
import Testing

@testable import UttrflowUX

extension HistoryFixture {
    /// A dictation that was timed, so the pace figures have something to work from.
    static func timed(
        _ text: String, seconds: Int, minutesAgo: Int = 0, daysAgo: Int = 0,
        application: String? = "Slack", changes: RecordedChanges? = RecordedChanges()
    ) -> HistoryEntry {
        HistoryEntry(
            id: UUID(), text: text,
            when: now.addingTimeInterval(Double(-minutesAgo) * 60 + Double(-daysAgo) * 86_400),
            applicationName: application, spokenFor: .seconds(seconds), changes: changes)
    }

    /// One change, in the terms the accuracy figure counts: which of the words the user said it covered.
    static func change(
        _ heard: String, _ wrote: String, over spoken: Range<Int>
    ) -> RecordedCorrection {
        RecordedCorrection(
            heard: heard, wrote: wrote, wordRange: spoken, entryID: UUID(),
            reason: .heardAsStrayLetters, heardConfidence: 0.3)
    }

    /// A dictation whose utterance was counted; `text` and `spokenWords` differ on purpose.
    static func measured(
        _ text: String, spokenWords: Int, changes: [RecordedCorrection] = [],
        daysAgo: Int = 0
    ) -> HistoryEntry {
        entry(
            text, daysAgo: daysAgo,
            changes: RecordedChanges(corrections: changes, spokenWords: spokenWords))
    }

    /// The dictation figures over these entries, retained and split the way Home does it.
    static func figures(entries: [HistoryEntry] = [], settings: Settings = .default) -> [MainStatistic] {
        let days = settings.transcriptRetentionDays
        let kept = HistoryPresenter.retained(entries, days: days, now: now)
        let (today, earlier) = HistoryPresenter.todayAndEarlier(in: kept, now: now, calendar: calendar)
        return DictationPresenter.figures(
            today: today, earlier: earlier,
            dropped: HistoryPresenter.dropped(entries, days: days, now: now),
            calendar: calendar, locale: locale)
    }
}

@Suite("The dictation figures")
struct DictationFiguresTests {
    /// No "time saved" tile: words and streak are counts, pace and accuracy need something measured.
    @Test("nothing is reported that has not been measured")
    func noInventedFigures() {
        let figures = HistoryFixture.figures(
            entries: [HistoryFixture.entry("two words", changes: nil)])
        #expect(figures.map(\.caption) == ["Words dictated", "Day dictating"])
        #expect(!figures.contains { $0.caption.localizedCaseInsensitiveContains("saved") })
    }

    @Test("words dictated counts everything kept, and says how much is today's")
    func words() {
        let figures = HistoryFixture.figures(entries: [
            HistoryFixture.entry("one two three"), HistoryFixture.entry("four five"),
            HistoryFixture.entry("six seven eight nine", daysAgo: 3),
        ])
        let figure = figures.first { $0.caption == "Words dictated" }
        #expect(figure?.value == "9")
        #expect(figure?.comment == "5 of them today")
    }

    /// The history keeps a retention window and no more, so this can never be called a lifetime total.
    @Test("the headline figure never claims to be a lifetime total")
    func neverClaimsALifetime() {
        let figures = HistoryFixture.figures(entries: [HistoryFixture.entry("one two")])
        let figure = figures.first { $0.caption == "Words dictated" }
        #expect(figure?.caption.localizedCaseInsensitiveContains("total") == false)
        #expect(figure?.caption.localizedCaseInsensitiveContains("all time") == false)
    }

    @Test("nothing dictated today is said plainly rather than left blank")
    func nothingToday() {
        let figures = HistoryFixture.figures(
            entries: [HistoryFixture.entry("one two", daysAgo: 2)])
        #expect(figures.first { $0.caption == "Words dictated" }?.comment == "none yet today")
    }

    // MARK: The streak

    @Test("counts the days in a row that were dictated in")
    func streak() {
        let figures = HistoryFixture.figures(entries: [
            HistoryFixture.entry("today"), HistoryFixture.entry("yesterday", daysAgo: 1),
            HistoryFixture.entry("the day before", daysAgo: 2),
            // A gap so the run stops here; five days, not seven, since seven is the retention window.
            HistoryFixture.entry("before that", daysAgo: 5),
        ])
        let figure = figures.first { $0.caption == "Day streak" }
        #expect(figure?.value == "3")
        #expect(figure?.comment == "days in a row")
    }

    /// Counted from the most recent day, not today, so a quiet morning does not break the streak.
    @Test("a morning with nothing in it yet does not break the streak")
    func streakSurvivesAQuietMorning() {
        let figures = HistoryFixture.figures(entries: [
            HistoryFixture.entry("yesterday", daysAgo: 1),
            HistoryFixture.entry("the day before", daysAgo: 2),
        ])
        #expect(figures.first { $0.caption == "Day streak" }?.value == "2")
    }

    /// Running out of history is not deletion: a new user's short streak gets the plain caption.
    @Test("a short streak with no evidence of deletion says nothing about it")
    func shortStreakIsNotCalledADeletion() {
        let figures = HistoryFixture.figures(entries: [
            HistoryFixture.entry("today"), HistoryFixture.entry("yesterday", daysAgo: 1),
        ])
        let figure = figures.first { $0.caption == "Day streak" }
        #expect(figure?.value == "2")
        #expect(figure?.comment == "days in a row")
    }

    /// A run reaching past retention's edge proves older days were deleted, not merely never dictated.
    @Test("a streak that runs past the retention window says so")
    func streakAtTheEdgeOfRetention() {
        var settings = Settings.default
        settings.transcriptRetentionDays = 2
        let figures = HistoryFixture.figures(
            entries: [
                HistoryFixture.entry("today"), HistoryFixture.entry("yesterday", daysAgo: 1),
                HistoryFixture.entry("past the window", minutesAgo: 60, daysAgo: 2),
            ], settings: settings)
        let figure = figures.first { $0.caption == "Day streak" }
        #expect(figure?.value == "2")
        #expect(figure?.comment == "at least — anything older has been deleted")
    }

    /// A new install's whole life that happens to fill the window has had nothing deleted.
    @Test("a streak that exactly fills the window with nothing older says nothing about deletion")
    func streakFillingTheWindowIsNotADeletion() {
        var settings = Settings.default
        settings.transcriptRetentionDays = 7
        let figures = HistoryFixture.figures(
            entries: (0..<7).map { HistoryFixture.entry("day \($0)", daysAgo: $0) },
            settings: settings)
        let figure = figures.first { $0.caption == "Day streak" }
        #expect(figure?.value == "7")
        #expect(figure?.comment == "days in a row")
    }

    /// A deleted entry separated from the run by a silent day does not extend it.
    @Test("a deletion beyond a gap does not make the streak 'at least'")
    func deletionBeyondAGapIsNotTheRun() {
        var settings = Settings.default
        settings.transcriptRetentionDays = 2
        let figures = HistoryFixture.figures(
            entries: [
                HistoryFixture.entry("today"), HistoryFixture.entry("yesterday", daysAgo: 1),
                HistoryFixture.entry("long gone", daysAgo: 4),
            ], settings: settings)
        #expect(figures.first { $0.caption == "Day streak" }?.comment == "days in a row")
    }

    /// One day is not a streak, and calling it one makes every other number less believable.
    @Test("a single day is not called a streak")
    func oneDayIsNotAStreak() {
        let figures = HistoryFixture.figures(entries: [HistoryFixture.entry("today")])
        #expect(figures.contains { $0.caption == "Day dictating" })
        #expect(!figures.contains { $0.caption == "Day streak" })
    }

    @Test("pace is pooled across everything that was timed")
    func pace() {
        // Sixty words in sixty seconds across two unequal dictations: pooling gives 60, averaging would not.
        let figures = HistoryFixture.figures(entries: [
            HistoryFixture.timed(String(repeating: "word ", count: 50), seconds: 30),
            HistoryFixture.timed(String(repeating: "word ", count: 10), seconds: 30),
        ])
        #expect(figures.first { $0.caption == "Words per minute" }?.value == "60")
    }

    @Test("nothing timed means no pace at all")
    func paceWithoutTimings() {
        let figures = HistoryFixture.figures(entries: [HistoryFixture.entry()])
        #expect(!figures.contains { $0.caption == "Words per minute" })
        #expect(DictationPresenter.pace(of: []) == nil)
    }

    @Test("today's pace is set beside the usual one")
    func usualPace() {
        let figures = HistoryFixture.figures(entries: [
            HistoryFixture.timed(String(repeating: "word ", count: 10), seconds: 10),
            HistoryFixture.timed(String(repeating: "word ", count: 10), seconds: 20, daysAgo: 1),
        ])
        #expect(
            figures.first { $0.caption == "Words per minute" }?.comment
                == "your usual pace is 30")
    }

    /// A comparison against nothing is not a comparison, so it is left off rather than filled in.
    @Test("a first day has nothing to compare against and says nothing")
    func noComparisonOnTheFirstDay() {
        let figures = HistoryFixture.figures(entries: [
            HistoryFixture.timed("one two three", seconds: 6)
        ])
        #expect(figures.first { $0.caption == "Words per minute" }?.comment == nil)
    }

    /// Five words said, one written over three of them correctly: two survive untouched, so 40%.
    @Test("a change that writes one word over three does not make the dictation 0% accurate")
    func accuracy() {
        let figures = HistoryFixture.figures(entries: [
            HistoryFixture.measured(
                "the SQL query", spokenWords: 5,
                changes: [HistoryFixture.change("s q l", "SQL", over: 1..<4)])
        ])

        let figure = figures.first { $0.caption == DictationPresenter.accuracyTitle }
        #expect(figure?.value == "40.0%")
        #expect(figure?.meters.map(\.label) == ["Today"])
        #expect(figure?.comment == DictationPresenter.accuracyCaption)
    }

    /// Two changes whose ranges sum past the text length must still count the word between them.
    @Test("two such changes leave the word between them counted")
    func accuracyWithSeveralChanges() {
        let figures = HistoryFixture.figures(entries: [
            HistoryFixture.measured(
                "SQL and JSON", spokenWords: 6,
                changes: [
                    HistoryFixture.change("s q l", "SQL", over: 0..<3),
                    HistoryFixture.change("j son", "JSON", over: 4..<6),
                ])
        ])
        // One of the six words said — "and" — survives untouched.
        #expect(figures.first { $0.caption == DictationPresenter.accuracyTitle }?.value == "16.7%")
    }

    /// Snippets are not counted: the trigger words were heard correctly, so they cannot inflate the figure.
    @Test("a snippet expanding two words into nine does not inflate the figure")
    func accuracyIgnoresSnippets() {
        let entry = HistoryFixture.entry(
            // The snippet writes nine words over the first two, and "SQL" replaces the last three.
            "Flat 2, 14 Rowan Street, Hackney, London E8 3PQ then SQL",
            changes: RecordedChanges(
                corrections: [HistoryFixture.change("s q l", "SQL", over: 3..<6)],
                snippets: [
                    RecordedSnippet(
                        snippetID: UUID(), matched: "my address",
                        expansion: "Flat 2, 14 Rowan Street, Hackney, London E8 3PQ")
                ],
                spokenWords: 6))

        // Three of the six words said came out as said; dividing by the eleven written would give 72.7%.
        #expect(
            HistoryFixture.figures(entries: [entry])
                .first { $0.caption == DictationPresenter.accuracyTitle }?.value == "50.0%")
    }

    /// The figure is near enough 100% for everybody, so yesterday's copy of it compared nothing.
    @Test("draws today alone, with no baseline to compare against")
    func drawsNoBaseline() {
        let figures = HistoryFixture.figures(entries: [
            HistoryFixture.measured(
                "one two three four", spokenWords: 4,
                changes: [HistoryFixture.change("one", "One", over: 0..<1)]),
            HistoryFixture.measured(
                "Five six seven eight", spokenWords: 4,
                changes: [HistoryFixture.change("five six", "Five six", over: 0..<2)],
                daysAgo: 1),
        ])

        let figure = figures.first { $0.caption == DictationPresenter.accuracyTitle }
        #expect(figure?.meters.map(\.label) == ["Today"])
        #expect(figure?.meters.contains { $0.isBaseline } == false)
        #expect(figure?.comment == DictationPresenter.accuracyCaption)
    }

    /// The name is the fix: the number says what the clean-up left, not what the recogniser heard.
    @Test("names the figure for what it measures")
    func namesWhatItMeasures() {
        #expect(DictationPresenter.accuracyTitle == "Left as dictated")
        #expect(DictationPresenter.accuracyCaption.contains("does not say"))
        #expect(!DictationPresenter.accuracyTitle.contains("Accuracy"))
    }

    /// An accuracy of 100% computed from no evidence is a number, not a measurement.
    @Test("no record of changes means no accuracy figure")
    func accuracyNeedsARecord() {
        let figures = HistoryFixture.figures(
            entries: [HistoryFixture.entry("one two", changes: nil)])
        #expect(!figures.contains { $0.caption == DictationPresenter.accuracyTitle })
    }

    /// Changes kept without the utterance counted have no denominator, so they leave the sample.
    @Test("changes recorded without the utterance being counted give no accuracy figure")
    func accuracyNeedsTheUtterance() {
        let figures = HistoryFixture.figures(entries: [
            HistoryFixture.entry("one two", changes: RecordedChanges())
        ])
        #expect(!figures.contains { $0.caption == DictationPresenter.accuracyTitle })
    }

    /// An unmeasured dictation leaves the sample instead of hiding the figure for the measured ones.
    @Test("one unmeasured dictation does not hide the figure for the measured ones")
    func accuracyIgnoresTheUnmeasured() {
        let figures = HistoryFixture.figures(entries: [
            HistoryFixture.measured(
                "one two three four", spokenWords: 4,
                changes: [HistoryFixture.change("one", "One", over: 0..<1)]),
            HistoryFixture.entry("salvaged", changes: nil),
        ])
        // Three of the measured dictation's four spoken words survive; the salvaged one is in neither half.
        #expect(figures.first { $0.caption == DictationPresenter.accuracyTitle }?.value == "75.0%")
    }

    /// A record whose stored count is damaged is left out of the figure rather than trapping or counting as silence.
    @Test("a damaged word count leaves its dictation out of the accuracy figure")
    func accuracySkipsADamagedCount() throws {
        let damaged = try JSONDecoder().decode(
            RecordedChanges.self,
            from: Data(#"{"corrections":[],"snippets":[],"spokenWords":-1}"#.utf8))
        let figures = HistoryFixture.figures(entries: [
            HistoryFixture.measured(
                "one two three four", spokenWords: 4,
                changes: [HistoryFixture.change("one", "One", over: 0..<1)]),
            HistoryFixture.entry("damaged", changes: damaged),
        ])
        #expect(figures.first { $0.caption == DictationPresenter.accuracyTitle }?.value == "75.0%")
    }

    @Test("nothing said means no accuracy either")
    func accuracyNeedsWords() {
        #expect(DictationPresenter.accuracy(of: []) == nil)
        #expect(DictationPresenter.accuracy(of: [HistoryFixture.measured("", spokenWords: 0)]) == nil)
    }

    /// Changed words are counted as positions inside the utterance, so a wide range cannot take more.
    @Test("a stored change wider than the utterance cannot take more words than were said")
    func accuracyCannotGoBelowNothing() {
        let figures = HistoryFixture.figures(entries: [
            HistoryFixture.measured(
                "One", spokenWords: 1,
                changes: [HistoryFixture.change("one two three", "One", over: 0..<3)])
        ])
        #expect(figures.first { $0.caption == DictationPresenter.accuracyTitle }?.value == "0.0%")
    }
}
