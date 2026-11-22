#!/usr/bin/env bash
# Checks every project against CHECKLIST.md and, if asked, applies the fixes that are safe to automate.
# See STANDARDS.md, "Checking every project". Needs git and the GitHub CLI (gh auth login) on your own machine.
#   ./github/standards.sh                        # report: every repo against every checklist row; changes nothing
#   ./github/standards.sh fitness-coach wardrobe # only these repos
#   ./github/standards.sh --only license,claude-md   # only these checklist rows
#   ./github/standards.sh --offline              # file checks only, from the backups; no GitHub calls at all
#   ./github/standards.sh --apply                # also fix what it can: repo settings, backups, and one small
#                                                # pull request per repo (auto-merge, squash) for file fixes
# Options: --root DIR (your clones, default /f/Dev/petravantaapps)  --dest DIR (backups, default ROOT/_backups)
#          --max-prs N (2)  --max-settings N (5 repos)  --delay MIN-MAX (between GitHub writes, 5-15)
#          --read-delay MIN-MAX (between GitHub reads, 2-5)  --min-interval MINUTES (between --apply runs, 60)
#
# File checks read each repo's backup mirror (_backups/<repo>.git), so they cost GitHub nothing; run backup-repos
# or sync-all first for an up-to-date answer. Settings checks read GitHub (two calls per repo, with pauses).
# Same manners as sync-all: one repo at a time, random pauses, small caps per run, and a full stop, without retrying,
# the moment GitHub answers 403, 429 or asks us to slow down. That shares sync-all's cool-down (sync-state.txt).
set -uo pipefail
owner=petravanta
root=${SYNC_ROOT:-/f/Dev/petravantaapps}
dest=""; apply=0; offline=0; only=""; repos=()
max_prs=2; max_settings=5; delay=5-15; read_delay=2-5; min_interval=60
while [ $# -gt 0 ]; do
  case "$1" in
    --apply) apply=1 ;;
    --offline) offline=1 ;;
    --only) only=$2; shift ;;
    --root) root=$2; shift ;;
    --dest) dest=$2; shift ;;
    --max-prs) max_prs=$2; shift ;;
    --max-settings) max_settings=$2; shift ;;
    --delay) delay=$2; shift ;;
    --read-delay) read_delay=$2; shift ;;
    --min-interval) min_interval=$2; shift ;;
    -h|--help) sed -n '2,18p' "$0"; exit 0 ;;
    -*) echo "Unknown option: $1 (see --help)" >&2; exit 64 ;;
    *) repos+=("$1") ;;
  esac
  shift
done
[ -n "$dest" ] || dest="$root/_backups"
[ "$apply" = 1 ] && [ "$offline" = 1 ] && { echo "--apply needs GitHub, so it can't go with --offline." >&2; exit 64; }
here=$(cd "$(dirname "$0")" && pwd)
hub=$(cd "$here/.." && pwd)            # this clone of general: CHECKLIST.md, LICENSE, apps.json, the hub lists
report="$dest/standards-report.txt"
sync_state="$dest/sync-state.txt"       # shared with sync-all: the cool-down after GitHub said stop
my_state="$dest/standards-state.txt"    # when --apply last ran
now=$(date +%s)
when() { date -d "@$1" '+%a %H:%M' 2>/dev/null || date -r "$1" '+%a %H:%M'; }

