// Tests for home's hero, mood, stat tiles and recent-activity rail.
import Foundation
import UttrflowCore
import UttrflowHistory
import Testing

@testable import UttrflowUX

@Suite("The part of the day")
struct HomeMoodTests {
    @Test(
        "each hour falls in the designed mood",
        arguments: [
            (5, HomeMood.earlyMorning), (7, .earlyMorning), (8, .morning), (11, .morning),
            (12, .afternoon), (16, .afternoon), (17, .evening), (19, .evening), (20, .night),
            (22, .night), (23, .lateNight), (0, .lateNight), (4, .lateNight),
        ])
    func hours(hour: Int, mood: HomeMood) {
        #expect(HomeMood.at(hour: hour) == mood)
    }

    @Test(
        "the greeting follows the mood",
        arguments: [
            (HomeMood.earlyMorning, "Good morning"), (.morning, "Good morning"),
            (.afternoon, "Good afternoon"), (.evening, "Good evening"), (.night, "Good evening"),
            (.lateNight, "Working late"),
        ])
    func salutation(mood: HomeMood, expected: String) {
        #expect(mood.salutation == expected)
    }

    @Test("every mood names its own picture")
    func pictures() {
        let names = HomeMood.allCases.map(\.imageName)
        #expect(Set(names).count == HomeMood.allCases.count)
        #expect(names.allSatisfy { $0.hasPrefix("panda-") })
        #expect(HomeMood.lateNight.imageName == "panda-late-night")
        #expect(HomeMood.earlyMorning.imageName == "panda-early-morning")
    }

    @Test("the page carries the mood of the hour it is drawn at")
    func pageMood() {
        #expect(HistoryFixture.home(at: HistoryFixture.atHour(9)).mood == .morning)
        #expect(HistoryFixture.home(at: HistoryFixture.atHour(23)).mood == .lateNight)
    }

    @Test("late at night the greeting says so, with the name")
    func workingLate() {
        let page = HistoryFixture.home(systemName: "Alex Example", at: HistoryFixture.atHour(1))
        #expect(page.greeting == "Working late, Alex")
    }

    @Test("the date over the greeting names the weekday, day and month")
    func dateLine() {
        let line = HistoryFixture.home().dateLine
        #expect(line.contains("Sunday"))
        #expect(line.contains("15"))
        #expect(line.contains("June"))
    }
}

@Suite("The hero card")
struct HomeHeroTests {
    @Test("names the three features in order and offers to start")
    func hero() {
        let hero = HistoryFixture.home().hero
        #expect(hero.lead == "Your voice,")
        #expect(hero.emphasis == "finished for you.")
        #expect(hero.features.map(\.title) == ["Dictation", "AI suggestions", "Clipboard"])
        #expect(hero.features.map(\.id) == ["dictation", "suggestions", "clipboard"])
        #expect(hero.start.intent == .dictate)
        #expect(hero.start.title == "Start speaking")
        #expect(hero.canStart)
    }

    @Test("a missing permission stops the hero offering to start")
    func blocked() {
        let page = HistoryFixture.home(permissions: [.microphone: .denied, .accessibility: .granted])
        #expect(!page.hero.canStart)
    }

    @Test("a speech model that is not ready stops it too")
    func loading() {
        let page = HomePresenter.page(
            for: HomeSnapshot(
                permissions: [.microphone: .granted, .accessibility: .granted], shortcut: "⌥Space",
                now: HistoryFixture.now, speechModel: .loading(elapsed: .seconds(1))),
            calendar: HistoryFixture.calendar, locale: HistoryFixture.locale)
        #expect(!page.hero.canStart)
    }
}

@Suite("The stat tiles")
struct HomeStatTileTests {
    private func tile(_ kind: HomeStatKind, in entries: [HistoryEntry]) -> HomeStatTile? {
        HistoryFixture.home(entries: entries).tiles.first { $0.kind == kind }
    }

    @Test("four tiles in the designed order")
    func order() {
        let tiles = HistoryFixture.home(entries: [HistoryFixture.entry()]).tiles
        #expect(tiles.map(\.kind) == [.wordsToday, .streak, .pace, .leftAsDictated])
        #expect(tiles.map(\.label) == ["words today", "streak", "words / min", "left as dictated"])
        #expect(tiles.map(\.id) == tiles.map(\.kind))
    }

