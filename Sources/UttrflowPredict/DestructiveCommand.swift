/// Recognises command lines that destroy data or the machine, so they are never learned or auto-offered.
public enum DestructiveCommand {
    /// Whether taking this line as a completion could do irreversible harm, judged conservatively.
    public static func matches(_ text: String, failClosedOnUnresolved: Bool = false) -> Bool {
        // A fork bomb carries no ordinary tokens, so it is matched on the whitespace-stripped text.
        if text.lowercased().filter({ !$0.isWhitespace }).contains(":(){:|:&};:") { return true }
        let lower = text.lowercased()
        if lower.contains("of=/dev/") || lower.contains("/dev/sd") || lower.contains("/dev/disk")
            || lower.contains("/dev/rdisk")
        {
            return true
        }
        guard let clauses = ShellWords.commands(in: text, home: "") else { return failClosedOnUnresolved }
        return clauses.contains { clause in
            if failClosedOnUnresolved,
                (clause.words + clause.inputs).contains(where: \.isUnresolved)
            {
                return true
            }
            if clause.overwrites.contains(where: { !harmlessOutputs.contains($0.text) }) { return true }
            return destroys(clause.words, failClosedOnUnresolved: failClosedOnUnresolved)
        }
    }

    /// Devices a `>` writes to without emptying any file.
    private static let harmlessOutputs: Set<String> = [
        "/dev/null", "/dev/stdout", "/dev/stderr", "/dev/tty", "/dev/fd/1", "/dev/fd/2",
    ]

    /// Flags that make rsync delete files, in the destination or at the source.
    private static func rsyncDeletes(_ flag: String) -> Bool {
        flag == "--del" || flag.hasPrefix("--delete") || flag == "--remove-source-files"
            || flag == "--remove-sent-files"
    }

    /// A word that runs the command after it: its flags that take a value, and how many plain words of its own precede the command.
    private struct Wrapper {
        let valued: Set<String>
        var operands = 0
    }

    /// Words that run the command after them, each read past before the command is judged.
    private static let wrappers: [String: Wrapper] = [
        "sudo": Wrapper(valued: ["-u", "-g", "-h", "-p", "-C", "-D", "-r", "-t", "-U", "-T"]),
        "doas": Wrapper(valued: ["-u", "-C"]), "env": Wrapper(valued: ["-u", "-S", "-P"]),
        "nice": Wrapper(valued: ["-n"]), "nohup": Wrapper(valued: []), "time": Wrapper(valued: []),
        "command": Wrapper(valued: []), "builtin": Wrapper(valued: []), "exec": Wrapper(valued: ["-a"]),
        "noglob": Wrapper(valued: []), "nocorrect": Wrapper(valued: []),
        "xargs": Wrapper(valued: ["-I", "-J", "-L", "-n", "-P", "-s", "-E", "-R", "-S", "-d"]),
        "timeout": Wrapper(valued: ["-s", "--signal", "-k", "--kill-after"], operands: 1),
        "gtimeout": Wrapper(valued: ["-s", "--signal", "-k", "--kill-after"], operands: 1),
        "caffeinate": Wrapper(valued: ["-t", "-w"]), "watch": Wrapper(valued: ["-n", "--interval"]),
        "ionice": Wrapper(valued: ["-c", "-n", "-p", "-P", "-u"]), "chronic": Wrapper(valued: []),
        "unbuffer": Wrapper(valued: []), "stdbuf": Wrapper(valued: ["-i", "-o", "-e"]),
        "taskpolicy": Wrapper(valued: ["-c", "-d", "-g", "-t", "-l"]), "arch": Wrapper(valued: ["-arch"]),
        "flock": Wrapper(valued: ["-w", "--timeout", "-E", "--conflict-exit-code"], operands: 1),
        "chroot": Wrapper(valued: ["-u", "-g", "-G"], operands: 1), "pkexec": Wrapper(valued: ["--user"]),
    ]

    /// Programs that destroy whatever they are pointed at.
    private static let destroyers: Set<String> = [
        "rm", "rmdir", "shred", "srm", "unlink", "dd", "mkfs", "fdisk", "parted", "shutdown", "reboot",
        "halt",
        "poweroff",
    ]

    private enum Command {
        case none
        case unresolved
        case named(String, [String])
    }

