#!/usr/bin/env bash
# Keeps a full local mirror (every branch and tag) of every petravanta GitHub repo. See STANDARDS.md, "Backups".
# Run it on your own machine with the GitHub CLI signed in (gh auth login) and git on the PATH.
#   ./github/backup-repos.sh                        # mirror new repos, refresh existing ones
#   ./github/backup-repos.sh --dry-run              # show what it would do, change nothing
#   ./github/backup-repos.sh --bundle /g/backups    # also write one <repo>.bundle per repo there (the second copy)
#   ./github/backup-repos.sh --verify               # also check each mirror is whole (git fsck)
#   ./github/backup-repos.sh general voicetrainer   # only the repos you name
#   ./github/backup-repos.sh --delay 5-15           # wait a random 5-15 s between repos (sync-all.sh does this)
#   ./github/backup-repos.sh --progress FILE        # skip repos listed in FILE, add each one done (lets a cut-short run resume)
# Mirrors go to --dest or $BACKUP_DIR (default /f/Dev/petravantaapps/_backups, which is F:\Dev\petravantaapps\_backups in Git Bash).
#
# Gentle on GitHub: one API call lists the repos; everything else is plain git fetch, one repo at a time,
# and a repo with nothing new downloads nothing. If GitHub answers 403/429 or asks us to slow down, it stops at once
# without retrying and exits with 2.
set -euo pipefail
owner=petravanta
dest=${BACKUP_DIR:-/f/Dev/petravantaapps/_backups}
dry=0; verify=0; bundle_dir=""; only=(); delay=0-0; progress=""
while [ $# -gt 0 ]; do
  case "$1" in
    -n|--dry-run) dry=1 ;;
    --verify) verify=1 ;;
    --bundle) bundle_dir=$2; shift ;;
    --dest) dest=$2; shift ;;
    --delay) delay=$2; shift ;;
    --progress) progress=$2; shift ;;
    -h|--help) sed -n '2,15p' "$0"; exit 0 ;;
    *) only+=("$1") ;;
  esac
  shift
done
run() { if [ "$dry" = 1 ]; then echo "  would run: $*"; else "$@"; fi; }
limit_re='HTTP 403|HTTP 429|403 Forbidden|429 Too Many|[Rr]ate limit|abuse|secondary rate|[Tt]oo many requests|[Ss]low down'
fetched=0
gh_git() {  # a git command that talks to GitHub: pause between repos, stop dead on a limit
  local lo=${delay%-*} hi=${delay#*-} out rc
  if [ "$dry" = 1 ]; then echo "  would run: git $*"; return 0; fi
  [ "$fetched" -gt 0 ] && [ "$hi" -gt 0 ] && sleep $(( lo + RANDOM % (hi - lo + 1) ))
  fetched=$((fetched + 1))
  out=$(git "$@" 2>&1 </dev/null); rc=$?
  [ -n "$out" ] && printf '%s\n' "$out"
  if [ "$rc" != 0 ] && printf '%s' "$out" | grep -Eq "$limit_re"; then
    echo "STOPPED: GitHub answered with a limit or a refusal. Not retrying; try again in a few hours." >&2; exit 2
  fi
  return "$rc"
}
wanted() { [ ${#only[@]} -eq 0 ] && return 0; local o; for o in "${only[@]}"; do [ "$o" = "$1" ] && return 0; done; return 1; }

# The one API call: a line per repo, "name<TAB>details as JSON". The details are kept as repos.json.
lines=$(gh repo list "$owner" --limit 500 \
  --json name,description,visibility,homepageUrl,defaultBranchRef,isArchived,isFork,pushedAt \
  --jq '.[] | "\(.name)\t\(tojson)"' 2>"${TMPDIR:-/tmp}/backup-repos.err") || true
if [ -z "$lines" ]; then
  cat "${TMPDIR:-/tmp}/backup-repos.err" >&2
  grep -Eq "$limit_re" "${TMPDIR:-/tmp}/backup-repos.err" && { echo "STOPPED: GitHub answered with a limit. Not retrying." >&2; exit 2; }
  echo "No repos listed for $owner. Is gh signed in?" >&2; exit 1
fi

run mkdir -p "$dest"
if [ "$dry" = 0 ]; then printf '%s\n' "$lines" | cut -f2- | paste -sd, - | sed 's/^/[/; s/$/]/' > "$dest/repos.json"; fi
[ -n "$bundle_dir" ] && run mkdir -p "$bundle_dir"

failed=0
while IFS=$'\t' read -r name _; do
  wanted "$name" || continue
  if [ -n "$progress" ] && [ -f "$progress" ] && grep -qxF "$name" "$progress"; then echo "skip    $name (refreshed earlier, resuming)"; continue; fi
  mirror="$dest/$name.git"
  if [ -d "$mirror" ]; then
    echo "refresh $name"
    gh_git -C "$mirror" remote update --prune || { echo "  FAILED $name" >&2; failed=1; continue; }
  else
    echo "mirror  $name (new)"
    gh_git clone --quiet --mirror "https://github.com/$owner/$name.git" "$mirror" || { echo "  FAILED $name" >&2; failed=1; continue; }
  fi
  if [ "$verify" = 1 ]; then run git -C "$mirror" fsck --connectivity-only --no-progress || { echo "  BROKEN $name" >&2; failed=1; }; fi
  if [ -n "$bundle_dir" ]; then
    # An empty repo has nothing to bundle.
    if [ "$dry" = 1 ] || [ -n "$(git -C "$mirror" for-each-ref --count=1)" ]; then
      run git -C "$mirror" bundle create "$bundle_dir/$name.bundle" --all
    fi
  fi
  if [ -n "$progress" ] && [ "$dry" = 0 ]; then echo "$name" >> "$progress"; fi
done <<< "$lines"

if [ "$dry" = 1 ]; then echo "Dry run: nothing changed."; exit $failed; fi
[ "$failed" = 0 ] && echo "Backups up to date in $dest" || { echo "Some repos failed, see above." >&2; exit 1; }
