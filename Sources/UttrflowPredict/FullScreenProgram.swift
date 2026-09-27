/// A terminal whose screen a full-screen program has taken, so the line at the caret is that program's and never a shell command.
public enum FullScreenProgram {
    /// Editors, pagers, pickers and monitors that draw the whole screen, named as a window title names the foreground one.
    static let programs: Set<String> = [
        "vim", "vi", "nvim", "view", "vimdiff", "nano", "pico", "emacs", "micro", "hx", "helix", "kak",
        "less",
        "more", "most", "man", "fzf", "sk", "peco", "fzy", "htop", "top", "btop", "atop", "glances",
        "lazygit",
        "tig", "gitui", "ranger", "nnn", "lf", "yazi", "mc", "ncdu", "k9s", "mutt", "neomutt", "w3m", "lynx",
        "watch",
    ]

    /// Whether a window title names a program that owns the terminal's screen.
    public static func isNamed(inWindowTitle title: String?) -> Bool {
        guard let title else { return false }
        return RemoteSession.words(of: title).contains { programs.contains($0) }
    }
}