    /// The program a parsed clause runs, read past assignments and every wrapper.
    private static func command(in tokens: [ShellWord]) -> Command {
        var rest = tokens[...]
        while let first = rest.first {
            guard !first.isUnresolved else { return .unresolved }
            let name = programName(first.text)
            if TerminalLineCheck.isAssignment(first.text), rest.count > 1 {
                rest.removeFirst()
                continue
            }
            guard let wrapper = wrappers[name], rest.count > 1 else {
                return .named(name, Array(rest.dropFirst().map(\.text)))
            }
            rest.removeFirst()
            while let flag = rest.first, flag.text.count > 1, flag.text.hasPrefix("-") {
                guard !flag.isUnresolved else { return .unresolved }
                rest.removeFirst()
                if wrapper.valued.contains(flag.text), !rest.isEmpty { rest.removeFirst() }
            }
            rest = rest.dropFirst(wrapper.operands)
        }
        return .none
    }

    /// The first kubectl argument that is neither a global flag nor the value a flag takes.
    private static func kubectlVerb(_ lowered: [String]) -> String? {
        let valued: Set = [
            "-n", "--namespace", "--context", "--kubeconfig", "--cluster", "--user", "-s", "--server",
            "--token", "--as", "--as-group", "--as-uid", "--request-timeout", "-v", "--v", "--cache-dir",
            "--certificate-authority", "--client-certificate", "--client-key", "--tls-server-name",
            "--password", "--username", "--profile", "--profile-output", "--log-file", "--vmodule",
        ]
        var rest = lowered[...]
        while let word = rest.popFirst() {
            guard word.hasPrefix("-") else { return word }
            if valued.contains(word), !rest.isEmpty { rest.removeFirst() }
        }
        return nil
    }

    /// A parsed command word as the program it names, lowercased.
    private static func programName(_ word: String) -> String {
        (word.split(separator: "/").last.map(String.init) ?? word).lowercased()
    }

    /// Whether one clause destroys data or the machine.
    private static func destroys(_ tokens: [ShellWord], failClosedOnUnresolved: Bool) -> Bool {
        let parsed = command(in: tokens)
        if case .unresolved = parsed { return failClosedOnUnresolved }
        guard case .named(let command, let arguments) = parsed else { return false }
        let lowered = arguments.map { $0.lowercased() }
        if destroyers.contains(command) || command.hasPrefix("mkfs.") { return true }
        switch command {
        case "git":
            if matchesDestructiveGit(arguments) { return true }
        case "find":
            if lowered.contains("-delete") { return true }
            // The command `-exec` runs is judged as its own clause, so a wrapper in front of it is read past.
            if let exec = tokens.firstIndex(where: { ["-exec", "-execdir"].contains($0.text.lowercased()) }),
                destroys(Array(tokens[(exec + 1)...]), failClosedOnUnresolved: failClosedOnUnresolved)
            {
                return true
            }
        case "diskutil":
            let verbs = [
                "erase", "zerodisk", "randomdisk", "securerase", "partitiondisk", "reformat", "deletevolume",
                "deletecontainer",
            ]
            if lowered.contains(where: { word in verbs.contains(where: word.hasPrefix) }) { return true }
        case "docker", "podman":
            if lowered.contains("prune") || (lowered.first == "volume" && lowered.dropFirst().first == "rm") {
                return true
            }
        case "kubectl":
            if kubectlVerb(lowered) == "delete" { return true }
        case "terraform", "tofu":
            if lowered.contains("destroy") || lowered.contains("-destroy") { return true }
        case "crontab":
            if lowered.contains("-r") { return true }
        case "sh", "bash", "zsh", "dash", "ksh", "fish":
            if let script = shellScript(arguments),
                matches(script, failClosedOnUnresolved: failClosedOnUnresolved)
            {
                return true
            }
        case "mv", "cp":
            if lowered.last == "/dev/null" { return true }
        case "rsync":
            if lowered.contains(where: rsyncDeletes) { return true }
        case "tee":
            // Without `-a` tee empties every file it names, as `>` does.
            let appends =
                lowered.contains("--append")
                || lowered.contains { shortFlags($0, include: "a", valuesAfter: []) }
            if !appends, lowered.contains(where: { !$0.hasPrefix("-") && !harmlessOutputs.contains($0) }) {
                return true
            }
        default:
            break
        }

        guard sqlVerbs.contains(command) || sqlClients.contains(command) else { return false }
        // SQL that drops or empties a table, wherever the verb sits in the statement.
        let words = Set(
            ([command] + lowered).flatMap {
                $0.split(whereSeparator: { !$0.isLetter && !$0.isNumber && $0 != "_" }).map(String.init)
            })
        if words.contains("drop"), words.contains(where: droppableObject) { return true }
        return words.contains("truncate")
    }