    @Test("words today counts today only, and fills its ring against the daily goal")
    func wordsToday() throws {
        let entries = [
            HistoryFixture.entry("one two three four five"),
            HistoryFixture.entry("six seven", minutesAgo: 30),
            HistoryFixture.entry("not today at all", daysAgo: 1),
        ]
        let words = try #require(tile(.wordsToday, in: entries))
        #expect(words.value == "7")
        #expect(words.progress == 7.0 / Double(HomeDashboard.dailyWordGoal))
        #expect(words.accessibilityLabel == "7 words today")
    }

    @Test("a ring past its goal stays full")
    func clamped() {
        #expect(
            HomeStatTile(kind: .pace, value: "300", label: "", progress: 2, accessibilityLabel: "")
                .progress == 1)
        #expect(
            HomeStatTile(kind: .pace, value: "0", label: "", progress: -1, accessibilityLabel: "")
                .progress == 0)
    }

    @Test("the streak counts days in a row ending today")
    func streakToday() throws {
        let entries =
            (0..<3).map { HistoryFixture.entry(daysAgo: $0) } + [
                HistoryFixture.entry(daysAgo: 5)
            ]
        let streak = try #require(tile(.streak, in: entries))
        #expect(streak.value == "3 days")
        #expect(streak.progress == 3.0 / Double(HomeDashboard.streakGoal))
    }

    /// A day that is not over yet has not broken the run.
    @Test("a streak that ended yesterday still stands")
    func streakYesterday() {
        let entries = [HistoryFixture.entry(daysAgo: 1), HistoryFixture.entry(daysAgo: 2)]
        #expect(
            HomeDashboard.streak(in: entries, now: HistoryFixture.now, calendar: HistoryFixture.calendar)
                == 2)
    }

    @Test("a gap of a whole day ends the streak")
    func streakBroken() throws {
        let entries = [HistoryFixture.entry(daysAgo: 2), HistoryFixture.entry(daysAgo: 3)]
        #expect(try #require(tile(.streak, in: entries)).value == "0 days")
        #expect(
            try #require(tile(.streak, in: [HistoryFixture.entry()])).value == "1 day")
    }

    @Test("pace pools every timed dictation kept")
    func pace() throws {
        let entries = [
            HistoryFixture.timed("one two three four five six", seconds: 3),
            HistoryFixture.timed("one two three four five six", seconds: 3, daysAgo: 1),
        ]
        let pace = try #require(tile(.pace, in: entries))
        #expect(pace.value == "120")
        #expect(pace.progress == 120.0 / Double(HomeDashboard.paceGoal))
    }

    @Test("nothing timed shows a dash and says so")
    func paceUnmeasured() throws {
        let pace = try #require(tile(.pace, in: [HistoryFixture.entry()]))
        #expect(pace.value == "—")
        #expect(pace.progress == 0)
        #expect(pace.accessibilityLabel == "words / min, not measured yet")
    }

    @Test("left as dictated is the share of spoken words the clean-up kept, rounded down")
    func leftAsDictated() throws {
        let entries = [
            HistoryFixture.measured(
                "a", spokenWords: 200, changes: [HistoryFixture.change("x", "y", over: 0..<1)])
        ]
        let share = try #require(tile(.leftAsDictated, in: entries))
        #expect(share.value == "99%")
        #expect(share.progress == 199.0 / 200.0)
    }

    @Test("left as dictated is a dash when nothing was measured")
    func leftAsDictatedUnmeasured() throws {
        let share = try #require(tile(.leftAsDictated, in: [HistoryFixture.entry(changes: nil)]))
        #expect(share.value == "—")
    }

    @Test("a missing permission removes the tiles")
    func blocked() {
        let page = HistoryFixture.home(
            permissions: [.microphone: .denied, .accessibility: .granted],
            entries: [HistoryFixture.entry()])
        #expect(page.tiles.isEmpty)
        #expect(page.activity.isEmpty)
    }
}

