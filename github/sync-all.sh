#!/usr/bin/env bash
# One command for every project: refresh the local backups, then check every clone for work that isn't on GitHub yet.
# See STANDARDS.md, "Syncing every project". Needs git and the GitHub CLI (gh auth login) on your own machine.
#   ./github/sync-all.sh                     # back up, then report (doesn't touch your files or branches)
#   ./github/sync-all.sh --push              # also push branches with commits GitHub doesn't have (at most 5)
#   ./github/sync-all.sh --push --open-prs   # ...and open pull requests for pushed branches without one (at most 2)
#   ./github/sync-all.sh --skip-backup       # report only, from what's already on disk; no network at all
# Options: --root DIR (where your clones live, default /f/Dev/petravantaapps = F:\Dev\petravantaapps)
#          --dest DIR (backups, default ROOT/_backups)  --max-pushes N (5)  --max-prs N (2)
#          --delay MIN-MAX (seconds between GitHub calls, 5-15)  --min-interval MINUTES (60)
#
# Gentle on GitHub on purpose: one repo at a time, a random pause before every GitHub call, small caps per run
# (the rest is listed under "Next run"), never a force push, and a full stop, without retrying, the moment
# GitHub answers 403, 429 or asks us to slow down. After that stop the next runs wait out a cool-down.
set -uo pipefail
owner=petravanta
root=${SYNC_ROOT:-/f/Dev/petravantaapps}
dest=""
push=0; open_prs=0; skip_backup=0; max_pushes=5; max_prs=2; delay=5-15; min_interval=60
while [ $# -gt 0 ]; do
  case "$1" in
    --push) push=1 ;;
    --open-prs) open_prs=1 ;;
    --skip-backup) skip_backup=1 ;;
    --root) root=$2; shift ;;
    --dest) dest=$2; shift ;;
    --max-pushes) max_pushes=$2; shift ;;
    --max-prs) max_prs=$2; shift ;;
    --delay) delay=$2; shift ;;
    --min-interval) min_interval=$2; shift ;;
    -h|--help) sed -n '2,15p' "$0"; exit 0 ;;
    *) echo "Unknown option: $1 (see --help)" >&2; exit 64 ;;
  esac
  shift
done
[ -n "$dest" ] || dest="$root/_backups"
[ "$open_prs" = 1 ] && [ "$push" = 0 ] && { echo "--open-prs goes with --push." >&2; exit 64; }
[ "$push" = 1 ] && [ "$skip_backup" = 1 ] && { echo "--push needs the backup step (it tells us what GitHub already has)." >&2; exit 64; }
here=$(cd "$(dirname "$0")" && pwd)
if [ "$open_prs" = 1 ] && ! command -v gh >/dev/null 2>&1; then
  echo "--open-prs needs the GitHub CLI: https://cli.github.com (Windows: winget install --id GitHub.cli), then gh auth login." >&2; exit 64
fi
state="$dest/sync-state.txt"
report="$dest/sync-report.txt"
now=$(date +%s)
delay_lo=${delay%-*}; delay_hi=${delay#*-}

# --- State: last run, cool-down after GitHub said stop ---------------------------------------------
last_run=0; blocked_until=0; strikes=0
if [ -f "$state" ]; then
  while IFS='=' read -r k v; do
    v=${v%$'\r'}
    case "$k" in last_run) last_run=$v ;; blocked_until) blocked_until=$v ;; strikes) strikes=$v ;; esac
  done < "$state"
fi
save_state() { mkdir -p "$dest"; printf 'last_run=%s\nblocked_until=%s\nstrikes=%s\n' "$last_run" "$blocked_until" "$strikes" > "$state"; }
when() { date -d "@$1" '+%a %H:%M' 2>/dev/null || date -r "$1" '+%a %H:%M'; }

