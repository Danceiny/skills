---
name: git-declutter
description: Lossless cleanup of git branches and worktrees — archive before delete, verify every commit stays reachable, then remove. Use when the user wants to clean up / prune / tidy / declutter branches or worktrees, mentions branch sprawl, stale or old remote branches, too many branches, worktree sprawl, git eating disk space, consolidating branches into one archive without losing commits (清理分支, 断舍离), or asks which branches can be safely deleted.
---

# Git Declutter

**Deletion is cheap. Losing commits is not.** On a squash-merge repo, "the PR merged" does **not** mean the branch's commits live on the base branch — the squash rewrote them into one new commit, and the originals become orphans the moment you delete the branch. Reflog saves you for ~90 days, then the garbage collector doesn't. So this skill never trusts merge status alone, never deletes on a hunch, and makes every removal reversible *before* it happens.

The move that makes all of it safe: **archive first** — one merge-style commit that adopts every to-be-deleted branch tip as a parent. Push it, verify every tip is reachable from it, and only then delete. After that, recovery is `git branch <name> <sha>` forever.

## Phase 0 — Refresh ground truth

Agents, IDEs, CI and teammates mutate the repo *while you work*. Every fact in this skill has a shelf life of minutes.

```bash
git fetch --prune origin
git fetch origin master:master   # fast-forward the base if you're not on it
```

Decide from `git ls-remote origin` and `gh pr list --state all`, never from stale remote-tracking refs — and re-check immediately before each destructive step. If a branch vanished mid-run, that's a concurrent actor, not an error; treat "remote ref does not exist" as success-shaped and move on.

## Phase 1 — Inventory

One picture, gathered fresh: branches with dates and upstream status, worktrees with dirty state, PR states, disk usage.

```bash
git for-each-ref --format='%(refname:short)%09%(committerdate:short)%09%(objectname:short)%09%(upstream:track)' refs/heads
git for-each-ref --format='%(refname:short)%09%(committerdate:unix)%09%(objectname:short)' refs/remotes/origin
git worktree list
gh pr list --state all --json number,state,headRefName,mergedAt --limit 2000  # not just --state open
df -h . ; du -sh .git
```

`--state all` matters: the *merged* state of a branch's PR is the fastest authoritative landed signal, and `--limit` above the PR count matters too — the default truncates and quietly lies about old branches.

## Phase 2 — Triage: the evidence ladder

For every branch, answer one question: **if I delete this, does any commit become unreachable?** Run each branch down the ladder and stop at the first hit:

1. **Protected** — current branch, `master`/`main`, open PR, release pin, existing `archive/*`. Keep, no discussion.
2. **Ancestor of base** — `git merge-base --is-ancestor <branch> master && echo safe`. Fully merged in the true sense; deleting loses nothing.
3. **PR merged** — the work landed; on a squash repo the *commits* are still orphans (see the box below). Safe to delete the ref if you don't need the originals; consolidate first (Phase 4) if you do.
4. **Tree-identical** — `git diff master...<branch> -- . ':(exclude)hotel-fe'` is empty (exclude submodules by noise, not by meaning). The branch adds nothing over the base.
5. **Unique and unlanded** — keep it, or salvage-then-delete. Never delete on vibes.

> ⚠️ **The squash gotcha.** `git branch --merged master` reports squash-merged branches as *not* merged, forever, because the original commits aren't on master. `--merged` is a valid fast path (on the list = genuinely merged) but never authoritative for a *missing* entry. A merged PR wins over `--merged`; when in doubt compare trees, not commit ancestry — the three-dot diff above is `git diff master...branch`, which shows what the branch changed since the merge-base, not what master did.

## Phase 3 — Salvage uncommitted work

Worktree directories are the only place work lives *outside* git's object store. Before removing any worktree:

```bash
dirty=$(git -C <worktree> status --porcelain | grep -vE '<tool-noise-patterns>')
[ -n "$dirty" ] && git -C <worktree> diff HEAD > ".salvage/<name>.patch"
```

Rules that come from incidents:

- **A patch in `/tmp` is not a salvage.** It must survive a reboot: commit the patches into an `archive/salvage-<date>` branch and push it to the remote. Verify with `git ls-remote` before you report anything done.
- **Secret-scan the patches before pushing** (`grep -iE '(api_key|secret|password|...)'`). If the repo's own pre-commit gate blocks a salvage commit, the gate is right — keep that patch local-only and say so in the report.
- **Untracked files aren't automatically unique** — most are tool noise or copies of landed work. Check `git cat-file -e master:<path>` before treating one as precious.

