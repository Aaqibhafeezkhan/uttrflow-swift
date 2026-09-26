// Tests that every file and directory the environment reader touches goes through its filesystem, which refuses a remote volume.

import Foundation
import Testing

@testable import UttrflowPredict

/// A launcher that must never be asked, since file lookups run no program.
private struct SilentLauncher: ProgramLaunching {
    func output(of launch: ProgramLaunch) async -> String? { nil }
}

/// A reader over `disk` alone.
private func reader(_ disk: any FileSystemProbing) -> SystemEnvironmentReader {
    SystemEnvironmentReader(launcher: SilentLauncher(), programDirectories: [], files: disk)
}

/// A filesystem that stands in for the disk and fails the test if a remote path reaches it.
private func guardedSystem() -> SystemFileSystem {
    SystemFileSystem(
        homeDirectory: "/Volumes/Home/someone",
        probe: { path in
            Issue.record("stat reached the disk for \(path)")
            return .missing
        },
        timeBox: { _, _ in nil })
}

struct EnvironmentReaderFileAccessTests {
    @Test func makeTargetsAreReadThroughTheFilesystem() async {
        let disk = FakeDisk(texts: ["/p/Makefile": "build:\n\techo\n"])
        #expect(await reader(disk).values(of: .subcommand(of: "make"), in: "/p") == ["build"])
        #expect(disk.operations.contains(.read("/p/Makefile")))
    }

    @Test func justRecipesAreReadThroughTheFilesystem() async {
        let disk = FakeDisk(texts: ["/p/justfile": "test:\n    echo\n"])
        #expect(await reader(disk).values(of: .subcommand(of: "just"), in: "/p") == ["test"])
    }

    @Test func packageScriptsAreReadThroughTheFilesystem() async {
        let disk = FakeDisk(texts: ["/p/package.json": #"{"scripts":{"dev":"x"}}"#])
        #expect(await reader(disk).values(of: .subcommand(of: "npm run"), in: "/p") == ["dev"])
    }

    @Test func aliasesAreReadFromTheFilesystemsHome() async {
        let disk = FakeDisk(home: "/h", texts: ["/h/.zshrc": "alias gs='git status'\n"])
        #expect(await reader(disk).values(of: .alias, in: "/p") == ["gs"])
    }

    @Test func entriesAreListedThroughTheFilesystem() async {
        let disk = FakeDisk(directories: ["/p/src"], files: ["/p/a.txt"])
        #expect(await reader(disk).values(of: .entries(under: ""), in: "/p") == ["a.txt", "src"])
        #expect(await reader(disk).values(of: .directories(under: ""), in: "/p") == ["src"])
    }

    @Test func aDirectoryThatDoesNotAnswerIsNoAnswer() async {
        let disk = FakeDisk(unknown: ["/p"])
        #expect(await reader(disk).values(of: .entries(under: ""), in: "/p") == nil)
    }

    @Test func aRemoteProjectIsNeverRead() async {
        let reader = reader(guardedSystem())
        #expect(await reader.values(of: .subcommand(of: "make"), in: "/Volumes/Share/p") == nil)
        #expect(await reader.values(of: .subcommand(of: "just"), in: "/Volumes/Share/p") == nil)
        #expect(await reader.values(of: .subcommand(of: "npm run"), in: "/Volumes/Share/p") == nil)
        #expect(await reader.values(of: .entries(under: ""), in: "/Volumes/Share/p") == nil)
    }

    @Test func aRemoteHomeIsNeverReadForAliases() async {
        #expect(await reader(guardedSystem()).values(of: .alias, in: "/tmp") == [])
    }
}
