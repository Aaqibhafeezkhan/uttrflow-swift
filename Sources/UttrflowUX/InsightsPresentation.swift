// The Insights page: a calendar of how much was said each day, a range switch, and four figures.
public import Foundation
public import UttrflowHistory
public import UttrflowSettings

/// How far back the calendar reaches.
public enum InsightsRange: String, Sendable, CaseIterable, Identifiable {
    case week = "7"
    case month = "30"
    case quarter = "90"

    /// The identifier the page reports back when this range is picked.
    public var id: String { rawValue }

    /// The days the range covers, today included.
    public var days: Int {
        switch self {
        case .week: 7
        case .month: 30
        case .quarter: 90
        }
    }

    /// "30 days".
    public var title: String { "\(days) days" }
}

/// One segment of the range switch.
public struct InsightsRangeOption: Sendable, Equatable, Identifiable {
    /// The range this segment picks.
    public let range: InsightsRange
    /// Whether this is the range the calendar shows.
    public let isSelected: Bool
    /// Why the range cannot be picked; absent when it can.
    public let unavailableReason: String?

    /// The range's identifier.
    public var id: String { range.id }
    /// "30 days".
    public var title: String { range.title }
    /// Whether the range reaches no further back than history is kept.
    public var isAvailable: Bool { unavailableReason == nil }

    /// Builds a segment.
    public init(range: InsightsRange, isSelected: Bool, unavailableReason: String? = nil) {
        self.range = range
        self.isSelected = isSelected
        self.unavailableReason = unavailableReason
    }
}

/// One day's tile on the calendar.
public struct InsightsCalendarDay: Sendable, Equatable, Identifiable {
    /// The start of the day.
    public let date: Date
    /// The day of the month drawn on the tile: "26".
    public let number: String
    /// Words dictated that day.
    public let words: Int
    /// Of the busiest day in the range, 0…1, so the view scales nothing itself.
    public let fraction: Double
    /// Whether this tile is today's.
    public let isToday: Bool
    /// "1,284 words · 26 Sept", shown on hover and read aloud.
    public let detail: String

    /// The day, which is unique within the range.
    public var id: Date { date }
    /// A day with nothing said, drawn as a bare tile.
    public var isSilent: Bool { words == 0 }
    /// The teal's opacity, from a floor to full, stepping over the band where no number ink reaches 4.5:1.
    public var shade: Double {
        if isSilent { return 0 }
        let smooth = 0.15 + 0.85 * fraction
        guard smooth > Self.inkCeiling, smooth < Self.deepInkFloor else { return smooth }
        return smooth < (Self.inkCeiling + Self.deepInkFloor) / 2 ? Self.inkCeiling : Self.deepInkFloor
    }
    /// Whether the number is drawn in the deep ink, which is on every tile at or past ``deepInkFloor``.
    public var usesDeepInk: Bool { shade >= Self.deepInkFloor }

    /// The deepest shade the page's ink still clears 4.5:1 on in dark. See `Docs/redesign-tokens.md`.
    public static let inkCeiling = 0.5
    /// The palest shade the deep ink clears 4.5:1 on in dark.
    public static let deepInkFloor = 0.72

    /// Builds a tile; the fraction is clamped to 0…1.
    public init(
        date: Date, number: String, words: Int, fraction: Double, isToday: Bool, detail: String
    ) {
        self.date = date
        self.number = number
        self.words = words
        self.fraction = min(max(fraction, 0), 1)
        self.isToday = isToday
        self.detail = detail
    }
}

/// The range laid out as weeks, first weekday on the left.
public struct InsightsCalendar: Sendable, Equatable {
    /// The shades the legend steps through, from less to more.
    public static let legend: [Double] = [0.15, 0.4, 0.72, 0.9]