# --- The checklist ----------------------------------------------------------------------------------
c_id=(); c_level=(); c_applies=(); c_check=(); c_fix=(); c_what=()
trim() { local s=$1; s=${s#"${s%%[![:space:]]*}"}; s=${s%"${s##*[![:space:]]}"}; printf '%s' "$s"; }
while IFS= read -r line; do
  line=${line%$'\r'}
  [[ $line == '| '* ]] || continue
  IFS='|' read -r _ id level applies check fix what _ <<< "$line"
  id=$(trim "$id"); [[ $id =~ ^[a-z][a-z0-9-]*$ ]] || continue
  if [ -n "$only" ] && [[ ",$only," != *",$id,"* ]]; then continue; fi
  check=$(trim "$check"); check=${check#\`}; check=${check%\`}
  what=$(trim "$what"); what=${what//\`/}; what=$(printf '%s' "$what" | sed -E 's/ \(\[[^]]*\]\([^)]*\)\)//g; s/\*\*//g; s/\*//g')
  c_id+=("$id"); c_level+=("$(trim "$level")"); c_applies+=("$(trim "$applies")"); c_check+=("$check")
  c_fix+=("$(trim "$fix")"); c_what+=("$what")
done < "$hub/CHECKLIST.md"
[ ${#c_id[@]} -gt 0 ] || { echo "No checklist rows found in $hub/CHECKLIST.md${only:+ matching --only $only}." >&2; exit 1; }

# --- Which repos ------------------------------------------------------------------------------------
if [ ${#repos[@]} -eq 0 ]; then
  repos=(general)
  while IFS= read -r r; do repos+=("$r"); done < <(grep -oE '"id": *"[^"]+"' "$hub/shared/apps.json" | sed -E 's/.*"([^"]+)"$/\1/')
fi
app_name() { grep -E "\"id\": *\"$1\"" "$hub/shared/apps.json" | sed -nE 's/.*"name": *"([^"]+)".*/\1/p' | head -1; }

# --- Talking to GitHub (same rules as sync-all) -----------------------------------------------------
last_run=0; blocked_until=0; strikes=0; last_apply=0
if [ -f "$sync_state" ]; then
  while IFS='=' read -r k v; do v=${v%$'\r'}
    case "$k" in last_run) last_run=$v ;; blocked_until) blocked_until=$v ;; strikes) strikes=$v ;; esac
  done < "$sync_state"
fi
[ -f "$my_state" ] && last_apply=$(sed -n 's/^last_apply=//p' "$my_state" | tr -d '\r')
[ -n "$last_apply" ] || last_apply=0
if [ "$offline" = 0 ] && [ "$now" -lt "$blocked_until" ]; then
  [ "$apply" = 1 ] && { echo "GitHub asked us to slow down recently. Cooling off until $(when "$blocked_until"); nothing done." >&2; exit 3; }
  echo "GitHub asked us to slow down recently (cool-down until $(when "$blocked_until")), so this report skips the settings checks."
  offline=1
fi
if [ "$apply" = 1 ] && [ $((now - last_apply)) -lt $((min_interval * 60)) ]; then
  echo "The last --apply run was $(( (now - last_apply) / 60 )) min ago; the minimum gap is $min_interval min. Try after $(when $((last_apply + min_interval * 60))), or run without --apply for a report." >&2
  exit 3
fi

limit_re='HTTP 403|HTTP 429|403 Forbidden|429 Too Many|[Rr]ate limit|abuse|secondary rate|[Tt]oo many requests|[Ss]low down'
flaky_re='Could not resolve host|timed out|Connection reset|early EOF|RPC failed|HTTP 50[234]|unable to access'
calls=0
pause() {  # a random wait before every GitHub call except the first
  local range=$1 lo hi; lo=${range%-*}; hi=${range#*-}
  if [ "$calls" -gt 0 ] && [ "$hi" -gt 0 ]; then sleep $(( lo + RANDOM % (hi - lo + 1) )); fi
  calls=$((calls + 1))
}
stop_for_github() {
  strikes=$((strikes + 1))
  local hours=$(( 6 * (1 << (strikes - 1)) )); [ "$hours" -gt 48 ] && hours=48
  blocked_until=$(( $(date +%s) + hours * 3600 ))
  mkdir -p "$dest"; printf 'last_run=%s\nblocked_until=%s\nstrikes=%s\n' "$last_run" "$blocked_until" "$strikes" > "$sync_state"
  echo
  echo "STOPPED: GitHub answered with a limit or a refusal. Not retrying. Runs that use GitHub (this and sync-all) wait $hours h (until $(when "$blocked_until"))." >&2
  finish 2
}
out=""
gh_call() {  # gh_call READ|WRITE cmd...: pause, run, stop dead on a limit, retry a flaky network twice. Output in $out.
  local kind=$1 try rc; shift
  for try in 1 2 3; do
    if [ "$kind" = READ ]; then pause "$read_delay"; else pause "$delay"; fi
    out=$("$@" 2>&1 </dev/null); rc=$?
    [ "$rc" = 0 ] && return 0
    printf '%s' "$out" | grep -Eq "$limit_re" && { printf '%s\n' "$out" | sed 's/^/      /'; stop_for_github; }
    printf '%s' "$out" | grep -Eq "$flaky_re" || return "$rc"
    [ "$try" = 3 ] && return "$rc"
    echo "      network hiccup; waiting $(( 30 << (try - 1) ))s before trying again"
    sleep $(( 30 << (try - 1) ))
  done
}

# --- Checks -----------------------------------------------------------------------------------------
src_paths=('*.html' '*.js' '*.css' '*.webmanifest' ':!vendor/' ':!node_modules/' ':!test/')
in_mirror_grep() {  # repo, comma paths (or ""), regex
  local m="$dest/$1.git" re=${3//\{repo\}/$1} p=()
  if [ -n "$2" ]; then IFS=',' read -r -a p <<< "$2"; else p=("${src_paths[@]}"); fi
  git -C "$m" grep -qE -e "$re" HEAD -- "${p[@]}" 2>/dev/null
}
in_mirror_file() {  # repo, comma paths: any of them exists
  local f; IFS=',' read -r -a fs <<< "$2"
  for f in "${fs[@]}"; do git -C "$dest/$1.git" cat-file -e "HEAD:${f//\{repo\}/$1}" 2>/dev/null && return 0; done
  return 1
}
has_tag() {  # repo, tag
  case "$2" in
    all) return 0 ;;
    hub) [ "$1" = general ] ;;
    apps) [ "$1" != general ] ;;
    data) [ "$1" != general ] && have_mirror "$1" && git -C "$dest/$1.git" cat-file -e HEAD:data 2>/dev/null ;;
    drive) have_mirror "$1" && in_mirror_grep "$1" "" 'accounts\.google\.com/gsi|googleapis\.com/(auth|drive|upload)' ;;
    photos) have_mirror "$1" && in_mirror_grep "$1" "" 'accept="image|accept=.image/' ;;
    *) return 1 ;;
  esac
}
applies_to() {  # repo, "apps !voicetrainer"
  local t any=1
  for t in $2; do [ "$t" = "!$1" ] && return 1; done
  for t in $2; do [[ $t == '!'* ]] && continue; any=0; has_tag "$1" "$t" && return 0; done
  [ "$any" = 1 ]
}
have_mirror() { [ -d "$dest/$1.git" ]; }
clone_of() {  # any working clone under root whose origin is this repo
  local g u
  while IFS= read -r -d '' g; do
    u=$(git -C "$(dirname "$g")" config --get remote.origin.url 2>/dev/null) || continue
    [[ $u =~ github\.com[:/]$owner/$1(\.git)?$ ]] && return 0
  done < <(find "$root" -maxdepth 4 \( -name _backups -o -name node_modules \) -prune -o -name .git -print0 2>/dev/null)
  return 1
}