    /// The command string a shell is given with `-c`, which it runs as a line of its own.
    private static func shellScript(_ arguments: [String]) -> String? {
        guard
            let flag = arguments.firstIndex(where: {
                $0.hasPrefix("-") && !$0.hasPrefix("--") && $0.dropFirst().contains("c")
            })
        else { return nil }
        return arguments.dropFirst(flag + 1).first { !$0.hasPrefix("-") }
    }

    /// SQL verbs that begin a statement typed straight into a database prompt.
    private static let sqlVerbs: Set<String> = ["drop", "truncate", "alter"]

    /// Programs that run the SQL they are given.
    private static let sqlClients: Set<String> = [
        "psql", "mysql", "mariadb", "sqlite3", "sqlite", "sqlcmd", "duckdb", "clickhouse",
        "clickhouse-client", "cockroach", "snowsql", "bq", "pgcli", "mycli", "litecli", "usql", "osql",
        "isql", "sqlplus", "db2",
        "trino", "presto", "spark-sql", "hive", "beeline", "cqlsh", "impala-shell", "vsql", "redshift",
    ]

    /// Whether a git clause throws work away for good: a forced or deleting push, a hard reset, a forced clean, a forced branch deletion, a dropped stash, or changes discarded by a checkout, switch or restore.
    private static func matchesDestructiveGit(_ arguments: [String]) -> Bool {
        let head = subcommandIndex(arguments)
        // The flags of the clause's own subcommand, so the same word as a message or path is not one.
        func flags(after subcommand: String) -> ArraySlice<String>? {
            guard let head, arguments[head] == subcommand else { return nil }
            return arguments[(head + 1)...]
        }
        if let flags = flags(after: "push"),
            flags.contains(where: {
                $0.hasPrefix("--force") || $0 == "-f" || $0 == "--delete" || $0 == "-d" || $0.hasPrefix("+")
                    || ($0.hasPrefix(":") && $0.count > 1)
            })
        {
            return true
        }
        if let flags = flags(after: "reset"), flags.contains("--hard") { return true }
        if let flags = flags(after: "clean"),
            flags.contains(where: {
                $0.hasPrefix("-") && !$0.hasPrefix("--") && $0.lowercased().contains("f")
            })
                || flags.contains("--force")
        {
            return true
        }
        if let flags = flags(after: "branch"),
            flags.contains(where: {
                $0 == "-D" || ($0.hasPrefix("-") && !$0.hasPrefix("--") && $0.contains("D"))
            })
                || (flags.contains("--delete") && flags.contains("--force"))
        {
            return true
        }
        if let flags = flags(after: "stash"), flags.first == "drop" || flags.first == "clear" { return true }
        if let flags = flags(after: "checkout"),
            flags.contains("--") || flags.contains(".") || flags.contains("--force")
                || flags.contains(where: { shortFlags($0, include: "f", valuesAfter: ["b", "B"]) })
        {
            return true
        }
        if let flags = flags(after: "switch"),
            flags.contains("--force") || flags.contains("--discard-changes")
                || flags.contains(where: { shortFlags($0, include: "f", valuesAfter: ["c", "C"]) })
        {
            return true
        }
        if let flags = flags(after: "restore"), !flags.contains("--staged") || flags.contains("--worktree") {
            return true
        }
        return false
    }

    /// Whether a cluster of short flags holds this one, read only up to the first flag whose value runs on in the same word.
    private static func shortFlags(
        _ word: String, include flag: Character, valuesAfter valued: Set<Character>
    ) -> Bool {
        guard word.hasPrefix("-"), !word.hasPrefix("--") else { return false }
        for letter in word.dropFirst() {
            if letter == flag { return true }
            if valued.contains(letter) { return false }
        }
        return false
    }

    /// Where the subcommand stands once git's own leading options are skipped, or nil when there is none.
    private static func subcommandIndex(_ arguments: [String]) -> Int? {
        var index = arguments.startIndex
        while index < arguments.endIndex {
            let word = arguments[index]
            guard word.hasPrefix("-") else { return index }
            index += gitOptionsTakingValue.contains(word) ? 2 : 1
        }
        return nil
    }

    /// Git's leading options whose value is the next word.
    private static let gitOptionsTakingValue: Set<String> = [
        "-C", "-c", "--git-dir", "--work-tree", "--namespace", "--super-prefix", "--config-env",
    ]

    /// The kinds of thing a DROP destroys, which is what makes the statement irreversible.
    private static func droppableObject(_ word: String) -> Bool {
        word == "table" || word == "database" || word == "schema" || word == "index"
    }
}