    /// The months the range spans: "August – September".
    public let title: String
    /// The weekday initials across the top, starting on the calendar's first weekday.
    public let weekdays: [String]
    /// The empty cells before the first day, so each day falls under its weekday.
    public let leadingBlanks: Int
    /// One tile per day of the range, oldest first.
    public let days: [InsightsCalendarDay]

    /// The rows the grid needs.
    public var weeks: Int { (leadingBlanks + days.count + 6) / 7 }

    /// Builds a calendar; the blanks are clamped to 0…6.
    public init(title: String, weekdays: [String], leadingBlanks: Int, days: [InsightsCalendarDay]) {
        self.title = title
        self.weekdays = weekdays
        self.leadingBlanks = min(max(leadingBlanks, 0), 6)
        self.days = days
    }
}

/// Everything the insights page is drawn from.
public struct InsightsSnapshot: Sendable, Equatable {
    /// Newest first, before retention is applied.
    public let entries: [HistoryEntry]
    /// The user's settings, for the retention window.
    public let settings: Settings
    /// The range last picked, if any; the presenter falls back when it is absent or out of reach.
    public let range: InsightsRange?
    /// The clock the page is drawn against.
    public let now: Date

    /// Builds a snapshot; entries and settings default to empty, the range to the presenter's choice.
    public init(
        entries: [HistoryEntry] = [],
        settings: Settings = .default,
        range: InsightsRange? = nil,
        now: Date
    ) {
        self.entries = entries
        self.settings = settings
        self.range = range
        self.now = now
    }
}

/// What the insights page shows.
public struct InsightsPresentation: Sendable, Equatable {
    /// The title and caption across the top.
    public let chrome: MainPageChrome
    /// The range switch. Empty exactly when ``emptyState`` is set.
    public let ranges: [InsightsRangeOption]
    /// The calendar. Absent exactly when ``emptyState`` is set.
    public let calendar: InsightsCalendar?
    /// Words, dictations, words per minute and the streak, in that order.
    public let figures: [MainStatistic]
    /// Shown until there is a week to show.
    public let emptyState: MainEmptyState?

    /// Builds the page from its parts.
    public init(
        chrome: MainPageChrome,
        ranges: [InsightsRangeOption],
        calendar: InsightsCalendar?,
        figures: [MainStatistic],
        emptyState: MainEmptyState?
    ) {
        self.chrome = chrome
        self.ranges = ranges
        self.calendar = calendar
        self.figures = figures
        self.emptyState = emptyState
    }
}

/// Turns the kept dictations into a calendar and the figures that can honestly be given.
public enum InsightsPresenter {
    /// A week, because a baseline drawn from three days is noise wearing a number's clothes.
    public static let daysBeforeCharting = 7

    /// Draws the Insights page from a snapshot.
    public static func page(
        for snapshot: InsightsSnapshot,
        calendar: Calendar = .autoupdatingCurrent,
        locale: Locale = .autoupdatingCurrent
    ) -> InsightsPresentation {
        let retention = snapshot.settings.transcriptRetentionDays
        let kept = HistoryPresenter.retained(snapshot.entries, days: retention, now: snapshot.now)
        let spoken = daysSpokenOn(kept, calendar: calendar)
        let chrome = MainPageChrome(
            title: "Insights",
            caption: "Where the words went, and how fast they arrived. Measured on this Mac.")

        guard spoken.count >= daysBeforeCharting else {
            return InsightsPresentation(
                chrome: chrome, ranges: [], calendar: nil, figures: [],
                emptyState: emptyState(
                    for: kept, daysSpokenOn: spoken.count, now: snapshot.now, calendar: calendar,
                    locale: locale))
        }

        let range = chosen(snapshot.range, retention: retention)
        let inRange = within(range, kept, now: snapshot.now, calendar: calendar)
        return InsightsPresentation(
            chrome: chrome,
            ranges: options(selected: range, retention: retention),
            calendar: self.calendar(
                for: inRange, range: range, now: snapshot.now, calendar: calendar, locale: locale),
            figures: figures(inRange: inRange, range: range, calendar: calendar, locale: locale),
            emptyState: nil)
    }