# Settings, read once per repo: "auto squash delete pages" and the ruleset names.
declare -A setting=()
read_settings() {
  local r=$1 a s d p
  [ "$offline" = 1 ] && return 1
  [ -n "${setting[$r.read]-}" ] && return "${setting[$r.read]}"
  setting[$r.read]=1
  gh_call READ gh api "repos/$owner/$r" --jq '[.allow_auto_merge,.allow_squash_merge,.delete_branch_on_merge,.has_pages]|@tsv' || return 1
  IFS=$'\t' read -r a s d p <<< "$out"
  setting[$r.allow_auto_merge]=$a; setting[$r.allow_squash_merge]=$s; setting[$r.delete_branch_on_merge]=$d; setting[$r.pages]=$p
  gh_call READ gh api "repos/$owner/$r/rulesets" --jq '.[].name' || return 1
  setting[$r.rulesets]=$out
  setting[$r.read]=0
}

# run_check repo index -> sets res to ok | gap | manual | skip:<why> (no subshell, so the settings cache sticks)
res=""
run_check() {
  local r=$1 i=$2 kind arg rest paths=""
  kind=${c_check[$i]%% *}; rest=""; [[ ${c_check[$i]} == *' '* ]] && rest=${c_check[$i]#* }
  [[ $kind == *:* ]] && { paths=${kind#*:}; kind=${kind%%:*}; }
  case "$kind" in
    manual) res=manual; return ;;
    file|grep|nogrep|shared) have_mirror "$r" || { res="skip:no backup yet"; return; } ;;
    setting|ruleset|pages) read_settings "$r" || { res="skip:settings not read"; return; } ;;
  esac
  case "$kind" in
    file) in_mirror_file "$r" "$rest" ;;
    grep) in_mirror_grep "$r" "$paths" "$rest" ;;
    nogrep) ! in_mirror_grep "$r" "$paths" "$rest" ;;
    shared) "$here/sync-shared.sh" --mirrors --quiet --dest "$dest" "$r" >/dev/null 2>&1 ;;
    hub-file) [ -e "$hub/${rest//\{repo\}/$r}" ] ;;
    hub-grep) grep -qE -e "${rest//\{repo\}/$r}" "$hub/$paths" 2>/dev/null ;;
    setting) [ "${setting[$r.$rest]-}" = true ] ;;
    ruleset) printf '%s\n' "${setting[$r.rulesets]-}" | grep -qxF "$rest" ;;
    pages) [ "${setting[$r.pages]-}" = true ] ;;
    mirror) have_mirror "$r" ;;
    clone) clone_of "$r" ;;
    *) res="skip:unknown check '$kind'"; return ;;
  esac && res=ok || res=gap
}