if [ "$skip_backup" = 0 ]; then
  if [ "$now" -lt "$blocked_until" ]; then
    echo "GitHub asked us to slow down last time. Cooling off until $(when "$blocked_until"); nothing done." >&2
    echo "(--skip-backup still works: it reports from disk without touching GitHub.)" >&2
    exit 3
  fi
  if [ $((now - last_run)) -lt $((min_interval * 60)) ]; then
    echo "Last run was $(( (now - last_run) / 60 )) min ago; the minimum gap is $min_interval min. Try after $(when $((last_run + min_interval * 60))), or use --skip-backup." >&2
    exit 3
  fi
fi
# Only a run that finishes its backup counts as a run (last_run is written at the end). If one is cut short,
# a retry carries on: repos refreshed in the last 6 hours are listed in the progress file and skipped.
progress="$dest/sync-progress.txt"
[ -n "$(find "$progress" -mmin +360 2>/dev/null)" ] && rm -f "$progress"

# --- Talking to GitHub ------------------------------------------------------------------------------
limit_re='HTTP 403|HTTP 429|403 Forbidden|429 Too Many|[Rr]ate limit|abuse|secondary rate|[Tt]oo many requests|[Ss]low down'
flaky_re='Could not resolve host|timed out|Connection reset|early EOF|RPC failed|HTTP 50[234]|unable to access'
calls=0
pause() {  # a random wait before every GitHub call except the first
  if [ "$calls" -gt 0 ] && [ "$delay_hi" -gt 0 ]; then sleep $(( delay_lo + RANDOM % (delay_hi - delay_lo + 1) )); fi
  calls=$((calls + 1))
}
stop_for_github() {
  strikes=$((strikes + 1))
  local hours=$(( 6 * (1 << (strikes - 1)) )); [ "$hours" -gt 48 ] && hours=48
  blocked_until=$(( $(date +%s) + hours * 3600 )); save_state
  echo
  echo "STOPPED: GitHub answered with a limit or a refusal. Not retrying. Runs that use GitHub wait $hours h (until $(when "$blocked_until"))." >&2
  echo "Everything not yet done is still on disk; the next run picks it up." >&2
  exit 2
}
net() {  # run a git/gh command that talks to GitHub: stop dead on a limit, retry a flaky network twice
  local try out rc
  for try in 1 2 3; do
    pause
    out=$("$@" 2>&1 </dev/null); rc=$?
    [ -n "$out" ] && printf '%s\n' "$out" | sed 's/^/      /'
    [ "$rc" = 0 ] && return 0
    printf '%s' "$out" | grep -Eq "$limit_re" && stop_for_github
    printf '%s' "$out" | grep -Eq "$flaky_re" || return "$rc"
    [ "$try" = 3 ] && return "$rc"
    echo "      network hiccup; waiting $(( 30 << (try - 1) ))s before trying again"
    sleep $(( 30 << (try - 1) ))
  done
}

mkdir -p "$dest"
exec > >(tee "$report.tmp") 2>&1

# --- Step 1: backups --------------------------------------------------------------------------------
fresh=0
if [ "$skip_backup" = 0 ]; then
  echo "== Backups"
  "$here/backup-repos.sh" --dest "$dest" --delay "$delay" --progress "$progress"; rc=$?
  [ "$rc" = 2 ] && stop_for_github
  if [ "$rc" = 0 ]; then fresh=1; strikes=0; rm -f "$progress"
  else echo "Backups had problems (see above). Still checking the clones, using what they last fetched."
       echo "This doesn't count as a run, so you can retry straight away; repos already refreshed are skipped."; fi
  echo
fi

# --- Step 2: every clone ----------------------------------------------------------------------------
pushes=0; prs=0; needs=(); later=()
need() { needs+=("$1"); echo "   ! ${1#*: }"; }
info() { echo "     $1"; }