    // MARK: - The range

    /// Whether history is kept long enough for the range to show anything; a week is always offered.
    static func reaches(_ range: InsightsRange, retention: Int) -> Bool {
        range.days <= max(retention, InsightsRange.week.days)
    }

    /// The range asked for when it is in reach, else the longest in reach up to a month.
    static func chosen(_ asked: InsightsRange?, retention: Int) -> InsightsRange {
        if let asked, reaches(asked, retention: retention) { return asked }
        return reaches(.month, retention: retention) ? .month : .week
    }

    /// The three segments, a range beyond what is kept saying why it cannot be picked.
    static func options(selected: InsightsRange, retention: Int) -> [InsightsRangeOption] {
        InsightsRange.allCases.map { range in
            InsightsRangeOption(
                range: range, isSelected: range == selected,
                unavailableReason: reaches(range, retention: retention)
                    ? nil
                    : """
                    History is kept for \(MainFormatting.count(retention, "day", "days")). \
                    Keep it longer in Settings to see \(range.title).
                    """)
        }
    }

    /// The first day of the range, today being its last.
    static func firstDay(of range: InsightsRange, now: Date, calendar: Calendar) -> Date {
        let today = calendar.startOfDay(for: now)
        return calendar.date(byAdding: .day, value: -(range.days - 1), to: today) ?? today
    }

    /// The dictations said on a day of the range.
    static func within(
        _ range: InsightsRange, _ entries: [HistoryEntry], now: Date, calendar: Calendar
    ) -> [HistoryEntry] {
        let first = firstDay(of: range, now: now, calendar: calendar)
        return entries.filter { $0.when >= first }
    }

    // MARK: - The calendar

    /// The distinct days the user said something on; fifty dictations in one afternoon is one afternoon.
    static func daysSpokenOn(_ entries: [HistoryEntry], calendar: Calendar) -> Set<Date> {
        Set(entries.map { calendar.startOfDay(for: $0.when) })
    }

    /// Words said on each day, keyed by the start of the day.
    static func wordsByDay(_ entries: [HistoryEntry], calendar: Calendar) -> [Date: Int] {
        var totals: [Date: Int] = [:]
        for entry in entries {
            totals[calendar.startOfDay(for: entry.when), default: 0] += MainFormatting.words(in: entry.text)
        }
        return totals
    }

    /// One tile per day of the range, oldest first, after the blanks that line the first up with its weekday.
    static func calendar(
        for entries: [HistoryEntry], range: InsightsRange, now: Date, calendar: Calendar,
        locale: Locale
    ) -> InsightsCalendar {
        let today = calendar.startOfDay(for: now)
        let first = firstDay(of: range, now: now, calendar: calendar)
        let totals = wordsByDay(entries, calendar: calendar)
        // A floor of one keeps the division safe for a range with nothing said in it.
        let peak = totals.values.reduce(1, max)
        let style = Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone)

        let days = (0..<range.days).compactMap { calendar.date(byAdding: .day, value: $0, to: first) }
            .map { day in
                let words = totals[day] ?? 0
                let date = day.formatted(style.day().month(.abbreviated))
                return InsightsCalendarDay(
                    date: day,
                    number: day.formatted(style.day()),
                    words: words,
                    fraction: Double(words) / Double(peak),
                    isToday: day == today,
                    detail: words == 0
                        ? "No dictation · \(date)"
                        : "\(words.formatted(.number.locale(locale))) \(words == 1 ? "word" : "words") · \(date)"
                )
            }

