# .claude/

What lives here, what loads when, and how to add to it without turning it back into a pile.

## Layout

| Path | Tracked in git? | Loaded when |
|---|---|---|
| `.claude/skills/<name>/SKILL.md` | **Yes** | Description loads every session (cheap); full body loads only when Claude decides the task matches the description, or the skill is invoked by name. |
| `.claude/README.md` (this file) | **Yes** | Never loaded automatically — read by a human, or by an agent asked to work on `.claude` itself. |
| `../CLAUDE.md` (repo root) | **No** — deliberately untracked (`ed6f6dd`) | Every session, in full, regardless of task. |
| `../iTgLegacy-notes/` | No — gitignored | Never automatically. Planning docs, design-reference screenshots, scratch material — opened by name when a task calls for that specific document. |
| `.claude/screenshots/` | No — gitignored | Never automatically. Temporary device screenshots; safe to delete any time, `clean.sh` does. |
| `.claude/AUDIT-LOG.md` | No — gitignored | Never automatically. One machine's running audit journal: round-by-round notes, local paths, device specifics. Local to whoever ran those rounds; it is not shared history. |
| `.claude/clean.sh` | No — gitignored | Never automatically. Run by hand when disk usage looks high or worktrees need pruning. |
| `.claude/commands/` | No — gitignored | Slash-command definitions (currently `perf-audit.md`); loaded when that command is invoked. |
| `.claude/settings.json` | **Yes** | Read by Claude Code at session start; wires the `PreToolUse` hook below. |
| `.claude/hooks/guard-device.py` | **Yes** | Runs before every `Bash` tool call — refuses `killall SpringBoard`/`uicache`/deleting the app bundle/a hard `kill -9` on Telegram/any `telegramdev://send` or `telegramdev://call`. |

The gitignore was narrowed deliberately (`fc3a131`) to exactly `../iTgLegacy-notes/`,
`.claude/screenshots/`, `.claude/clean.sh`, `.claude/commands/`, `.claude/AUDIT-LOG.md` — everything else under `.claude/`,
meaning `skills/` and this README, is tracked and travels with the repo. If you add a new kind of
disposable or machine-local material, ignore that specific new path; do not widen the ignore back
to all of `.claude/`.

## Why a skill and not a CLAUDE.md line

CLAUDE.md content loads in full, every session, regardless of what the task is — it is the right
place only for facts and rules that are relevant to essentially every task (the platform ceiling,
the no-comments rule, the settled design decisions, the highest-stakes "never act outward on the
user's account" rule). A skill's description loads every session but its body loads only when the
task matches — the right place for a multi-step procedure or a reference body that is only
relevant to a specific kind of task (deploying to a device, judging a screenshot, running the
build, writing Objective-C against this SDK, a shell/macOS gotcha).

The test before adding a new rule anywhere in `.claude/`: would a wrong guess here cost a real
incident (a respring, a logged-out user, a reverted design decision)? If yes, and it applies to
*every* task, it belongs in CLAUDE.md. If yes, but only to a specific *kind* of task, it belongs in
a skill. If a rule must hold with zero exceptions no matter what Claude decides, prose in either
place is a request, not a guarantee — see `code.claude.com/docs/en/hooks` and consider a
`PreToolUse`/`PostToolUse` hook in `.claude/settings.json` instead, the way `guard-device.py`
already blocks a respring, `uicache`, deleting the app bundle, or a hard kill of Telegram before
the `Bash` tool call that would do it ever runs.

## The five current skills

- **`device-deploy`** — building, SSH access, resigning, stop/start, the debug URL harness, and
  what must never be done to a physical device.
- **`look-verify`** — running `scripts/check-bubble-geometry.py`, its known false failures, nearest-neighbor
  zoom, and the look/behavior authority order (2013 original vs. modern Telegram-iOS vs. our own
  code).
- **`build-and-verify`** — the armv7 build, reading `make` output correctly, worktree symlink
  discipline, the duplicate-method scan, the layer linter, the comment check.
- **`objc-ios6`** — the iOS 6 SDK ceiling, the in-house replacements this project already uses,
  and the TDLib id-type traps specific to this client.
- **`shell-macos`** — BSD `sed` vs. GNU addressing, zsh word-splitting, zsh empty-glob errors.

Each was written from an actual incident or an actual repo fact, checked against the current
source rather than assumed — see `../iTgLegacy-notes/docs/claude-md-practice.md` for the research this
was built from, including the practitioner sources and the survey of ready-made skills that didn't
fit (none did; this project's combination of hand-written Makefile, dlopen'd TDLib, iOS 6 SDK
ceiling, and jailbroken-device SSH deploy has no existing off-the-shelf skill).

## Adding a skill

1. `mkdir .claude/skills/<name>` and write `<name>/SKILL.md` with YAML frontmatter:
   ```yaml
   ---
   name: <name>
   description: Use when <the specific trigger>. Covers <the one-line scope>.
   ---
   ```
   The `description` is the only field that matters for auto-loading — it is what Claude matches
   against the current task. Lead with the trigger ("use when..."), not a summary of the content.
   A vague description ("iOS build stuff") either never fires or fires on everything; a specific
   one ("use when building for armv7 or reading a make failure") fires only when it should.
2. Write the body as procedure and fact: concrete commands, file paths, and — for any rule that
   exists because something went wrong — one sentence saying what happened. An agent follows a
   rule it understands the cost of; it argues with or drifts from a rule stated as pure prohibition.
3. Do not pad. A skill nobody's task ever matches, or one so long its one useful paragraph is lost
   in filler, is worse than no skill — it still costs its description's tokens every session for
   zero benefit, or it costs its full body every time it fires without the reader finding the
   actually load-bearing line.
4. Verify the facts against the current repo before writing them down — a command, a file path, an
   incident detail. A skill that's fluently wrong is worse than a skill that's honestly silent.
5. If the new material is a hard rule with no legitimate exception rather than a sometimes-needed
   procedure, it may belong in `../CLAUDE.md` instead — see the test above.