# --- File fixes, made in a scratch clone of the mirror and sent as one pull request --------------------
fix_files() {  # repo, workdir, fix ids...
  local r=$1 w=$2 f year name; shift 2
  for f in "$@"; do
    case "$f" in
      license)
        year=$(git -C "$w" log --reverse --format=%ad --date=format:%Y | head -1)
        sed -E "s/^Copyright \(c\) [0-9]{4}/Copyright (c) ${year:-$(date +%Y)}/" "$hub/LICENSE" > "$w/LICENSE" ;;
      readme-license)
        [ -f "$w/README.md" ] || printf '# %s\n' "$(app_name "$r")" > "$w/README.md"
        [ -n "$(tail -c1 "$w/README.md")" ] && echo >> "$w/README.md"
        printf '\n## License\n\nMIT, see [LICENSE](LICENSE).\n' >> "$w/README.md" ;;
      claude-md)
        if [ -f "$w/CLAUDE.md" ]; then { echo '@AGENTS.md'; echo; cat "$w/CLAUDE.md"; } > "$w/CLAUDE.md.new" && mv "$w/CLAUDE.md.new" "$w/CLAUDE.md"
        else echo '@AGENTS.md' > "$w/CLAUDE.md"; fi ;;
      agents-md)
        name=$(app_name "$r"); name=${name:-$r}
        cat > "$w/AGENTS.md" <<EOF
# Notes for coding agents

Follow the shared standards in https://github.com/petravanta/general/blob/main/STANDARDS.md (hub link, theme switch, shared look, installing on a phone, user data). This file only adds what's specific to $name.

- (Add what an agent needs to know about $name here: how to run it, where its data lives, what never to rename.)

Checked against General as of $(date +%Y-%m-%d).
EOF
        ;;
      manifest-id)
        for m in manifest.webmanifest pwa/manifest.webmanifest; do
          [ -f "$w/$m" ] || continue
          if grep -qE '"id"[[:space:]]*:' "$w/$m"; then
            sed -E "s#(\"id\"[[:space:]]*:[[:space:]]*\")[^\"]*\"#\1/$r/\"#" "$w/$m" > "$w/$m.new"
          else
            awk -v id="/$r/" '!done && /\{/ { sub(/\{/, "{\n  \"id\": \"" id "\","); done=1 } { print }' "$w/$m" > "$w/$m.new"
          fi
          mv "$w/$m.new" "$w/$m"
        done ;;
    esac
  done
}

# --- Run --------------------------------------------------------------------------------------------
mkdir -p "$dest"
finish() {
  [ -f "$report.tmp" ] && mv -f "$report.tmp" "$report" 2>/dev/null && echo "(Saved to $report)"
  exit "${1:-0}"
}
exec > >(tee "$report.tmp") 2>&1