        return InsightsCalendar(
            title: months(from: first, to: today, style: style),
            weekdays: weekdays(calendar: calendar),
            leadingBlanks: blanks(before: first, calendar: calendar),
            days: days)
    }

    /// "September", or "August – September" when the range crosses into another month.
    static func months(from first: Date, to last: Date, style: Date.FormatStyle) -> String {
        let from = first.formatted(style.month(.wide))
        let to = last.formatted(style.month(.wide))
        return from == to ? to : "\(from) – \(to)"
    }

    /// The weekday initials, turned so the calendar's first weekday leads.
    static func weekdays(calendar: Calendar) -> [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let start = (calendar.firstWeekday - 1) % symbols.count
        return Array(symbols[start...] + symbols[..<start])
    }

    /// How many cells come before the first day in its week.
    static func blanks(before first: Date, calendar: Calendar) -> Int {
        (calendar.component(.weekday, from: first) - calendar.firstWeekday + 7) % 7
    }

    // MARK: - Figures

    /// Words in the range, their daily average, the pace across it, and the range's longest streak.
    static func figures(
        inRange: [HistoryEntry], range: InsightsRange, calendar: Calendar, locale: Locale
    ) -> [MainStatistic] {
        let streak = longestStreak(in: inRange, calendar: calendar)
        return [
            MainStatistic(value: inRange.totalWords.formatted(.number.locale(locale)), caption: "words"),
            MainStatistic(
                value: dailyAverage(of: inRange, over: range).formatted(.number.locale(locale)),
                caption: "a day"),
            MainStatistic(
                value: DictationPresenter.pace(of: inRange).map { "\($0)" } ?? "—",
                caption: "words / min"),
            MainStatistic(value: MainFormatting.count(streak, "day", "days"), caption: "longest streak"),
        ]
    }

    /// Words in the range over every day it covers, silent days included, to the nearest word.
    static func dailyAverage(of inRange: [HistoryEntry], over range: InsightsRange) -> Int {
        Int((Double(inRange.totalWords) / Double(range.days)).rounded())
    }

    /// The most days in a row with a dictation, anywhere in the entries given.
    static func longestStreak(in entries: [HistoryEntry], calendar: Calendar) -> Int {
        let days = daysSpokenOn(entries, calendar: calendar).sorted()
        var longest = 0
        var run = 0
        var previous: Date?
        for day in days {
            let follows = previous.flatMap { calendar.date(byAdding: .day, value: 1, to: $0) } == day
            run = follows ? run + 1 : 1
            longest = max(longest, run)
            previous = day
        }
        return longest
    }

    // MARK: - Not yet

    /// Waiting is not empty: says how long is left and gives the two figures already true.
    static func emptyState(
        for entries: [HistoryEntry], daysSpokenOn spoken: Int, now: Date, calendar: Calendar,
        locale: Locale
    ) -> MainEmptyState {
        MainEmptyState(
            symbolName: "chart.bar",
            title: "Not enough to chart yet",
            message: """
                Dictate on \(daysBeforeCharting) different days and your charts appear. \
                \(spoken) of \(daysBeforeCharting) days so far.
                """,
            chips: entries.isEmpty
                ? []
                : [
                    MainStatistic(
                        value: entries.count.formatted(.number.locale(locale)),
                        caption: "dictations so far"),
                    MainStatistic(
                        value: entries.totalWords.formatted(.number.locale(locale)),
                        caption: "words so far"),
                ],
            progress: MainProgress(
                fraction: Double(spoken) / Double(daysBeforeCharting),
                leading: "\(spoken) of \(daysBeforeCharting) days",
                trailing: remaining(spoken: spoken, now: now, calendar: calendar, locale: locale),
                steps: daysBeforeCharting))
    }

    /// "Charts appear on Tuesday", or "next Tuesday" a week ahead, assuming each day left is spoken on.
    static func remaining(spoken: Int, now: Date, calendar: Calendar, locale: Locale) -> String {
        let left = max(daysBeforeCharting - spoken, 1)
        let day = now.addingTimeInterval(Double(left) * 86_400)
        let weekday = day.formatted(.dateTime.weekday(.wide).locale(locale))
        return left % 7 == 0 ? "Charts appear next \(weekday)" : "Charts appear on \(weekday)"
    }
}
