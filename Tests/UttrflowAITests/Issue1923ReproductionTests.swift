import Testing
import UttrflowCore

@testable import UttrflowAI

/// Issue #1923: in a terminal the first word of a dictated command must keep its heard case.
@Suite("Issue1923")
struct Issue1923ReproductionTests {
    private let terminal = AppContext(
        applicationName: "Terminal", bundleIdentifier: "com.apple.Terminal")
    private let codeEditor = AppContext(
        applicationName: "Xcode", bundleIdentifier: "com.apple.dt.Xcode",
        documentName: "AppDelegate.swift")

    private func cleaned(_ spoken: String, into app: AppContext) -> String {
        let situation = SituationResolver.resolve(from: app)
        let formatter = DestinationFormatter.standard(for: situation.destination)
        return CleaningPipeline.standard(for: formatter, situation: situation)
            .run(Draft(text: spoken)).text
    }

    /// A terminal app resolves to the terminal destination rather than the code editor's.
    @Test("the terminal destination is reached from com.apple.Terminal")
    func terminalResolvesToTerminal() {
        let destination = SituationResolver.resolve(from: terminal).destination
        #expect(destination == .terminal)
    }

    /// A code editor still resolves to the code editor destination.
    @Test("the code editor destination is reached from Xcode")
    func codeEditorStillResolvesToCodeEditor() {
        let destination = SituationResolver.resolve(from: codeEditor).destination
        #expect(destination == .codeEditor)
    }

    /// The terminal formatter keeps the first word's heard case, since the shell is case-sensitive.
    @Test("the terminal formatter copies the first word's heard case")
    func terminalFormatterPolicy() {
        let formatter = DestinationFormatter.standard(for: .terminal)
        #expect(formatter.firstWord == .asSpoken)
        #expect(formatter.terminalStop == .never)
        #expect(formatter.layout.contains(.preserveNewlines))
        #expect(formatter.grammar == .asSpoken)
    }

    /// The exact cases the issue lists: every lower-case command stays lower-case.
    @Test(
        "a dictated command keeps the case the speaker said",
        arguments: [
            "ls dash la", "npm run build", "git commit dash m fix the login bug",
            "cd documents slash projects", "docker compose up dash d",
        ]
    )
    func terminalCommandsKeepTheirCase(spoken: String) {
        #expect(cleaned(spoken, into: terminal) == spoken)
    }

    /// The case the speaker said is preserved through the deterministic pipeline, not just by the formatter.
    @Test("ls dash la into Terminal stays ls dash la, in the rules path")
    func terminalKeepsCaseInTheRulesPath() {
        #expect(cleaned("ls dash la", into: terminal) == "ls dash la")
        #expect(cleaned("npm run build", into: terminal) == "npm run build")
    }

    /// A code editor still capitalises the start of a sentence, so the fix has not over-corrected.
    @Test("a code editor capitalises the start of a dictated sentence")
    func codeEditorStillCapitalises() {
        #expect(cleaned("the build failed", into: codeEditor) == "The build failed")
        #expect(cleaned("function do thing", into: codeEditor) == "Function do thing")
    }

    /// A capitalised word mid-sentence in a code editor is left alone; a terminal never capitalises anyway.
    @Test("the code editor still mid-sentence lower-cases a first word at an unknown caret")
    func codeEditorMidSentenceLowercases() {
        let midway = AppContext(
            applicationName: "Xcode", bundleIdentifier: "com.apple.dt.Xcode",
            documentName: "AppDelegate.swift",
            precedingText: "we ran the suite. then ")
        let situation = SituationResolver.resolve(from: midway)
        let formatter = DestinationFormatter.standard(for: situation.destination)
        let cleaned = CleaningPipeline.standard(for: formatter, situation: situation)
            .run(Draft(text: "the build failed")).text
        #expect(cleaned == "the build failed")
    }
}
