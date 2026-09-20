#!/usr/bin/env bash
# consolidate-branches.sh — losslessly consolidate stale remote branches into one archive ref.
#
# Creates a single merge-style commit (tree = base branch, parents = base + every
# selected branch tip), pushes it as an archive ref, verifies that every tip is
# reachable from it, and only then deletes the original branches. Recovery is
# always: git branch <name> <tip-sha> && git push <remote> <name>
#
# Dry-run by default. --apply executes.
#
# Usage:
#   consolidate-branches.sh [--remote origin] [--base master] [--days 7] \
#     [--archive NAME] [--keep GLOB]... [--include BRANCH]... [--apply]
#
#   --remote    remote to operate on                     (default: origin)
#   --base      base branch on that remote               (default: master)
#   --days      inactivity cutoff: last commit older than N days (default: 7)
#   --archive   name of the archive ref to create        (default: archive/inactive-YYYY-MM-DD)
#   --keep      extra glob (fnmatch against bare branch name) to always keep. Can repeat.
#               Always kept regardless: HEAD, the base branch, archive/*, release/*,
#               */release-*, and open-PR heads (when gh is available).
#   --include   force-include a branch regardless of age or --keep. Can repeat.
#   --apply     actually push the archive and delete branches. Without it: plan only.
set -euo pipefail

REMOTE=origin
BASE=master
DAYS=7
ARCHIVE=""
APPLY=0
declare -a KEEPS=() INCLUDES=()
while [ $# -gt 0 ]; do
  case "$1" in
    --remote)  REMOTE="$2"; shift 2 ;;
    --base)    BASE="$2"; shift 2 ;;
    --days)    DAYS="$2"; shift 2 ;;
    --archive) ARCHIVE="$2"; shift 2 ;;
    --keep)    KEEPS+=("$2"); shift 2 ;;
    --include) INCLUDES+=("$2"); shift 2 ;;
    --apply)   APPLY=1; shift ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done
[ -n "$ARCHIVE" ] || ARCHIVE="archive/inactive-$(date +%F)"

cd "$(git rev-parse --show-toplevel)"
git fetch --prune "$REMOTE" >/dev/null 2>&1 || git fetch "$REMOTE" >/dev/null

BASE_REF="refs/remotes/$REMOTE/$BASE"
git rev-parse --verify --quiet "$BASE_REF" >/dev/null || { echo "base ref $BASE_REF not found" >&2; exit 2; }

# ---- selection ------------------------------------------------------------
CUTOFF=$(( $(date +%s) - DAYS * 86400 ))
declare -a OPEN_PR_HEADS=()
if command -v gh >/dev/null 2>&1; then
  OPEN_PR_HEADS=( $(gh pr list --state open --json headRefName --limit 300 \
    2>/dev/null | grep -o '"headRefName":"[^"]*"' | cut -d'"' -f4) ) || true
fi

keep_protected() {  # bare branch name -> 0 if protected
  case "$1" in
    "$BASE"|archive/*|release/*|*/release-*) return 0 ;;
  esac
  local k
  for k in "${KEEPS[@]+"${KEEPS[@]}"}"; do
    # shellcheck disable=SC2254
    case "$1" in $k) return 0 ;; esac
  done
  local h
  for h in "${OPEN_PR_HEADS[@]+"${OPEN_PR_HEADS[@]}"}"; do
    [ "$1" = "$h" ] && return 0
  done
  return 1
}

declare -a NAMES=() TIPS=()
seen=""   # portable tip dedupe (macOS ships bash 3.2: no associative arrays)
while IFS=$'\t' read -r ref ts tip; do
  [ -n "${ref:-}" ] || continue
  bare="${ref#refs/remotes/$REMOTE/}"
  [ "$bare" = "HEAD" ] && continue
  [ "$bare" = "$BASE" ] && continue
  forced=0
  for inc in "${INCLUDES[@]+"${INCLUDES[@]}"}"; do [ "$bare" = "$inc" ] && forced=1; done
  if [ "$forced" -eq 0 ]; then
    keep_protected "$bare" && continue
    [ "${ts:-0}" -ge "$CUTOFF" ] && continue   # active inside the window
  fi
  case " $seen " in *" $tip "*) continue ;; esac  # dedupe identical tips
  seen="$seen $tip"
  NAMES+=("$bare") TIPS+=("$tip")
done < <(git for-each-ref --format='%(refname)%09%(committerdate:unix)%09%(objectname)' "refs/remotes/$REMOTE")

N=${#NAMES[@]}
if [ "$N" -eq 0 ]; then echo "nothing to consolidate (cutoff: ${DAYS}d)"; exit 0; fi

# ---- plan -----------------------------------------------------------------
msg="$(mktemp)"; trap 'rm -f "$msg"' EXIT
{
  echo "archive: consolidate $N remote branches inactive since >${DAYS}d ($(date +%F))"
  echo
  echo "Merge-style archival commit: tree=${BASE}, all branch tips attached as parents."
  echo "Every commit from the listed branches stays reachable from this ref."
  echo "Recover any branch with: git branch <name> <tip-sha>"
  echo
  printf '%s\t%s\t%s\n' branch tip last-commit
  for i in $(seq 0 $((N-1))); do
    printf '%s\t%s\t%s\n' "${NAMES[$i]}" "${TIPS[$i]}" "$(git show -s --format=%cs "${TIPS[$i]}")"
  done
} > "$msg"
cat "$msg"

if [ "$APPLY" -eq 0 ]; then
  echo
  echo "DRY RUN — nothing was changed. Re-run with --apply to archive and delete."
  exit 0
fi

# ---- archive commit (octopus) ---------------------------------------------
if git ls-remote --heads "$REMOTE" "$ARCHIVE" | grep -q .; then
  echo "archive ref $ARCHIVE already exists on $REMOTE — pass a fresh --archive name" >&2
  exit 1
fi
PARENTS=(-p "$(git rev-parse "$BASE_REF")")
for tip in "${TIPS[@]}"; do PARENTS+=(-p "$tip"); done
tree="$(git rev-parse "$BASE_REF^{tree}")"
new="$(git commit-tree "$tree" "${PARENTS[@]}" < "$msg")"
echo "archive commit: $new"
git push "$REMOTE" "$new:refs/heads/$ARCHIVE"

# ---- verify reachability BEFORE deleting ----------------------------------
BASE_TIP_COUNT=$(git rev-list --parents -n1 "$new" | wc -w | awk '{print $1-1}')
ok=0
for tip in "${TIPS[@]}"; do
  git merge-base --is-ancestor "$tip" "$new" && ok=$((ok+1))
done
echo "tips reachable: $ok/$N (explicit parents: $BASE_TIP_COUNT)"
if [ "$ok" -ne "$N" ]; then
  echo "ABORT: not every tip is reachable from $ARCHIVE — originals left untouched." >&2
  exit 1
fi

# ---- delete originals (bare names; already-gone is fine) ------------------
declare -a DELARGS=()
for i in $(seq 0 $((N-1))); do DELARGS+=("${NAMES[$i]}"); done
git push "$REMOTE" --delete "${DELARGS[@]}" 2>&1 | grep -E 'deleted|error|remote ref' || true

echo
echo "done. archive ref: $ARCHIVE ($new). recovery index is in that commit's message:"
echo "  git fetch $REMOTE $ARCHIVE && git log -1 $new"
