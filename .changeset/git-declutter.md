---
"danceiny-skills": minor
---

New **`git-declutter`** skill: lossless cleanup of git branches and worktrees. Triage runs an evidence ladder (ancestor / merged PR / tree-identical / unique) that doesn't trust `--merged` on squash-merge repos; uncommitted worktree work is salvaged to a remote archive branch; every to-be-deleted remote branch tip is consolidated into one merge-style archive commit and verified reachable before anything is removed. Ships `scripts/consolidate-branches.sh` (dry-run by default, `--apply` to execute) which was tested end-to-end: selection, protection of `archive/*`/`release/*`/open-PR heads, counted reachability check, deletion, and branch recovery from the archive commit's message.
