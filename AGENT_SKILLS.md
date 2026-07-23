# How ICP skills are managed in generated projects

Every project scaffolded from these templates ships an `AGENTS.md` (and a
`CLAUDE.md` that points to it) with a **self-configuring skills section**. This
document explains what that section does, the choices it offers, and why it is
written the way it is — so a future reader of a project's `AGENTS.md` can tell
where the content came from and why.

For the broader, tool-agnostic picture of how agents consume ICP skills, see the
developer-docs guide: <https://docs.internetcomputer.org/guides/ai-coding-agents>.

## What ICP skills are

ICP skills are tested, frequently-updated instruction files (correct dependency
versions, compiler flags, API signatures, and documented pitfalls) published at
<https://skills.internetcomputer.org>. ICP evolves quickly, so pre-training
knowledge is outdated by definition. The rule agents follow is: **when a skill
and general knowledge disagree, the skill is correct.**

## The self-configuring `AGENTS.md`

The skills section of a fresh `AGENTS.md` is delimited by markers:

```
<!-- ic-skills:managed:start -->
<!-- state: onboarding-needed -->
...
<!-- ic-skills:managed:end -->
```

While `state:` is `onboarding-needed`, the first agent session runs a one-time
setup: it asks you to choose how this project should use skills, performs the
setup, and then **rewrites everything between the two markers** with a small,
mode-specific block — deleting the onboarding instructions. From then on every
session reads that terse block and behaves accordingly, without asking again.
Only the text between the markers is ever rewritten; anything you add elsewhere
in `AGENTS.md` is left untouched.

## The three modes

| Mode | Who it's for | Preconditions | How skills are obtained |
|------|--------------|---------------|-------------------------|
| **autosync** | Claude Code users who want zero-maintenance, always-current skills | bash, `curl`, `jq`, Claude Code | A `SessionStart` hook (`.claude/sync-ic-skills.sh`) mirrors the latest skills into `.claude/skills/` every session |
| **pinned** | Any agent/harness; teams wanting reproducible, version-locked skills | Node / `npx` | `npx skills add dfinity/icskills` records a `skills-lock.json`; skills restored/refreshed via the CLI |
| **on-demand** | Anyone; zero install; the safe default | Network access | Skills fetched fresh from the registry on demand each session |

`on-demand` is the **recommended default** and the fallback (see below) because it
installs nothing, works with any agent, and is fully reversible.

### Pinned update policy

When `pinned` is chosen, you also pick how new sessions keep skills current:

- **auto** — each session runs `npx skills update` silently.
- **confirm** — each session asks you first, then runs `npx skills update`.
- **off** — never auto-updates; you update manually when you want.

## The two fallbacks (and why they differ)

If skills aren't present when a session needs them, the recovery path depends on
the mode — because each mode stores skills differently:

- **autosync → fetch from the registry.** There is no lock file in this mode; the
  hook is the source of truth. If the hook hasn't run yet (or `jq` is missing),
  the agent fetches skills on demand from
  <https://skills.internetcomputer.org/llms.txt>.
- **pinned → `npx skills experimental_install`.** This mode commits a
  `skills-lock.json`, so the exact locked versions are restored deterministically
  from it.

## What's committed vs. git-ignored

Skill files are treated as a **managed cache**, not source. The generated
`.gitignore` ignores:

```
.claude/skills/
.agents/skills/
```

Committed instead is the small metadata that makes the cache reproducible:

- **pinned** commits `skills-lock.json` (repo root). Teammates restore the exact
  versions with `npx skills experimental_install`.
- **autosync** commits the hook and script (`.claude/settings.json`,
  `.claude/sync-ic-skills.sh`) — *not* the skills themselves, which the hook
  repopulates each session.

This avoids committing frequently-changing generated files (no surprise diffs, no
cross-platform symlink issues from `npx skills`), while keeping every mode fully
recoverable.

## Non-interactive sessions, and "just start"

The onboarding never blocks your actual work. If a session can't ask you
(non-interactive/CI) or you'd rather just start coding, the agent uses `on-demand`
for that session only and **does not modify `AGENTS.md`** — leaving the choice
open so a later interactive session can still make it. A choice is persisted only
when you actively make one.

## Changing your mind later

To switch modes, reset the marker to re-trigger onboarding: replace the block
between `ic-skills:managed:start` / `end` with a single line:

```
<!-- state: onboarding-needed -->
```

The next session will walk you through the choice again. (You can also just edit
the configured block by hand if you know the target mode.)

## A note on reliability

The self-rewrite is deliberately simple (clear markers, copy-one-block-verbatim)
so a wide range of agents can perform it. It has been validated across simulated
Claude Code / Cursor / Aider sessions. A less capable model could still mis-edit
the block; because `on-demand` is side-effect-free and every mode is recoverable,
the failure modes are benign (an extra prompt, or one session on general
knowledge) rather than destructive.
