# Tab-to-complete: accuracy is the product

A suggestion that is wrong costs more than a suggestion that never appeared. The wrong one has to
be read, judged and rejected, and it spends something that does not come back: the belief that
what appears is worth looking at. Once a person has learned to ignore the grey text, a better
model cannot win them back, because they are no longer reading it.

So the feature is not judged on how often it answers. It is judged on how often it is right when
it answers, and it may answer as rarely as it must to keep that number high.

## The number

**Precision** is the share of the suggestions actually drawn that were right. **Coverage** is the
share of moments where anything was drawn at all. The bake-off prints both
(`uttrflow-bakeoff complete --fixtures`), and precision is printed to two decimal places because
the last of them is what the bar is set on.

| | Run 8, before | Run 9, addresses refused | Run 10, searches refused too |
|---|---|---|---|
| Precision | 94.07 % | 95.80 % | **96.74 %** |
| Coverage | 98 % | 92.9 % | 85.1 % |
| Wrong lines drawn | 67 | 45 | **32** |

Half the wrong lines are gone for thirteen points of coverage. Read as a hit rate the same two
changes look like 112 regressions, which is exactly the reading this document rejects: a line
withheld because nothing could vouch for it is not a failure of the same kind as a line drawn and
wrong.

Roughly one suggestion in seventeen was wrong. That is what "no accuracy" felt like, and the hit
rate of 94 % hid it, because a hit rate counts a silence and a lie as the same kind of miss.

**The bar: precision at or above 99 %, coverage whatever it costs.** A category that cannot reach
it stays quiet in that register until something can ground it.

## Two causes, not one

**Stale context.** The suggestion was right for a moment that has passed: another conversation,
another thread, another page. A chat composer publishes the same name in every conversation, so
one corpus and one set of "lines this person wrote here" served every thread; a line typed to one
person was offered to another. The rule this breaks is the one that matters most in a messaging
app: **what is on the screen now outranks anything remembered from before.**

**Guessing where nothing grounds the guess.** A host after three letters, a search phrase after
two, a file the machine never listed. In a terminal this was answered by asking the machine
(`predict-agent.md`); everywhere else the model is still free to invent, and invention is where
the wrong lines come from.

## The steps

**P1 — A field is identified by what it is writing to. Done.** A field that owns no document is
now scoped by the window that holds it, so two conversations are two corpora and two sets of
recent lines. Window counts and edit marks (`Priya (3)`, `Draft •`) are stripped, so a thread
stays one thread; a title long enough to be a document's first line names nothing and is ignored;
a field that owns a document keeps its own scope, so a browser stays by host and a terminal by
directory — except a terminal whose window title names a remote session, which is scoped as the
session, since the directory it publishes is this Mac's and not the one the shell is in. See
`predict-terminal-paths.md`.

**P2 — Precision is the headline. Done.** The bake-off and the scorecard report precision,
coverage and the count of wrong lines, per category. Every step below is judged on that curve.

**P3 — Refuse what cannot be known: a web address. Done.** A host exists in this person's history
or nowhere; no model can know it. The generator no longer answers where addresses are written.
Measured on those fixtures alone: precision 74.1 % → 83.5 %.

**P4 — Refuse what cannot be known: a search phrase. Done.** What was left wrong after P3 was not
addresses but search boxes guessing from two to four characters — `ni` → `ni-ghts`, `blue` →
`blue tooth`, `def` → `def show_menu`, `receipts 20` → `receipts 2023` — and a search phrase is
the same kind of thing as a host: it is what this person has looked for before, or it is
unknowable. A field whose own name says it searches or finds is now answered by the corpus alone.
The name is the test, and it is deliberately narrow: an editor calls its own field a query or a
filter, and what it holds is grounded by the schema on the screen, so those still answer (SQL
holds at 97.5 % precision and full coverage).

Together these silence the generator across the whole address-and-search category. In the
application the corpus still answers there, from what this person has actually typed; in the
bake-off, which measures the generator alone, the category reads as no coverage at all, and that
is the honest picture of what a model can contribute to it.