echo "Checking ${#repos[@]} repo(s) against ${#c_id[@]} checklist row(s)$( [ "$offline" = 1 ] && echo ', files only (offline)')."
echo "Files are read from the backups in $dest; refresh them first (backup-repos or sync-all) for today's state."
echo
declare -A gaps_by=(); declare -A planned=(); declare -A fixes_for=(); needs=(); manual_ids=()
total_gaps=0
for r in "${repos[@]}"; do
  have_mirror "$r" || needs+=("$r: no backup mirror yet, so its file checks were skipped (run backup-repos.sh $r)")
  lines=(); ok=0; gap=0; soft=0; skipped=0
  for i in "${!c_id[@]}"; do
    applies_to "$r" "${c_applies[$i]}" || continue
    run_check "$r" "$i"
    case "$res" in
      ok) ok=$((ok + 1)) ;;
      manual) [[ " ${manual_ids[*]-} " == *" ${c_id[$i]} "* ]] || manual_ids+=("${c_id[$i]}") ;;
      skip:*) skipped=$((skipped + 1)) ;;
      gap)
        fx=${c_fix[$i]}; tag="    "
        if [ "${c_level[$i]}" = planned ]; then planned[${c_id[$i]}]="${planned[${c_id[$i]}]-} $r"; continue; fi
        if [ "${c_level[$i]}" = must ]; then tag=GAP; gap=$((gap + 1)); else tag=should; soft=$((soft + 1)); fi
        note=""; [ "$fx" != - ] && { note="  [--apply fixes]"; fixes_for[$r]="${fixes_for[$r]-} $fx"; }
        lines+=("$(printf '   %-6s %-17s %s%s' "$tag" "${c_id[$i]}" "${c_what[$i]}" "$note")")
        gaps_by[${c_id[$i]}]="${gaps_by[${c_id[$i]}]-} $r"
        ;;
    esac
  done
  total_gaps=$((total_gaps + gap))
  echo "== $r   $ok ok, $gap gap(s), $soft should$( [ "$skipped" -gt 0 ] && echo ", $skipped skipped")"
  [ ${#lines[@]} -gt 0 ] && printf '%s\n' "${lines[@]}"
done
echo

echo "== By concern (repos that don't follow it yet)"
any=0
for i in "${!c_id[@]}"; do
  id=${c_id[$i]}; [ -n "${gaps_by[$id]-}" ] || continue
  any=1; printf '   %-17s%s\n' "$id" "${gaps_by[$id]}"
done
[ "$any" = 0 ] && echo "   none: every repo follows every checked row"
for id in "${!planned[@]}"; do echo; echo "Planned, not rolled out yet: $id (missing in $(printf '%s' "${planned[$id]}" | wc -w | tr -d ' ') repo(s))"; done
[ ${#manual_ids[@]} -gt 0 ] && { echo; echo "To check by hand in each app: ${manual_ids[*]}"; }
echo

# --- Apply ------------------------------------------------------------------------------------------
if [ "$apply" = 1 ]; then
  echo "== Applying fixes"
  prs=0; settings_done=0; later=()
  stamp=$(date +%Y%m%d)
  for r in "${repos[@]}"; do
    fx=" ${fixes_for[$r]-} "; [ "$fx" != "  " ] || continue
    # Repo settings and the ruleset: apply-ruleset does both, three calls per repo.
    if [[ $fx == *" settings "* ]]; then
      if [ "$settings_done" -ge "$max_settings" ]; then later+=("settings for $r")
      else
        echo "   $r: applying repo settings and the Protect main ruleset"
        if gh_call WRITE "$here/apply-ruleset.sh" "$r"; then settings_done=$((settings_done + 1)); printf '%s\n' "$out" | sed 's/^/      /'
        else printf '%s\n' "$out" | sed 's/^/      /'; needs+=("$r: apply-ruleset failed (see above)"); fi
      fi
    fi
    if [[ $fx == *" backup "* ]]; then
      echo "   $r: making its first backup mirror"
      "$here/backup-repos.sh" --dest "$dest" "$r" 2>&1 | sed 's/^/      /'; rc=${PIPESTATUS[0]}
      [ "$rc" = 2 ] && stop_for_github
      [ "$rc" = 0 ] || needs+=("$r: backup failed (see above)")
    fi
    # File fixes: one branch, one small pull request, auto-merge (squash) on.
    files=(); for f in license readme-license claude-md agents-md manifest-id; do [[ $fx == *" $f "* ]] && files+=("$f"); done
    [ ${#files[@]} -gt 0 ] || continue
    if ! have_mirror "$r"; then needs+=("$r: file fixes need a backup mirror first"); continue; fi
    open=$(git -C "$dest/$r.git" for-each-ref --format='%(refname:short)' 'refs/heads/standards/*' | head -1)
    if [ -n "$open" ]; then needs+=("$r: branch $open from an earlier run is still on GitHub; merge or delete it first"); continue; fi
    if [ "$prs" -ge "$max_prs" ]; then later+=("pull request for $r (${files[*]})"); continue; fi
    w="$dest/_work/$r"; b="standards/$stamp"
    rm -rf "$w"; mkdir -p "$dest/_work"
    git clone --quiet "$dest/$r.git" "$w" && git -C "$w" remote set-url origin "https://github.com/$owner/$r.git" \
      && git -C "$w" checkout --quiet -b "$b" || { needs+=("$r: couldn't prepare a scratch clone in $w"); continue; }
    base=$(git -C "$dest/$r.git" symbolic-ref --quiet --short HEAD); base=${base:-main}
    fix_files "$r" "$w" "${files[@]}"
    git -C "$w" add -A
    if git -C "$w" diff --cached --quiet; then echo "   $r: nothing to change after all"; rm -rf "$w"; continue; fi
    title="Apply shared standards: ${files[*]}"
    git -C "$w" commit --quiet -m "$title" -m "Checklist rows from general/CHECKLIST.md, applied by github/standards.sh."
    body="Brings $r in line with these rows of the [standards checklist](https://github.com/$owner/general/blob/main/CHECKLIST.md):"$'\n\n'
    for f in "${files[@]}"; do for i in "${!c_id[@]}"; do [ "${c_fix[$i]}" = "$f" ] && body+="- **${c_id[$i]}**: ${c_what[$i]}"$'\n'; done; done
    body+=$'\n'"Opened by \`github/standards.sh --apply\`; auto-merge (squash) is on, as STANDARDS.md *Merging pull requests* describes."
    echo "   $r: pushing $b (${files[*]})"
    if ! gh_call WRITE git -C "$w" push --quiet -u origin "$b"; then printf '%s\n' "$out" | sed 's/^/      /'; needs+=("$r: push of $b failed (see above)"); continue; fi
    if ! gh_call WRITE gh pr create --repo "$owner/$r" --head "$b" --base "$base" --title "$title" --body "$body"; then
      printf '%s\n' "$out" | sed 's/^/      /'; needs+=("$r: pushed $b but couldn't open the pull request"); continue
    fi
    url=$(printf '%s\n' "$out" | grep -Eo 'https://github\.com/[^ ]+/pull/[0-9]+' | tail -1); prs=$((prs + 1))
    echo "      opened $url"
    if ! gh_call WRITE gh pr merge --auto --squash "$url"; then
      needs+=("$r: $url is open but auto-merge couldn't be turned on (is Allow auto-merge on? apply-ruleset.sh $r), so merge it by hand")
    fi
    rm -rf "$w"
  done
  printf '%s\n' "last_apply=$now" > "$my_state"
  echo "   $settings_done repo(s) got settings, $prs pull request(s) opened, $calls GitHub call(s) in all"
  [ ${#later[@]} -gt 0 ] && { echo "Next run (over this run's caps):"; printf '  - %s\n' "${later[@]}"; }
  echo
fi

echo "== Summary: $total_gaps must-have gap(s) across ${#repos[@]} repo(s), $calls GitHub call(s)"
if [ ${#needs[@]} -gt 0 ]; then echo "Needs you:"; printf '  - %s\n' "${needs[@]}"; fi
[ "$apply" = 0 ] && [ ${#fixes_for[@]} -gt 0 ] && echo "Rows marked [--apply fixes] can be fixed with: ./github/standards.sh --apply"
finish 0