@Suite("The recent-activity rail")
struct HomeActivityTests {
    @Test("shows the newest three, with the way to History")
    func newestThree() {
        let entries = (0..<5).map { HistoryFixture.entry("dictation \($0)", minutesAgo: $0) }
        let page = HistoryFixture.home(entries: entries)
        #expect(page.activity.map(\.text) == ["dictation 0", "dictation 1", "dictation 2"])
        #expect(page.viewAll?.intent == .show(.history))
        #expect(page.viewAll?.title == "View all")
    }

    @Test("an empty history offers no way to it")
    func empty() {
        let page = HistoryFixture.home()
        #expect(page.activity.isEmpty)
        #expect(page.viewAll == nil)
    }

    @Test("a row carries the time, the app, the words and its actions")
    func row() throws {
        let entry = HistoryFixture.entry("move the review to Thursday", application: "Notes")
        let row = HomeDashboard.activity(
            for: entry, calendar: HistoryFixture.calendar, locale: HistoryFixture.locale)
        #expect(row.id == entry.id)
        #expect(row.time == "15:20")
        #expect(row.words == "5 words")
        #expect(row.details == ["Notes", "5 words", "As dictated"])
        #expect(row.view.intent == .show(.history))
        #expect(row.more.map(\.title) == ["Copy", "Flag", "Delete"])
        #expect(row.more.first?.intent == .copy(entry.text))
        #expect(row.more.last?.intent == .forgetDictation(entry.id))
        #expect(row.more.last?.isDestructive == true)
    }

    /// The rail's gutter is sized for five characters, so the stamp is on the 24-hour clock everywhere.
    @Test("the time is on the 24-hour clock with two-digit hours, whatever the region")
    func twentyFourHour() {
        let morning = HistoryFixture.atHour(9)
        let us = Locale(identifier: "en_US")
        #expect(HomeDashboard.time(morning, calendar: HistoryFixture.calendar, locale: us) == "09:30")
        #expect(
            HomeDashboard.time(HistoryFixture.atHour(21), calendar: HistoryFixture.calendar, locale: us)
                == "21:30")
    }

    @Test("the top bar's search opens History's search")
    func search() {
        let search = HistoryFixture.home().search
        #expect(search.intent == .search)
        #expect(search.title == "Search your words…")
    }

    @Test("a flagged row offers to unflag")
    func flagged() {
        let entry = HistoryFixture.entry(isFlagged: true)
        let row = HomeDashboard.activity(
            for: entry, calendar: HistoryFixture.calendar, locale: HistoryFixture.locale)
        #expect(row.more[1].title == "Unflag")
        #expect(row.more[1].intent == .flagDictation(entry.id))
    }

    @Test("an unknown app is left out of the details rather than named")
    func noApplication() {
        let row = HomeDashboard.activity(
            for: HistoryFixture.entry("one", application: nil, changes: nil),
            calendar: HistoryFixture.calendar, locale: HistoryFixture.locale)
        #expect(row.details == ["1 word"])
        #expect(row.tone == .unmeasured)
    }

    @Test("the tag says what the clean-up did, and says nothing when it was not measured")
    func outcome() {
        #expect(HomeDashboard.outcome(of: nil) == (nil, .unmeasured))
        #expect(HomeDashboard.outcome(of: RecordedChanges()) == ("As dictated", .asDictated))
        let one = RecordedChanges(corrections: [HistoryFixture.change("a", "b", over: 0..<1)])
        #expect(HomeDashboard.outcome(of: one) == ("1 change", .changed))
        let snippet = RecordedSnippet(snippetID: UUID(), matched: "addr", expansion: "a longer phrase")
        let two = RecordedChanges(
            corrections: [HistoryFixture.change("a", "b", over: 0..<1)], snippets: [snippet])
        #expect(HomeDashboard.outcome(of: two) == ("2 changes", .changed))
    }

    /// A change the user put back is no longer a change Uttrflow made.
    @Test("an undone change does not count")
    func undone() {
        let undone = RecordedCorrection(
            heard: "a", wrote: "b", wordRange: 0..<1, entryID: UUID(),
            reason: .heardAsStrayLetters, heardConfidence: 0.3, isUndone: true)
        #expect(
            HomeDashboard.outcome(of: RecordedChanges(corrections: [undone]))
                == ("As dictated", .asDictated))
    }
}
