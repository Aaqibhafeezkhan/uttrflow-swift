// Tests for reading this Mac's name.

import Testing

@testable import Uttrflow

@Suite("This Mac's name")
struct MacNameTests {
    /// Every Mac has a computer name, so the Account page's This Mac row has something to say.
    @Test("reads a name that is not blank")
    func readsAName() {
        let name = MacName.current?.trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(name?.isEmpty == false)
    }
}