**P5 — The screen outranks the memory where the window will not say which thread it is.** P1 reaches
every application whose window names what is being written to. It does not reach the ones whose
window names only themselves: the Claude desktop app titles its window `Claude`, and a title equal
to the application's own name is now treated as no identity at all rather than as one shared by
every thread in it. Those applications need the identity to come from the screen, and until it
does the rule has to be the blunt one: where a conversation is on screen and the thread cannot be
named, a remembered line may teach the model this person's voice but may never be offered as the
line itself. Fixtures for it: a corpus holding another thread's lines, where the right answer uses
none of them.

**P6 — Say how sure it is. Done.** Most wrong lines are the model's own, in places no list can
vouch for: a sentence, a shopping-list item, a reply. Scoring each generated line and drawing
only what clears a floor turns precision into a dial rather than an argument.

A generated line is scored by the pass that wrote it, and a line below a set floor is not drawn.
While the model decodes, `RecordingSampler` keeps the log-probability of every token it chose,
and `GeneratedConfidence` averages the tokens that wrote the line's own words past the typing: a
word the typing still owed and anything the parser cut off the line are left out. No second
model pass is spent. A line no pass scored, such as one whose model was released since it was
written, is never drawn. A line drawn as `.certain` clears a stricter floor than one offered in a
`.choice`:

| Floor | Value | What clears it |
|---|---|---|
| `certainFloor` | −0.9 | the one line drawn alone as `.certain` |
| `choiceFloor` | −1.5 | a line offered as one of several in a `.choice` |

Both are mean log-probability per generated token on gemma-3-4b-it-qat-4bit, which is a
different scale from `plausibilityFloor`: that one reads a remembered line with no context, and
stays −6.0.

`certainFloor` is set from the 1,173-fixture catalogue (`uttrflow-bakeoff complete --fixtures
--judge`, which prints this table). Coverage is the share of fixtures that drew a line:

| Floor on the pass's own score | Precision | Wrong drawn | Coverage |
|---|---|---|---|
| none | 87.15 % (217/249) | 32 | 77.75 % |
| −1.5 | 87.85 % (217/247) | 30 | 77.15 % |
| −1.0 | 88.57 % (217/245) | 28 | 75.87 % |
| **−0.9** | **90.04 % (217/241)** | **24** | **74.68 %** |
| −0.75 | 90.38 % (216/239) | 23 | 71.44 % |
| −0.6 | 91.77 % (212/231) | 19 | 67.01 % |
| −0.5 | 92.48 % (209/226) | 17 | 61.04 % |

−0.9 is the lowest floor that keeps every judged right line. The eight judged lines it holds
back were all wrong, and it costs 3 points of coverage. Above it, each step loses right lines as
fast as wrong ones.

The scorer's own second pass separates right from wrong about as well at the same coverage
(90.27 % at 72.63 % with a −8.0 floor, 90.83 % at 67.95 % with −6.0), but it costs one more
pass per line, a median of about 100 ms on this machine under load. It is not used for
generated lines. A −3.0 floor on that second pass reached 97.20 % precision, but at 40.58 %
coverage.

The eight it holds back are `npx esl` → `npx eslinit`, `def subtr` → `def subtrack`, two
Hinglish replies, and four shopping-list items (`to` → `toppings` twice, `di` → `diets`, `pan` →
`pan cakes`). The 24 wrong lines that remain are ones the model writes with confidence: nine
shopping-list items (`ba` → `bacon`, `yog` → `yogurt`), five commands (`npx pret` → `npx
pretify`), three SQL lines, three replies, two code lines, one mail line and one robustness case.
The pass's own score cannot see these, so they need another check.

`choiceFloor` is not set from the catalogue, because the catalogue draws one line per fixture.
−1.5 refuses only the two least likely of the 32 wrong lines, and a person chooses from a list on
purpose.

`SuggestionScoringTests` pins the contract. A line under `certainFloor` leaves the turn quiet
(`modelUnsure`). A line over it is drawn. An unscored line is never drawn. An unscored
alternative is dropped, and a value the machine listed needs no score. `GeneratedConfidenceTests`
pins which tokens score a line.

