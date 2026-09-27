// The dictation figures: words, streak, pace and the share left as dictated.
import Foundation
import UttrflowHistory

/// The dictation figures Home and Insights draw: words, streak, pace and what was left as dictated.
public enum DictationPresenter {
    /// How many earlier days the pace and accuracy comparisons need before "your usual" is said.
    static let comparisonFloor = 1

    /// The figure's name, shared with Insights, saying what is measured rather than what a user hopes it means.
    static let accuracyTitle = "Left as dictated"

    /// What the figure measures, shared with Insights; the denominator is the words said.
    static let accuracyCaption = """
        The share of your words the clean-up left exactly as you said them. It does not say \
        whether they were heard correctly.
        """

    // MARK: - The rail

    /// Only figures with something real behind them; no "time saved" tile, since nothing measures typing.
    static func figures(
        today: [HistoryEntry], earlier: [HistoryEntry], dropped: [HistoryEntry], calendar: Calendar,
        locale: Locale
    ) -> [MainStatistic] {
        var figures: [MainStatistic] = []
        let kept = today + earlier

        // Words within the retention window, never a lifetime total: older words are gone.
        let all = kept.totalWords
        let todayWords = today.totalWords
        if all > 0 {
            figures.append(
                MainStatistic(
                    value: MainFormatting.compact(all, locale: locale),
                    caption: "Words dictated",
                    comment: todayWords > 0
                        ? "\(todayWords.formatted(.number.locale(locale))) of them today"
                        : "none yet today"))
        }

        if let run = streak(in: kept, dropped: dropped, calendar: calendar) {
            figures.append(
                MainStatistic(
                    value: "\(run.days)",
                    caption: run.days == 1 ? "Day dictating" : "Day streak",
                    // Only a dropped entry touching the run is evidence of a deletion; a full window is not.
                    comment: run.reachesTheEdge
                        ? "at least — anything older has been deleted"
                        : "days in a row"))
        }

        if let pace = pace(of: today) {
            let usual = earlier.count >= comparisonFloor ? self.pace(of: earlier) : nil
            figures.append(
                MainStatistic(
                    value: "\(pace)",
                    caption: "Words per minute",
                    comment: usual.map { "your usual pace is \($0)" }))
        }

        if let accuracy = accuracy(of: today) {
            figures.append(
                MainStatistic(
                    value: MainFormatting.percentage(accuracy, locale: locale),
                    caption: Self.accuracyTitle,
                    comment: Self.accuracyCaption,
                    meters: [MainMeter(label: "Today", fraction: accuracy)]))
        }

        return figures
    }

    /// Words per minute pooled across every timed dictation; `nil` when nothing was timed.
    static func pace(of entries: [HistoryEntry]) -> Int? {
        // Reduced to words and seconds as found, so untimed entries never reach the sum.
        let timed = entries.compactMap { entry -> (words: Int, seconds: Double)? in
            guard let spoken = entry.spokenFor else { return nil }
            return (MainFormatting.words(in: entry.text), spoken.inSeconds)
        }
        let seconds = timed.reduce(0.0) { $0 + $1.seconds }
        guard seconds > 0 else { return nil }
        let words = timed.reduce(0) { $0 + $1.words }
        return Int((Double(words) / seconds * 60).rounded())
    }

    /// The share of spoken words that came out as said, measured dictations only. See Docs/ux-figures.md.
    static func accuracy(of entries: [HistoryEntry]) -> Double? {
        var spoken = 0
        var changed = 0
        for changes in entries.compactMap(\.changes) {
            guard let said = changes.spokenWords else { continue }
            spoken += said
            changed += changes.correctedWords
        }
        guard spoken > 0 else { return nil }
        return Double(spoken - changed) / Double(spoken)
    }

    /// Days in a row back from the most recent day, not today; `nil` when nothing is kept.
    static func streak(
        in entries: [HistoryEntry], dropped: [HistoryEntry], calendar: Calendar
    ) -> (days: Int, reachesTheEdge: Bool)? {
        let days = Set(entries.map { calendar.startOfDay(for: $0.when) }).sorted(by: >)
        guard let newest = days.first else { return nil }

        var run = 1
        var expected = newest
        for day in days.dropFirst() {
            guard let previous = calendar.date(byAdding: .day, value: -1, to: expected),
                calendar.isDate(day, inSameDayAs: previous)
            else { break }
            run += 1
            expected = day
        }
        guard run == days.count, run > 1, let oldest = days.last,
            let before = calendar.date(byAdding: .day, value: -1, to: oldest)
        else { return (run, false) }
        // A deleted entry on the run's oldest day or the day before it proves the run went further back.
        let cut = dropped.contains {
            calendar.isDate($0.when, inSameDayAs: oldest) || calendar.isDate($0.when, inSameDayAs: before)
        }
        return (run, cut)
    }
}
