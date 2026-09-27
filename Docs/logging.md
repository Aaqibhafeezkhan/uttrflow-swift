# What the unified log may carry

Uttrflow writes to the unified log under the subsystem `com.uttrflow.Uttrflow`. Anybody who
can read this Mac's log can read those messages, and a message marked `privacy: .public`
also travels unredacted in anything that collects logs, such as a sysdiagnose.

## The rule

**No log message carries text a person typed, read, said or was offered.** That covers the
focused field's line and value, a suggestion's candidates and completions, an accepted
completion, a prompt, a transcript, what was heard, a clip, a dictionary word or snippet, and
another application's window title or document name.

A message carries the shape of that text instead: its length in characters, a count, whether
it is present, and the reason, route, engine or timing that explains what happened.

Swapping `.public` for `.private` is not a fix. A private value is still captured, and a Mac
configured to reveal private data shows it in clear. The text is left out altogether.

An error from a model or a third-party framework is logged by its type and case
(`SuggestionLog.failure`), because its payload may hold the text the model was given or wrote.

## Tab-to-complete

`Sources/Uttrflow/Suggestion/SuggestionLog.swift` builds the predict lines that describe the
typed line, and `SuggestionLogTests` checks each one against invented text; `TURN` and
`CONTEXT` log their lengths inline. The keys are:

| Line | Carries |
|---|---|
| `TURN` | the front application's bundle identifier, `lineChars`, the value's `chars`, the role, `labelChars`, whether the field has an identifier, placement |
| `QUERY` | `typedChars`, how many candidates the corpus held, whether the model is ready |
| `OPTIONS` | `typedChars`, and `none` or how many values the machine offers |
| `QUIET` | `typedChars`, the silence's reason, rejections, whether the field is silenced |
| `GENERATE` | the application name, `typedChars`, how many lines, elapsed time, `firstChars` |
| `ALTERNATIVES` | `typedChars`, how many lines, elapsed time |
| `ATTEST` | `typedChars`, lines in, lines out, how many were dropped |
| `VERIFY` | `typedChars`, candidates in and out, elapsed time, `firstChars` |
| `ACCEPT` | the completion's `chars`, `typedChars`, the insertion route |
| `CONTEXT` | the lengths of the window title, the surroundings and the preceding text, and how many recent lines |
| `STALL` | the step the turn left behind was waiting on, and the bundle identifier of the application it read |

A run is followed by these sizes and by the order of the lines, which is enough for
`Scripts/e2e_predict.sh`: it types text it chose, so it knows the length to expect.

## Sign-in and the session

`HTTPAuthenticationService` and `KeychainTokenStore` log each step under the category
`account`, by port and HTTP status alone. No token, code, state, email address or name is
logged.

| Line | Says |
|---|---|
| `sign-in: waiting on loopback port N` | the browser was given a page that comes back to port N |
| `sign-in: no loopback port, signing in by code instead` | no port bound, so the device code is shown |
| `sign-in: the browser came back, exchanging the code` | the redirect reached the port |
| `sign-in: token exchange answered N` | `POST /v1/auth/token` answered N |
| `session: token kept in the data-protection keychain` or `file-based keychain` | which keychain took the refresh token |
| `sign-in: the Keychain refused the session` | neither keychain took it; the sign-in fails |
| `sign-in: profile answered N` | the first `GET /v1/me` answered N |
| `profile refused: unsigned, wrongly signed or inconsistent` | the entitlement did not verify |
| `session: refresh answered N` | `POST /v1/auth/refresh` answered N; 401 signs this Mac out |
| `session: profile answered N` | a later `GET /v1/me` answered N; 304 means unchanged |
| `session: signed out on this Mac` | both halves of the session are gone |

## How it is enforced

`Scripts/log_privacy_audit.py` runs in `make verify` (`make log-audit`). It reads every
interpolation inside a `Logger` call in `Sources/`, and every interpolation in a file whose
name ends in `Log.swift`, and fails when the interpolated value still names user text —
`typed`, `text`, `line`, `value`, `candidate`, `completion`, `prompt`, `transcript`, `spoken`,
`heard`, `clip` and the rest of its list — once `.count`, `.isEmpty` and `!= nil` are taken
out. It fails whatever the privacy level.

It also fails when a message publishes a description: `String(describing:)`,
`String(reflecting:)`, `.localizedDescription`, `.description`, or a bare value named like an
error or a failure, at every privacy level, including `.private` — a private value is still
captured, so marking a description private is not a fix, only a narrower leak. An error's
description can carry its payload — a database path under the home folder, a raw SQLite
message, the text a model was given — so an error is logged by `SuggestionLog.failure`, which
keeps its type and case. A description of a value whose every case is fixed wording goes on the
audit's second list with its reason, printed on every run. `--self-test`, which `make
verify` passes, proves the audit still reports each kind of violation it looks for.

A value that matches a name and carries no user text goes on the audit's allow-list with its
reason, and the list is printed on every run. A call to a builder in a `Log.swift` file is
trusted at the call site because the builder's own file is scanned whole.

Both lists are keyed on the exact interpolation a log message carries, and the audit refuses to
report anything at all while an entry names a file that is gone, or an interpolation that file no
longer carries. An exception it cannot check is not one it has checked, and printing it beside a
clean scan would claim a privacy decision nobody made; it would also let the same expression come
back later and inherit the old exemption. So delete the entry with the log call, or point it at
the interpolation the message carries now and decide afresh. The match is parser-aware: the same
text in a comment or in an ordinary string does not keep an entry alive.

The audit reads names, not types, so it is a tripwire rather than a proof: a value called
something innocent can still carry text. Keep user text out of names like `message` and pass
it to a builder instead.
