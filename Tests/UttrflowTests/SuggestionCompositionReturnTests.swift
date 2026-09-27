// Tests that a Return confirming an input method's conversion is not taken as the line being finished (#2123).

import Foundation
import Testing
import UttrflowPredict
import UttrflowPredictCapture

@testable import Uttrflow

@Suite("A Return while an input method composes")
struct SuggestionCompositionReturnTests {
    @Test("a Return after a read with marked text confirms the conversion, and does not end the line")
    func composingReturnIsAKeystroke() {
        #expect(!SuggestionCoordinator.endsLine(.return, composing: true))
    }

    @Test("a Return with no composition ends the line as it always has")
    func plainReturnEndsTheLine() {
        #expect(SuggestionCoordinator.endsLine(.return, composing: false))
        #expect(!SuggestionCoordinator.endsLine(.tab, composing: false))
        #expect(!SuggestionCoordinator.endsLine(.other, composing: false))
    }

    @Test("confirming conversions mid-line commits nothing, and the finished line commits once, whole")
    func confirmationsKeepThePendingLine() {
        var detector = CommitDetector()
        let moment = Date(timeIntervalSince1970: 1_800_000_000)
        // Each confirming Return reaches capture as the line it left, which is a keystroke.
        for line in ["今日は", "今日は会議", "今日は会議です"] {
            #expect(detector.receive(.keystroke(line, at: moment)) == nil)
        }
        let finished = detector.receive(.returnPressed(at: moment))
        #expect(finished == Commit(text: "今日は会議です", reason: .returnPressed))
    }
}
