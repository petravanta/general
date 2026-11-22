#!/usr/bin/env bash
# Checks that the shared code each app pastes in (google-token.js, drive-store.js, ...) still matches general/shared/.
# See STANDARDS.md, "Pasted shared code". The list of pasted files and their markers is shared/blocks.txt.
#   ./github/sync-shared.sh                  # report: every app clone under ROOT; changes nothing
#   ./github/sync-shared.sh wardrobe         # only these apps
#   ./github/sync-shared.sh --diff           # also show what differs
#   ./github/sync-shared.sh --apply          # replace stale copies in your clones' working files (no commit, no push)
#   ./github/sync-shared.sh --mirrors        # read the backup mirrors (_backups/<repo>.git) instead of your clones
# Options: --root DIR (your clones, default /f/Dev/petravantaapps)  --dest DIR (backups, default ROOT/_backups)
#          --quiet (print nothing; the exit code says it all, as standards.sh uses it)
#          --force (with --apply, also replace copies that were edited inside their markers, losing those edits)
# A stale copy is "old" when it matches an earlier version of general's file (safe to replace), or "edited" when it
# matches none, because the app changed it inside the markers: move those lines after the closing marker first.
# A pasted block is the lines from its opening marker comment to its closing one. A file under a shared/ folder
# with the same name (js/shared/drive-store.js in an app split into files) is compared whole.
# Copies are compared line by line, ignoring the opening comment, indentation, trailing spaces and blank lines.
# Exit codes: 0 every copy is current, 1 a copy is stale or broken, 64 bad options. Never touches GitHub.
set -uo pipefail
owner=petravanta
root=${SYNC_ROOT:-/f/Dev/petravantaapps}
dest=""; apply=0; mirrors=0; quiet=0; show_diff=0; force=0; repos=()
while [ $# -gt 0 ]; do
  case "$1" in
    --apply) apply=1 ;;
    --mirrors) mirrors=1 ;;
    --quiet) quiet=1 ;;
    --diff) show_diff=1 ;;
    --force) force=1 ;;
    --root) root=$2; shift ;;
    --dest) dest=$2; shift ;;
    -h|--help) sed -n '2,18p' "$0"; exit 0 ;;
    -*) echo "Unknown option: $1 (see --help)" >&2; exit 64 ;;
    *) repos+=("$1") ;;
  esac
  shift
