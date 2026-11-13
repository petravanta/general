#!/usr/bin/env bash
# Keeps a full local mirror (every branch and tag) of every petravanta GitHub repo. See STANDARDS.md, "Backups".
# Run it on your own machine with the GitHub CLI signed in (gh auth login) and git on the PATH.
#   ./github/backup-repos.sh                        # mirror new repos, refresh existing ones
#   ./github/backup-repos.sh --dry-run              # show what it would do, change nothing
#   ./github/backup-repos.sh --bundle /g/backups    # also write one <repo>.bundle per repo there (the second copy)
#   ./github/backup-repos.sh --verify               # also check each mirror is whole (git fsck)
#   ./github/backup-repos.sh general voicetrainer   # only the repos you name
# Mirrors go to --dest or $BACKUP_DIR (default /f/Dev/petravantaapps/_backups, which is F:\Dev\petravantaapps\_backups in Git Bash).
#
# Gentle on GitHub: one API call lists the repos; everything else is plain git fetch, one repo at a time,
# and a repo with nothing new downloads nothing.
set -euo pipefail
owner=petravanta
dest=${BACKUP_DIR:-/f/Dev/petravantaapps/_backups}
dry=0; verify=0; bundle_dir=""; only=()
while [ $# -gt 0 ]; do
  case "$1" in
    -n|--dry-run) dry=1 ;;
    --verify) verify=1 ;;
    --bundle) bundle_dir=$2; shift ;;
    --dest) dest=$2; shift ;;
    -h|--help) sed -n '2,11p' "$0"; exit 0 ;;
    *) only+=("$1") ;;
  esac
  shift
done
run() { if [ "$dry" = 1 ]; then echo "  would run: $*"; else "$@"; fi; }
wanted() { [ ${#only[@]} -eq 0 ] && return 0; local o; for o in "${only[@]}"; do [ "$o" = "$1" ] && return 0; done; return 1; }

# The one API call: a line per repo, "name<TAB>details as JSON". The details are kept as repos.json.
lines=$(gh repo list "$owner" --limit 500 \
  --json name,description,visibility,homepageUrl,defaultBranchRef,isArchived,isFork,pushedAt \
  --jq '.[] | "\(.name)\t\(tojson)"')
[ -n "$lines" ] || { echo "No repos listed for $owner. Is gh signed in?" >&2; exit 1; }

run mkdir -p "$dest"
if [ "$dry" = 0 ]; then printf '%s\n' "$lines" | cut -f2- | paste -sd, - | sed 's/^/[/; s/$/]/' > "$dest/repos.json"; fi
[ -n "$bundle_dir" ] && run mkdir -p "$bundle_dir"

failed=0
while IFS=$'\t' read -r name _; do
  wanted "$name" || continue
  mirror="$dest/$name.git"
  if [ -d "$mirror" ]; then
    echo "refresh $name"
    run git -C "$mirror" remote update --prune || { echo "  FAILED $name" >&2; failed=1; continue; }
  else
    echo "mirror  $name (new)"
    run git clone --quiet --mirror "https://github.com/$owner/$name.git" "$mirror" || { echo "  FAILED $name" >&2; failed=1; continue; }
  fi
  if [ "$verify" = 1 ]; then run git -C "$mirror" fsck --connectivity-only --no-progress || { echo "  BROKEN $name" >&2; failed=1; }; fi
  if [ -n "$bundle_dir" ]; then
    # An empty repo has nothing to bundle.
    if [ "$dry" = 1 ] || [ -n "$(git -C "$mirror" for-each-ref --count=1)" ]; then
      run git -C "$mirror" bundle create "$bundle_dir/$name.bundle" --all
    fi
  fi
done <<< "$lines"

if [ "$dry" = 1 ]; then echo "Dry run: nothing changed."; exit $failed; fi
[ "$failed" = 0 ] && echo "Backups up to date in $dest" || { echo "Some repos failed, see above." >&2; exit 1; }
