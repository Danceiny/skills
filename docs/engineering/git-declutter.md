Quickstart:

```bash
npx skills add danceiny/skills --skill=git-declutter
```

```bash
npx skills update git-declutter
```

[Source](https://github.com/Danceiny/skills/tree/main/skills/engineering/git-declutter)

## What it does

Cleans up git branch and worktree sprawl without losing a single commit. It triages every branch on an evidence ladder — ancestor-of-base, merged PR, tree-identical, unique — salvages any uncommitted work from worktrees into a remote archive branch, then consolidates everything you're about to delete into one merge-style archive commit before the actual removal. The defining constraint: on a squash-merge repo, "the PR merged" does not mean the commits survive — the squash rewrote them — so nothing is ever deleted until every to-be-deleted branch tip is verified reachable from a pushed archive ref.

## When to reach for it

Type `/git-declutter`, or the agent reaches for it automatically when a task fits — the moment branch sprawl, stale remote branches, worktree litter, or git eating your disk shows up.

Reach for it when `git branch` stops fitting on one screen, when a cleanup session (or three coding agents) has left dozens of dead worktrees behind, or when you want old remote branches gone *without* betting that nobody ever needs those commits again. For untangling an in-progress merge instead, use [resolving-merge-conflicts](./resolving-merge-conflicts.md).

## Prerequisites

A git repo, a remote you can push to (the archive branch is the safety net — it has to live somewhere durable), and `gh` authenticated if you want open-PR branches auto-protected.

## The archive-first loop

The skill runs a **lossless** loop: inventory → triage → salvage → consolidate → remove → report.

- **Triage** never trusts `git branch --merged` on a squash-merge repo — it lies in the dangerous direction, reporting squash-merged branches as unmerged forever. The ladder ends in tree comparison: `git diff master...branch` empty means the branch adds nothing.
- **Consolidate** is the signature move: one commit whose tree is the base branch and whose parents are every selected branch tip. Pushed, that single ref keeps every commit reachable — and recovery is `git branch <name> <sha>` forever, using the branch→tip table written into the commit message.
- **Remove** only fires after a counted reachability check (`2/2`, `48/48` — a count that doesn't match aborts the deletion).

## Worktree removal runs three gates

Live process with the path open, recent agent-session activity in that worktree (excluding your own session — your inventory output poisons the check), and no unsalvaged changes. Any gate hits, the worktree stays and appears in the report with a reason.

The bundled `scripts/consolidate-branches.sh` automates the remote half — dry-run by default, `--apply` to execute, protects `archive/*`, `release/*`, `*/release-*` and open-PR heads.

## It's working if

- The report arrives in four buckets: kept (why), salvaged (with the *remote* archive location), removed-as-merged (with the evidence per branch), and final counts plus disk freed.
- Before any branch disappears, you see an archive ref pushed and a reachability count that matches the plan.
- You can restore any deleted branch weeks later from the table in the archive commit's message.

## Where it fits

Periodic **maintenance** — the repo-hygiene sibling of [improve-codebase-architecture](./improve-codebase-architecture.md) (which improves the code; this reclaims the space around it), typically run after a heavy multi-agent stretch or before a release. The full map of skills lives in [ask-skills](./ask-skills.md).
