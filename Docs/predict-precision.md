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

**P6 — Say how sure it is.** The 32 wrong lines that remain are prose: notes at 89.8 % precision
is now the worst category, and no list can vouch for a sentence. The scorer already reads a line's likelihood; a generated line is
drawn today without ever being scored. Scoring it and drawing only what clears a floor turns
precision into a dial rather than an argument. Measured last, because it costs a second pass.

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

## What this trades away

Coverage falls, and some of it will feel like a loss: the address bar goes quiet unless the person
has been there before, and short prefixes stop answering. That is the trade being made
deliberately. A feature that speaks less often and is right when it speaks is one a person keeps
switched on.
