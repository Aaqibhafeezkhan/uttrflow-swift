// Tests that an application is named as it names itself, whether it is running or only installed.

import Testing

@testable import Uttrflow

@Suite("An installed application's name")
struct InstalledApplicationNameTests {
    @Test("the Finder is named as it names itself")
    func theFinderIsNamed() {
        #expect(InstalledApplicationName.lookUp("com.apple.finder") == "Finder")
    }

    @Test("an application that is installed but not running is named from its bundle")
    func anInstalledApplicationIsNamed() {
        #expect(InstalledApplicationName.lookUp("com.apple.TextEdit") == "TextEdit")
    }

    @Test("an identifier names the same application however it is cased")
    func anyCaseNamesTheSameApplication() {
        let first = InstalledApplicationName.lookUp("com.apple.TextEdit")
        #expect(first != nil)
        #expect(InstalledApplicationName.lookUp("COM.APPLE.TEXTEDIT") == first)
    }

    @Test("an application nobody installed has no name, so the list falls back to its identifier")
    func anUnknownApplicationHasNoName() {
        #expect(InstalledApplicationName.lookUp("com.example.not-installed-anywhere") == nil)
    }
}
