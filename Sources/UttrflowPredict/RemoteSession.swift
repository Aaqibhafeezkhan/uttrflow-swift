/// A terminal handed to another machine, which nothing on this disk describes. See `Docs/predict-terminal-paths.md`.
public enum RemoteSession {
    /// What a remote session is scoped by: no path and no host, so nothing here resolves a file or a listing from it.
    public static let scope = "remote-session:"

    /// The programs that hand a terminal to another machine, named as a window title names the foreground one.
    static let programs: Set<String> = ["ssh", "mosh", "mosh-client"]

    /// Whether a window title names a program running this terminal on another machine.
    public static func isNamed(inWindowTitle title: String?) -> Bool {
        guard let title else { return false }
        return Self.words(of: title).contains { programs.contains($0) }
    }

    /// Whether a scope names a remote session rather than a place on this Mac.
    public static func names(_ scope: String?) -> Bool {
        scope == Self.scope
    }

    /// The title's words, keeping what a path is made of together, so a directory called `~/.ssh` is not the program `ssh`.
    static func words(of title: String) -> [String] {
        title.split { !($0.isLetter || $0.isNumber || "-_./~@+".contains($0)) }.map(String.init)
    }
}