check_clone() {
  local d=$1 rel=${1#"$root"/} url name="" mirror base b ahead behind
  url=$(git -C "$d" config --get remote.origin.url 2>/dev/null || true)
  if [[ $url =~ github\.com[:/]$owner/([^/]+)$ ]]; then name=${BASH_REMATCH[1]%.git}; fi
  echo "== ${name:-$(basename "$d")}  ($rel)"
  if [ -z "$url" ]; then
    need "$rel: no remote at all, so nothing here is on GitHub"
    info "to put it on GitHub (private): cd \"$d\" && gh repo create $owner/$(basename "$d") --private --source . --push"
    info "then add it to github/repos.txt. Not done for you, because creating a repo is your call."
    echo; return
  fi
  [ -n "$name" ] || info "origin is $url (not $owner's), so only checking, never pushing"
  mirror="$dest/$name.git"

  # Bring origin/* up to date from today's mirror: same as git fetch, but read off the local disk.
  local source="last fetch in this clone"
  if [ "$fresh" = 1 ] && [ -n "$name" ] && [ -d "$mirror" ]; then
    git -C "$d" fetch --quiet --prune "$mirror" '+refs/heads/*:refs/remotes/origin/*' && source="today's backup"
  fi
  info "compared with GitHub as of $source"

  base=$(git -C "$d" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null); base=${base#origin/}
  if [ -z "$base" ]; then for b in main master; do git -C "$d" rev-parse -q --verify "refs/remotes/origin/$b" >/dev/null && { base=$b; break; }; done; fi
  [ -n "$base" ] || base=main

  local dirty stashes
  dirty=$(git -C "$d" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
  stashes=$(git -C "$d" stash list 2>/dev/null | wc -l | tr -d ' ')
  [ "$dirty" -gt 0 ] && need "$rel: $dirty uncommitted or untracked file(s) on $(git -C "$d" branch --show-current 2>/dev/null || echo '(detached)')"
  [ "$stashes" -gt 0 ] && need "$rel: $stashes stash(es) that only exist here"

  # Pull request heads come with the mirror (refs/pull/N/head), so finding PRs costs no API calls.
  local pulls=""
  [ -d "$mirror" ] && pulls=$(git -C "$mirror" for-each-ref --format='%(objectname) %(refname)' 'refs/pull/*/head' 2>/dev/null)
  pr_for() { [ -n "$pulls" ] || return 1; printf '%s\n' "$pulls" | awk -v s="$1" '$1==s { split($2,p,"/"); print "#" p[3]; exit }' | grep .; }

  while IFS= read -r b; do
    [ -n "$b" ] || continue
    local to_push=0 on_github=0 pr=""
    if git -C "$d" rev-parse -q --verify "refs/remotes/origin/$b" >/dev/null; then
      ahead=$(git -C "$d" rev-list --count "origin/$b..$b"); behind=$(git -C "$d" rev-list --count "$b..origin/$b")
      on_github=1; pr=$(pr_for "$(git -C "$d" rev-parse "refs/remotes/origin/$b")") || pr=""
      if [ "$ahead" -gt 0 ] && [ "$behind" -gt 0 ]; then need "$rel: $b has $ahead local and $behind GitHub commit(s) the other lacks; pull, then push"
      elif [ "$ahead" -gt 0 ] && [ "$b" = "$base" ]; then need "$rel: $base has $ahead commit(s) not on GitHub; push it yourself or move them to a branch"
      elif [ "$ahead" -gt 0 ]; then to_push=1; info "$b: $ahead commit(s) not on GitHub"
      elif [ "$behind" -gt 0 ]; then info "$b: $behind commit(s) behind GitHub (a pull will catch up)"
      fi
    elif git -C "$d" merge-base --is-ancestor "$b" "origin/$base" 2>/dev/null; then
      info "$b: only here, but already in $base; safe to delete (git branch -d $b)"; continue
    else
      ahead=$(git -C "$d" rev-list --count "origin/$base..$b" 2>/dev/null || echo '?')
      to_push=1; info "$b: never pushed ($ahead commit(s) not in $base)"
    fi

    if [ "$to_push" = 1 ]; then
      if [ -z "$name" ]; then need "$rel: $b has unpushed work (not $owner's repo, push it by hand)"; continue
      elif [ "$push" = 0 ]; then need "$rel: push $b"; continue
      elif [ "$pushes" -ge "$max_pushes" ]; then later+=("push $b in $rel"); info "$b: over this run's push cap, next run"; continue
      fi
      echo "     pushing $b"
      if net git -C "$d" push --quiet -u origin "$b"; then pushes=$((pushes + 1)); on_github=1; info "$b: pushed"
      else need "$rel: push of $b failed (see above)"; continue; fi
    fi

    # Just pushed and not in a pull request yet. (Branches already on GitHub are checked once per repo below.)
    if [ "$to_push" = 1 ] && [ "$b" != "$base" ]; then
      handled+=("$name:$b")
      if [ -n "$pr" ]; then info "$b: has pull request $pr"
      else maybe_pr "$name" "$d" "origin/$base" "$base" "$b" "$rel"; fi
    fi
  done < <(git -C "$d" for-each-ref --format='%(refname:short)' refs/heads)
  echo
}

# Offer a PR, or open one with --open-prs (never with auto-merge: these are your branches, you merge them).
maybe_pr() {  # repo, git dir, base ref, base branch, branch, where
  local name=$1 g=$2 baseref=$3 base=$4 b=$5 where=$6 title body
  if [ "$open_prs" = 0 ]; then need "$where: $b is ahead of $base with no pull request"; return; fi
  if [ "$prs" -ge "$max_prs" ]; then later+=("open a PR for $b in $where"); info "$b: over this run's PR cap, next run"; return; fi
  title=$(git -C "$g" log -1 --format=%s "$b"); body=$(git -C "$g" log --reverse --format='- %s' "$baseref..$b")
  echo "     opening a pull request for $b"
  if net gh pr create --repo "$owner/$name" --head "$b" --base "$base" --title "$title" --body "$body"; then prs=$((prs + 1))
  else need "$where: could not open a PR for $b (see above; it may already have one)"; fi
}

found=0; handled=()
while IFS= read -r -d '' g; do
  found=$((found + 1)); check_clone "$(dirname "$g")"
done < <(find "$root" -maxdepth 4 \( -name _backups -o -name node_modules \) -prune -o -name .git -print0 2>/dev/null | sort -z)
[ "$found" -gt 0 ] || echo "No clones found under $root (use --root)."

# --- Step 3: branches on GitHub ahead of main with no pull request, from the mirrors -----------------
echo "== Branches on GitHub without a pull request ($( [ "$fresh" = 1 ] && echo "today's backup" || echo "last backup" ))"
none=1
for mirror in "$dest"/*.git; do
  [ -d "$mirror" ] || continue
  name=$(basename "$mirror" .git)
  base=$(git -C "$mirror" symbolic-ref --quiet --short HEAD 2>/dev/null) || continue
  pulls=$(git -C "$mirror" for-each-ref --format='%(objectname)' 'refs/pull/*/head')
  while IFS=' ' read -r tip b; do
    [ -n "$b" ] && [ "$b" != "$base" ] || continue
    [[ " ${handled[*]-} " == *" $name:$b "* ]] && continue
    [ "$(git -C "$mirror" rev-list --count "$base..$b")" -gt 0 ] || continue
    printf '%s\n' "$pulls" | grep -qx "$tip" && continue
    none=0; echo "   $name: $b ($(git -C "$mirror" rev-list --count "$base..$b") commit(s) ahead of $base)"
    maybe_pr "$name" "$mirror" "$base" "$base" "$b" "$name on GitHub"
  done < <(git -C "$mirror" for-each-ref --format='%(objectname) %(refname:short)' refs/heads)
done
[ "$none" = 1 ] && echo "   none"
echo

# --- Summary ----------------------------------------------------------------------------------------
echo "== Summary: $found clone(s) checked, $pushes push(es), $prs PR(s) opened, $calls GitHub call(s) after the backup"
if [ ${#needs[@]} -gt 0 ]; then echo "Needs you:"; printf '  - %s\n' "${needs[@]}"; else echo "Everything local is on GitHub."; fi
if [ ${#later[@]} -gt 0 ]; then echo "Next run (over this run's caps):"; printf '  - %s\n' "${later[@]}"; fi
[ "$fresh" = 1 ] && { last_run=$now; save_state; }
mv -f "$report.tmp" "$report" 2>/dev/null && echo "(Saved to $report)"
exit 0
