# Danceiny's Skills

[![skills.sh](https://skills.sh/b/danceiny/skills)](https://skills.sh/danceiny/skills)

Agent skills I use every day to do real engineering — not vibe coding. A living set, iterated continuously: born as a fork of [mattpocock/skills](https://github.com/mattpocock/skills) (MIT, huge thanks for the foundation), now rebranded and extended with my own.

The philosophy survives the rebrand: **small, composable, hackable** skills that work with any model. No process framework owns you; each skill does one thing, states its contract, and gets out of the way. Fork it, strip it, extend it — that's the point.

## Installation

Two ways in, two philosophies — pick one, not both (installing both leaves you with every skill twice).

**Claude Code — the plugin** (managed, read-only bundle; reinstall to update):

```bash
claude plugin marketplace add danceiny/skills
```

```
/plugin install danceiny-skills@danceiny
```

**Any agent (Codex, Cursor, …) — skills.sh** (editable files you own):

```bash
npx skills@latest add danceiny/skills
```

Then, once per repo, run `/setup-skills` — it asks which issue tracker to use (GitHub, Linear, or local files), which triage labels you apply, and where docs should live. After that you're ready to go.

## The skills

### Engineering — user-invoked

| Skill | What it does |
|---|---|
| [`/ask-skills`](./skills/engineering/ask-skills/SKILL.md) | Router over the whole set: which skill or flow fits your situation. |
| [`/grill-with-docs`](./skills/engineering/grill-with-docs/SKILL.md) | Grilling session that also builds your domain model inline (`CONTEXT.md` + ADRs). |
| [`/triage`](./skills/engineering/triage/SKILL.md) | Move incoming issues through a state machine of triage roles. |
| [`/improve-codebase-architecture`](./skills/engineering/improve-codebase-architecture/SKILL.md) | Scan for deepening opportunities, grill through the one you pick. |
| [`/setup-skills`](./skills/engineering/setup-skills/SKILL.md) | One-time per-repo configuration: tracker, labels, doc layout. |
| [`/to-spec`](./skills/engineering/to-spec/SKILL.md) | Turn the current conversation into a spec on the issue tracker. |
| [`/to-tickets`](./skills/engineering/to-tickets/SKILL.md) | Break a plan into tracer-bullet tickets with blocking edges. |
| [`/implement`](./skills/engineering/implement/SKILL.md) | Build a spec or ticket set, driving `/tdd` at pre-agreed seams, closing with `/code-review`. |
| [`/wayfinder`](./skills/engineering/wayfinder/SKILL.md) | Chart a too-big-for-one-session effort as decision tickets; resolve until the way is clear. |

### Engineering — model-invoked

The agent reaches for these when the task fits; you can invoke them too.

| Skill | What it does |
|---|---|
| [`/prototype`](./skills/engineering/prototype/SKILL.md) | Throwaway prototype to answer a design question. |
| [`/diagnosing-bugs`](./skills/engineering/diagnosing-bugs/SKILL.md) | Diagnosis loop for hard bugs: tight feedback loop first, theorise never. |
| [`/research`](./skills/engineering/research/SKILL.md) | Investigate against primary sources, capture cited findings in the repo. |
| [`/tdd`](./skills/engineering/tdd/SKILL.md) | Red-green-refactor, one vertical slice at a time. |
| [`/domain-modeling`](./skills/engineering/domain-modeling/SKILL.md) | Sharpen the project's domain language, record decisions as ADRs. |
| [`/codebase-design`](./skills/engineering/codebase-design/SKILL.md) | Deep-module vocabulary: small interfaces at clean seams. |
| [`/code-review`](./skills/engineering/code-review/SKILL.md) | Two-axis review (Standards + Spec) of the diff since a fixed point. |
| [`/resolving-merge-conflicts`](./skills/engineering/resolving-merge-conflicts/SKILL.md) | Work an in-progress merge/rebase conflict by intent, never `--abort`. |
| [`/git-declutter`](./skills/engineering/git-declutter/SKILL.md) | **Lossless** branch/worktree cleanup: archive every to-be-deleted tip into one commit, verify reachability, then delete — nothing recoverable is ever lost. |
| [`/wizard`](./skills/engineering/wizard/SKILL.md) | Interactive bash wizard for steps only a human can perform. |

### Productivity

| Skill | What it does |
|---|---|
| [`/grill-me`](./skills/productivity/grill-me/SKILL.md) | Relentless interview about a plan until every branch resolves. |
| [`/grilling`](./skills/productivity/grilling/SKILL.md) | The interview primitive underneath `grill-me` / `grill-with-docs`. |
| [`/handoff`](./skills/productivity/handoff/SKILL.md) | Compact this conversation into a handoff another agent can continue. |
| [`/teach`](./skills/productivity/teach/SKILL.md) | Multi-session teaching workspace. |
| [`/to-questionnaire`](./skills/productivity/to-questionnaire/SKILL.md) | Turn an unanswerable-alone decision into a questionnaire for the one person who can. |
| [`/wait-what`](./skills/productivity/wait-what/SKILL.md) | Re-pitch a message that didn't land, with the context you were missing. |
| [`/writing-for-agents`](./skills/productivity/writing-for-agents/SKILL.md) | Writing docs agents actually reach: skills, AGENTS.md, pointer targets. |

Not every experiment ships: drafts live in `skills/in-progress/`, retired ones in `skills/deprecated/`.

## My additions

**[`/git-declutter`](./skills/engineering/git-declutter/SKILL.md)** — born from a real cleanup: 82 worktrees, 273 branches, a 94%-full disk, and a hard rule that no commit may be lost. On squash-merge repos "the PR merged" doesn't mean the commits survive, so the skill consolidates every to-be-deleted branch tip into one merge-style archive commit and verifies reachability before deleting anything. Any branch stays recoverable with `git branch <name> <sha>` forever. It ships a tested `consolidate-branches.sh` (dry-run by default).

## The main flow, in one breath

`/grill-with-docs` sharpens the idea → `/to-spec` freezes it → `/to-tickets` splits it into blocking-edge tickets → `/implement` builds each one via `/tdd` and closes with `/code-review`. On-ramps: `/triage` when requests pile up, `/diagnosing-bugs` when something's broken, `/wayfinder` when the effort is too foggy to plan. Lost? `/ask-skills`.

## Contributing & provenance

- This repo is independently iterated; upstream merges are taken deliberately, not automatically.
- Original skill set and structure: [Matt Pocock](https://github.com/mattpocock)'s [skills](https://github.com/mattpocock/skills), MIT. Read his [AI Hero](https://www.aihero.dev) work — it's where most of the thinking here comes from.
- License: [MIT](./LICENSE).