done
[ -n "$dest" ] || dest="$root/_backups"
[ "$apply" = 1 ] && [ "$mirrors" = 1 ] && { echo "--apply changes your clones, so it can't go with --mirrors." >&2; exit 64; }
here=$(cd "$(dirname "$0")" && pwd)
hub=$(cd "$here/.." && pwd)
say() { [ "$quiet" = 1 ] || printf '%s\n' "$*"; }
trim() { local s=$1; s=${s#"${s%%[![:space:]]*}"}; s=${s%"${s##*[![:space:]]}"}; printf '%s' "$s"; }

# --- What is shared ---------------------------------------------------------------------------------
b_file=(); b_start=(); b_end=()
while IFS='|' read -r f s e; do
  f=$(trim "${f%$'\r'}"); [ -n "$f" ] && [[ $f != '#'* ]] || continue
  b_file+=("$f"); b_start+=("$(trim "$s")"); b_end+=("$(trim "${e%$'\r'}")")
done < "$hub/shared/blocks.txt"

block() {  # file start end: print the lines from the opening marker to the closing one (first block only)
  awk -v s="$2" -v e="$3" 'on { print; if (index($0, e)) exit; next } index($0, s) { on = 1; print; if (index($0, e)) exit }' "$1"
}
# Compared without the opening comment (the block's title and notes), indentation, trailing spaces or blank lines.
norm() {
  tr -d '\r' | awk 'NR == 1 && index($0, "/*") && !index($0, "*/") { c = 1; next } c { if (index($0, "*/")) c = 0; next } NR == 1 && index($0, "/*") { next } { print }' \
    | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//' | grep -v '^$'
}
ends_ok() { tail -n 1 "$1" | grep -qF -- "$2"; }

# Every earlier version of a shared file, from general's history, to tell an old copy from an edited one.
from_version() {  # index of blocks, normalized copy file -> prints the date of the matching version, if any
  local i=$1 f=${b_file[$1]} dir="$tmp/hist/${b_file[$1]}" h when n=0
  if [ ! -d "$dir" ]; then
    mkdir -p "$dir"
    while read -r h when; do
      n=$((n + 1))
      git -C "$hub" show "$h:shared/$f" > "$dir/v" 2>/dev/null || continue
      block "$dir/v" "${b_start[$i]}" "${b_end[$i]}" | norm > "$dir/$n.$when"
      [ -s "$dir/$n.$when" ] || norm < "$dir/v" > "$dir/$n.$when"
    done < <(git -C "$hub" log --format='%h %ad' --date=short -- "shared/$f" 2>/dev/null)
  fi
  for h in "$dir"/[0-9]*; do
    [ -e "$h" ] && cmp -s "$h" "$2" && { printf '%s' "${h##*.}"; return 0; }
  done
  return 1
}

# --- Which apps -------------------------------------------------------------------------------------
if [ ${#repos[@]} -eq 0 ]; then
  while IFS= read -r r; do repos+=("$r"); done < <(grep -oE '"id": *"[^"]+"' "$hub/shared/apps.json" | sed -E 's/.*"([^"]+)"$/\1/')
fi
wanted() { local r; for r in "${repos[@]}"; do [ "$r" = "$1" ] && return 0; done; return 1; }

# Where to read each app from: "repo<TAB>folder<TAB>label"
sources=()
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
if [ "$mirrors" = 1 ]; then
  for r in "${repos[@]}"; do
    [ "$r" = general ] && continue
    m="$dest/$r.git"
    if [ ! -d "$m" ]; then say "== $r: no backup mirror at $m, skipped"; continue; fi
    mkdir -p "$tmp/$r" && git -C "$m" archive HEAD 2>/dev/null | tar -x -C "$tmp/$r" 2>/dev/null
    sources+=("$r"$'\t'"$tmp/$r"$'\t'"backup mirror, main")
  done
else
  while IFS= read -r -d '' g; do
    d=$(dirname "$g")
    u=$(git -C "$d" config --get remote.origin.url 2>/dev/null) || continue
    [[ $u =~ github\.com[:/]$owner/([A-Za-z0-9._-]+)$ ]] || continue
    r=${BASH_REMATCH[1]%.git}
    [ "$r" = general ] && continue
    wanted "$r" || continue
    sources+=("$r"$'\t'"$d"$'\t'"$(git -C "$d" rev-parse --abbrev-ref HEAD 2>/dev/null)")
  done < <(find "$root" -maxdepth 4 \( -name _backups -o -name node_modules \) -prune -o -name .git -print0 2>/dev/null)
  [ ${#sources[@]} -gt 0 ] || say "No app clones found under $root (use --root, or --mirrors to read the backups)."
fi

# --- Compare ----------------------------------------------------------------------------------------
stale=0; stale_list=(); fixed=0; skipped=(); touched=()   # touched: files this run rewrote
for src in "${sources[@]}"; do
  IFS=$'\t' read -r r d label <<< "$src"
  say "== $r   ($d, $label)"
  found=0
  mapfile -d '' files < <(find "$d" \( -name .git -o -name node_modules -o -name vendor -o -name test \) -prune -o \
    -type f \( -name '*.html' -o -name '*.js' -o -name '*.mjs' -o -name '*.css' \) -print0 2>/dev/null)
  for i in "${!b_file[@]}"; do
    f=${b_file[$i]}; s=${b_start[$i]}; e=${b_end[$i]}; canon="$hub/shared/$f"
    for p in "${files[@]}"; do
      rel=${p#"$d"/}
      if [[ $rel == */shared/"$f" || $rel == shared/"$f" ]]; then whole=1
      elif grep -qF -- "$s" "$p"; then whole=0
      else continue; fi
      found=1
      if [ "$whole" = 1 ]; then cp "$p" "$tmp/copy"; cp "$canon" "$tmp/want"
      else block "$p" "$s" "$e" > "$tmp/copy"; block "$canon" "$s" "$e" > "$tmp/want"; fi
      if [ "$whole" = 0 ] && ! ends_ok "$tmp/copy" "$e"; then
        status=broken; detail="opening marker without its closing one"
      elif diff -q <(norm < "$tmp/copy") <(norm < "$tmp/want") >/dev/null; then
        say "   ok       $(printf '%-16s' "$f") $rel"; continue
      else
        n=$(diff <(norm < "$tmp/copy") <(norm < "$tmp/want") | grep -c '^[<>]')
        norm < "$tmp/copy" > "$tmp/copy.norm"
        if when=$(from_version "$i" "$tmp/copy.norm"); then status=old; detail="general's copy as of $when, $n line(s) behind"
        else status=edited; detail="$n line(s) differ, and it matches no version in general: changed inside its markers?"; fi
      fi
      stale=$((stale + 1)); stale_list+=("$r: $f in $rel ($status)")
      say "   $(printf '%-8s' "$status") $(printf '%-16s' "$f") $rel: $detail"
      if [ "$show_diff" = 1 ] && [ "$status" != broken ] && [ "$quiet" = 0 ]; then
        diff -u --label "$r/$rel" --label "general/shared/$f" <(norm < "$tmp/copy") <(norm < "$tmp/want") | sed 's/^/      /'
      fi
      [ "$apply" = 1 ] || continue
      if [ "$status" = broken ]; then skipped+=("$r: $rel has no closing marker for $f; fix it by hand"); continue; fi
      if [ "$status" = edited ] && [ "$force" = 0 ]; then
        skipped+=("$r: $f in $rel was edited inside its markers; move the app's own lines after the closing marker (or into shared/), then run again, or use --force to drop them"); continue
      fi
      if [[ " ${touched[*]-} " != *" $p "* ]] && ! git -C "$d" diff --quiet HEAD -- "$rel" 2>/dev/null; then
        skipped+=("$r: $rel has uncommitted changes; commit or stash them, then run again"); continue
      fi
      if [ "$whole" = 1 ]; then cp "$canon" "$p"
      else
        cp "$tmp/want" "$tmp/put"
        cr=0; grep -q $'\r$' "$p" && cr=1
        awk -v s="$s" -v e="$e" -v canon="$tmp/put" -v cr="$cr" '
          function put(   line, ind) {
            ind = start; sub(/[^ \t].*$/, "", ind)
            while ((getline line < canon) > 0) { sub(/\r$/, "", line); print (line == "" ? "" : ind line) (cr ? "\r" : "") }
            close(canon)
          }
          state == 2 { print; next }
          state == 1 { if (index($0, e)) state = 2; next }
          index($0, s) { start = $0; put(); state = index($0, e) ? 2 : 1; next }
          { print }' "$p" > "$p.sync-shared" && mv "$p.sync-shared" "$p"
      fi
      touched+=("$p"); fixed=$((fixed + 1)); say "            replaced with the current copy (not committed)"
    done
  done
  [ "$found" = 1 ] || say "   (no pasted shared code)"
done

say ""
if [ "$stale" = 0 ]; then say "Every pasted copy matches general/shared/."
else
  say "$stale copy(s) out of date (old: safe to replace; edited: the app changed it inside the markers):"; for x in "${stale_list[@]}"; do say "  - $x"; done
  if [ "$apply" = 1 ]; then
    say "$fixed replaced in the working files. Review, test, commit and open a pull request in each app."
    [ ${#skipped[@]} -gt 0 ] && { say "Not replaced:"; for x in "${skipped[@]}"; do say "  - $x"; done; }
  else say "Run with --apply to replace them in your clones, or --diff to see what changed."; fi
fi
[ "$stale" = 0 ] || { [ "$apply" = 1 ] && [ "$fixed" = "$stale" ]; }