**P7 — A generated line keeps to this person's shape. Done, not yet measured.** Both models'
lines pass through `CompletionText.finished`, so the rules hold on either path. Prose — a reply
or a document's line — ends at its first sentence end, since the tail of a run-on line is where
a clause goes wrong; a stop inside a number, an address, an abbreviation or an ellipsis is read
past. Prose that repeats five or more screen words in a row that this person has not written
here is refused: the other person's last message is the likeliest thing for a small model to
echo, and it is never the reply. Commands are exempt, because they reuse the paths and names on
screen. Every continuation is held to three times this person's typical line here (never under
16 characters), and with no history to the register's own limit: 80 for a reply, 120 for a
command, 160 for a document. A reply's token budget follows the typical line too, so a terse
person is not given a paragraph's room. The `chat/echo` fixtures cover a reply that opens as the
last message does.

**P8 — A generated line adds no specific nobody gave it. Done, not yet measured.** A number, a
time, a date, an amount, a percentage, an email or a web address is the one kind of wrong that
reads as right, and one Tab puts it in a sent message. `CompletionText.finished` now refuses a
line from either model when a token it adds names such a specific and that exact token is not in
the typed text, this person's lines here, the screen or the machine's values. Tokens compare
lowercased with surrounding punctuation removed. There is no prefix or substring match. A digit
inside a name, as in `python3`, is not a number. The corpus is unaffected: a line this person
typed is theirs, specifics included. Each refusal is logged under `predict` as `DROP made-up
specific`, by reason only.

Code, queries and commands write a few numbers that carry no value of their own. In those
registers (not prose, an address bar or a search box) a word whose every number is one of these
is not a specific. A number assigned to or compared with a name whose last word is `id`, `ids`,
`pid`, `uid`, `uuid` or `guid` is still an invented id, and one after `<` or `>` is an invented
threshold. So is one passed as the argument of a call whose name ends in one of those words
(`findById(1)`, `byId(0)`, `getUserId(1)`), or listed in `IN (…)` after such a column. The
exemption holds only where the number is an operand of code: after an assignment,
a bracket, a separator, an operator or a member, or after `return`, `in`, `case`, `limit` and
the like. A number standing as a word after a command's word or after `~` or `^` is an argument
the command acts on, as in `kill 1`, `HEAD~1` or `tail -n 1`, and is a specific. Each row has a
case in `SpecificsTests`.

| literal | in code, a query or a command | in prose | why |
|---|---|---|---|
| `0`, `1`, `-1` | kept | refused | a start, a step, an index, a bound or "not found"; in prose `at 1` is a time |
| `0.0`, `1.0` | kept | refused | the float forms of nothing and one |
| `true`, `false`, `nil`, `null`, `None` | kept | kept | words, never a specific |
| `""`, `''`, `[]`, `{}` | kept | kept | empty values, never a specific |
| `id = 1`, `user_id = 1`, `userId: 0`, `"id": 1` | refused | refused | a record nobody named |
| `findById(1)`, `getUserId(0)`, `id IN (1)` | refused | refused | a record nobody named, passed as an argument |
| `> 0`, `>= 0`, `< 1` | refused | refused | a threshold is a choice the line never showed |
| `kill 1`, `HEAD~1`, `tail -n 1`, `sleep 1` | refused | refused | an argument a command acts on: a process, a commit, a count |
| `2`, `10`, `1042`, `0.5`, `19.99` | refused | refused | a count, an id or an amount |
| `01`, `1e9`, `0x1f`, `1_000`, `1s` | refused | refused | a literal with a form, a base or a unit carries a choice |
| `$0`, `0%` | refused | refused | an amount sign or a percent sign reads as an amount |

## What this trades away

Coverage falls, and some of it will feel like a loss: the address bar goes quiet unless the person
has been there before, and short prefixes stop answering. That is the trade being made
deliberately. A feature that speaks less often and is right when it speaks is one a person keeps
switched on.