## Phase 4 — Consolidate: the lossless delete

The centerpiece. One commit, tree = base, parents = base + every selected branch tip. Every commit on every selected branch stays reachable; git never GCs what's reachable.

```bash
# msg file = the recovery index: branch → tip → last-commit-date
git commit-tree "$(git rev-parse origin/master^{tree})" \
  -p origin/master -p <tip1> -p <tip2> … < archive-msg.txt
git push origin <new-sha>:refs/heads/archive/inactive-$(date +%F)
```

**Verify before deleting — all of them, counted:**

```bash
n=$(grep -c . selected-branches.tsv)          # grep -c ., NOT wc -l — see pitfalls
ok=0
while IFS=$'\t' read -r name tip; do
  git merge-base --is-ancestor "$tip" origin/archive/inactive-… && ok=$((ok+1))
done < selected-branches.tsv
[ "$ok" -eq "$n" ] || echo "ABORT: $ok/$n reachable"
```

Only when `$ok == $n` do you delete the originals. Recovery, any time later:

```bash
git branch <name> <tip-sha> && git push origin <name>
```

Or run `scripts/consolidate-branches.sh` from this skill — it does plan → archive → verify → delete, dry-run by default, `--apply` to execute.

## Phase 5 — Remove worktrees through three gates

A worktree can look dead and still be someone's (some*agent*'s) active workspace. Three gates; any hit means keep and report:

1. **Process gate** — no live process with the path in its cwd or argv (`ps aux | grep -F <path>`). Read-only watchers (log viewers) don't count.
2. **Session gate** — search agent session transcripts for the path, **excluding your own session**: your own inventory output poisons the signal, flagging every worktree as "active 0h ago". And a transcript *mentioning* a path isn't activity — look for tool calls that actually run there (`git -C <path>`, absolute-path writes), not for `git worktree list` echoes.
3. **Changes gate** — dirty worktree ⇒ Phase 3 salvage already done.

Then `git worktree remove <path>` (clean) or `--force` (only post-salvage), and `git worktree prune` at the end. File mtime is weak evidence — re-checkouts and tool caches refresh dotfiles (`.air.toml`, caches) without anyone working there.

## Phase 6 — Delete and reclaim

- **Local branches**: `git branch -d` is your safety net — it refuses unmerged branches. Use `-D` only when Phase 2 evidence exists (merged PR, empty tree-diff), and be able to name it.
- **Remote branches**: `git push origin --delete <branch>` takes **bare names** — `origin/fix/foo` asks the remote to delete a branch literally named `origin/fix/foo` and fails with a confusing "remote ref does not exist". Confirm the scope once with the user (it's outward-facing), then batch.
- **Reclaim**: `git worktree prune`, then `git gc --prune=now` — but *only after* every archive branch is pushed and verified, because `--prune=now` also shortens the reflog safety net you'd otherwise fall back on.

## Phase 7 — Report (the proof of safety)

Never say "cleaned up" without this four-bucket breakdown — the breakdown *is* the evidence that nothing was lost:

1. **Kept** — and why (active, open PR, release pin).
2. **Salvaged then removed** — with the *remote* location of the salvage (archive branch name), never a local path.
3. **Removed as merged** — with the evidence per branch (PR #N, ancestor check, empty tree-diff).
4. **Final state** — branch/worktree counts, disk before → after, and any leftovers honestly listed.

## Pitfalls

Each of these bit in a real cleanup; none gets to bite twice:

- **Self-poisoning activity checks** — your own `git worktree list` output lands in your session transcript, so grepping transcripts for worktree paths flags everything as active. Exclude your own session ID; inspect actual tool calls, not mentions.
- **`while read` drops a final line without a trailing newline** — a count off by one silently skips the last branch's verification. `grep -c .` counts real lines; compare against it.
- **zsh doesn't word-split unquoted `$ARGS`** — `git commit-tree $tree $PARGS` becomes one giant argument. Use an array or `eval`.
- **`*` doesn't match dotfiles** — `.salvage/*.patch` misses `.cursor_xxx.patch`. Glob `.[^.]*` too.
- **Concurrent actors** — CI merges PRs, other agents delete branches, tools clean their own worktrees mid-run. Re-pull ground truth before each destructive batch; verify with `ls-remote`, not tracking refs.
