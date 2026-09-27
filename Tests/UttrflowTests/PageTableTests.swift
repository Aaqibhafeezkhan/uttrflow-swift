// The redesigned tables' column arithmetic.

import Testing

@testable import Uttrflow

@Suite("Page columns")
struct PageTableTests {
    @Test("fixed columns keep their width and the shares split what is left")
    func sharesSplitTheRest() {
        let columns = PageColumns(widths: [.share(1), .share(3), .fixed(40)], spacing: 10)
        #expect(columns.cellWidths(in: 460) == [100, 300, 40])
    }

    @Test("a row narrower than its fixed columns gives the shares nothing")
    func narrowRow() {
        let columns = PageColumns(widths: [.share(1), .fixed(100)], spacing: 12)
        #expect(columns.cellWidths(in: 50) == [0, 100])
    }

    @Test("a table of fixed columns only has nothing to share")
    func fixedOnly() {
        #expect(PageColumns(widths: [.fixed(30), .fixed(20)]).cellWidths(in: 400) == [30, 20])
    }
}
