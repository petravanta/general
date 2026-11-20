<#
One command for every project: refresh the local backups, then check every clone for work that isn't on GitHub yet.
See STANDARDS.md, "Syncing every project". Needs git and the GitHub CLI (gh auth login) on your own machine.

  .\github\sync-all.ps1                    # back up, then report (doesn't touch your files or branches)
  .\github\sync-all.ps1 -Push              # also push branches with commits GitHub doesn't have (at most 5)
  .\github\sync-all.ps1 -Push -OpenPRs     # ...and open pull requests for branches without one (at most 2)
  .\github\sync-all.ps1 -SkipBackup        # report only, from what's already on disk; no network at all

Options: -Root (where your clones live, default F:\Dev\petravantaapps), -Dest (backups, default <Root>\_backups),
-MaxPushes 5, -MaxPRs 2, -Delay 5-15 (seconds between GitHub calls), -MinInterval 60 (minutes between runs).

Gentle on GitHub on purpose: one repo at a time, a random pause before every GitHub call, small caps per run
(the rest is listed under "Next run"), never a force push, and a full stop, without retrying, the moment
GitHub answers 403, 429 or asks us to slow down. After that stop the next runs wait out a cool-down.
Exit codes: 0 done, 2 stopped by GitHub, 3 too soon or cooling off, 64 bad options.
#>
param(
  [string]$Root = 'F:\Dev\petravantaapps',
  [string]$Dest = '',
  [switch]$Push,
  [switch]$OpenPRs,
  [switch]$SkipBackup,
  [int]$MaxPushes = 5,
  [int]$MaxPRs = 2,
  [string]$Delay = '5-15',
  [int]$MinInterval = 60
)
$ErrorActionPreference = 'Continue'   # git and gh write progress to stderr; we read exit codes instead
$owner = 'petravanta'
if (-not $Dest) { $Dest = Join-Path $Root '_backups' }
if ($OpenPRs -and -not $Push) { Write-Host '-OpenPRs goes with -Push.'; exit 64 }
if ($Push -and $SkipBackup) { Write-Host '-Push needs the backup step (it tells us what GitHub already has).'; exit 64 }
if ($OpenPRs -and -not (Get-Command gh -ErrorAction SilentlyContinue)) {
  Write-Host '-OpenPRs needs the GitHub CLI: winget install --id GitHub.cli, then open a new terminal and run gh auth login.'; exit 64
}
$delayLo, $delayHi = $Delay -split '-' | ForEach-Object { [int]$_ }
$stateFile = Join-Path $Dest 'sync-state.txt'
$reportFile = Join-Path $Dest 'sync-report.txt'
function Now { [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() }
function When([long]$t) { [DateTimeOffset]::FromUnixTimeSeconds($t).LocalDateTime.ToString('ddd HH:mm') }

# --- State: last run, cool-down after GitHub said stop ---------------------------------------------
$state = @{ last_run = 0; blocked_until = 0; strikes = 0 }
if (Test-Path $stateFile) {
  foreach ($line in Get-Content $stateFile) {
    $k, $v = $line -split '=', 2
    if ($state.ContainsKey($k)) { $state[$k] = [long]$v }
  }
}
function Save-State {
  New-Item -ItemType Directory -Force -Path $Dest | Out-Null
  "last_run=$($state.last_run)`nblocked_until=$($state.blocked_until)`nstrikes=$($state.strikes)`n" |
    Set-Content -NoNewline -Encoding ascii $stateFile
}

$log = New-Object System.Collections.Generic.List[string]
function Say([string]$s = '') { Write-Host $s; $log.Add($s) }
function Save-Report { New-Item -ItemType Directory -Force -Path $Dest | Out-Null; $log | Set-Content -Encoding utf8 $reportFile }

if (-not $SkipBackup) {
  $now = Now
  if ($now -lt $state.blocked_until) {
    Write-Host "GitHub asked us to slow down last time. Cooling off until $(When $state.blocked_until); nothing done."
    Write-Host '(-SkipBackup still works: it reports from disk without touching GitHub.)'
    exit 3
  }
  if (($now - $state.last_run) -lt ($MinInterval * 60)) {
    Write-Host "Last run was $([int](($now - $state.last_run) / 60)) min ago; the minimum gap is $MinInterval min. Try after $(When ($state.last_run + $MinInterval * 60)), or use -SkipBackup."
    exit 3
  }
}
# Only a run that finishes its backup counts as a run (last_run is written at the end). If one is cut short,
# a retry carries on: repos refreshed in the last 6 hours are listed in the progress file and skipped.
$progressFile = Join-Path $Dest 'sync-progress.txt'
if ((Test-Path $progressFile) -and (Get-Item $progressFile).LastWriteTime -lt (Get-Date).AddHours(-6)) { Remove-Item $progressFile }

# --- Talking to GitHub ------------------------------------------------------------------------------
$limitRe = 'HTTP 403|HTTP 429|403 Forbidden|429 Too Many|rate limit|abuse|secondary rate|too many requests|slow down'
$flakyRe = 'Could not resolve host|timed out|Connection reset|early EOF|RPC failed|HTTP 50[234]|unable to access'
$script:calls = 0
function Stop-ForGitHub {
  $state.strikes++
  $hours = [Math]::Min(48, 6 * [Math]::Pow(2, $state.strikes - 1))
  $state.blocked_until = (Now) + [long]($hours * 3600); Save-State
  Say ''
  Say "STOPPED: GitHub answered with a limit or a refusal. Not retrying. Runs that use GitHub wait $hours h (until $(When $state.blocked_until))."
  Say 'Everything not yet done is still on disk; the next run picks it up.'
  Save-Report
  exit 2
}
# Run a git/gh command that talks to GitHub: a pause first, a dead stop on a limit, two retries for a flaky network.
function Invoke-GitHub([string]$exe, [string[]]$argv) {
  for ($try = 1; $try -le 3; $try++) {
    if ($script:calls -gt 0 -and $delayHi -gt 0) { Start-Sleep -Seconds (Get-Random -Minimum $delayLo -Maximum ($delayHi + 1)) }
    $script:calls++
    $out = (& $exe @argv 2>&1 | ForEach-Object { "$_" }) -join "`n"
    $rc = $LASTEXITCODE
    if ($out) { $out -split "`n" | ForEach-Object { Say "      $_" } }
    if ($rc -eq 0) { return $true }
    if ($out -match $limitRe) { Stop-ForGitHub }
    if ($out -notmatch $flakyRe -or $try -eq 3) { return $false }
    $wait = 30 * [Math]::Pow(2, $try - 1)
    Say "      network hiccup; waiting $($wait)s before trying again"
    Start-Sleep -Seconds $wait
  }
  return $false
}

# --- Step 1: backups --------------------------------------------------------------------------------
$fresh = $false
if (-not $SkipBackup) {
  Say '== Backups'
  # Its own process, so its exit code (2 = GitHub said stop) comes back cleanly.
  $ps = (Get-Process -Id $PID).Path
  & $ps -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'backup-repos.ps1') -Dest $Dest -Delay $Delay -Progress $progressFile 2>&1 |
    ForEach-Object { Say "$_" }
  $rc = $LASTEXITCODE
  if ($rc -eq 2) { Stop-ForGitHub }
  if ($rc -eq 0) { $fresh = $true; $state.strikes = 0; Remove-Item $progressFile -ErrorAction SilentlyContinue }
  else {
    Say 'Backups had problems (see above). Still checking the clones, using what they last fetched.'
    Say "This doesn't count as a run, so you can retry straight away; repos already refreshed are skipped."
  }
  Say ''
}

# --- Step 2: every clone ----------------------------------------------------------------------------
$script:pushes = 0; $script:prs = 0
$needs = New-Object System.Collections.Generic.List[string]
$later = New-Object System.Collections.Generic.List[string]
$handled = @{}
function Need([string]$where, [string]$what) { $needs.Add("${where}: $what"); Say "   ! $what" }
function Info([string]$s) { Say "     $s" }
function Git-Count([string]$dir, [string]$range) { $n = git -C $dir rev-list --count $range 2>$null; if ($LASTEXITCODE -eq 0) { [int]$n } else { -1 } }
function Has-Ref([string]$dir, [string]$ref) { git -C $dir rev-parse -q --verify $ref 2>$null | Out-Null; $LASTEXITCODE -eq 0 }

# Offer a PR, or open one with -OpenPRs (never with auto-merge: these are your branches, you merge them).
function Maybe-PR([string]$name, [string]$dir, [string]$baseRef, [string]$base, [string]$b, [string]$where) {
  if (-not $OpenPRs) { Need $where "$b is ahead of $base with no pull request"; return }
  if ($script:prs -ge $MaxPRs) { $later.Add("open a PR for $b in $where"); Info "${b}: over this run's PR cap, next run"; return }
  $title = git -C $dir log -1 --format=%s $b
  $body = (git -C $dir log --reverse --format='- %s' "$baseRef..$b") -join "`n"
  Info "opening a pull request for $b"
  if (Invoke-GitHub gh @('pr', 'create', '--repo', "$owner/$name", '--head', $b, '--base', $base, '--title', $title, '--body', $body)) { $script:prs++ }
  else { Need $where "could not open a PR for $b (see above; it may already have one)" }
}

function Check-Clone([string]$d) {
  $rel = $d.Substring($Root.TrimEnd('\', '/').Length).TrimStart('\', '/')
  $url = git -C $d config --get remote.origin.url 2>$null
  $name = ''
  if ($url -match "github\.com[:/]$owner/([^/]+?)(\.git)?$") { $name = $Matches[1] }
  Say "== $(if ($name) { $name } else { Split-Path $d -Leaf })  ($rel)"
  if (-not $url) {
    Need $rel 'no remote at all, so nothing here is on GitHub'
    Info "to put it on GitHub (private): cd `"$d`"; gh repo create $owner/$(Split-Path $d -Leaf) --private --source . --push"
    Info "then add it to github\repos.txt. Not done for you, because creating a repo is your call."
    Say ''; return
  }
  if (-not $name) { Info "origin is $url (not $owner's), so only checking, never pushing" }
  $mirror = Join-Path $Dest "$name.git"

  # Bring origin/* up to date from today's mirror: same as git fetch, but read off the local disk.
  $source = 'last fetch in this clone'
  if ($fresh -and $name -and (Test-Path $mirror)) {
    git -C $d fetch --quiet --prune $mirror '+refs/heads/*:refs/remotes/origin/*' 2>$null
    if ($LASTEXITCODE -eq 0) { $source = "today's backup" }
  }
  Info "compared with GitHub as of $source"

  $base = (git -C $d symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>$null) -replace '^origin/', ''
  if (-not $base) { $base = @('main', 'master') | Where-Object { Has-Ref $d "refs/remotes/origin/$_" } | Select-Object -First 1 }
  if (-not $base) { $base = 'main' }

  $dirty = @(git -C $d status --porcelain 2>$null).Count
  $stashes = @(git -C $d stash list 2>$null).Count
  if ($dirty -gt 0) { $cur = git -C $d branch --show-current; Need $rel "$dirty uncommitted or untracked file(s) on $(if ($cur) { $cur } else { '(detached)' })" }
  if ($stashes -gt 0) { Need $rel "$stashes stash(es) that only exist here" }

  # Pull request heads come with the mirror (refs/pull/N/head), so finding PRs costs no API calls.
  $pulls = @{}
  if (Test-Path $mirror) {
    git -C $mirror for-each-ref --format='%(objectname) %(refname)' 'refs/pull/*/head' 2>$null | ForEach-Object {
      $sha, $ref = $_ -split ' ', 2; if (-not $pulls.ContainsKey($sha)) { $pulls[$sha] = '#' + ($ref -split '/')[2] }
    }
  }

  foreach ($b in @(git -C $d for-each-ref --format='%(refname:short)' refs/heads)) {
    if (-not $b) { continue }
    $toPush = $false; $pr = ''
    if (Has-Ref $d "refs/remotes/origin/$b") {
      $ahead = Git-Count $d "origin/$b..$b"; $behind = Git-Count $d "$b..origin/$b"
      $tip = git -C $d rev-parse "refs/remotes/origin/$b"
      if ($pulls.ContainsKey($tip)) { $pr = $pulls[$tip] }
      if ($ahead -gt 0 -and $behind -gt 0) { Need $rel "$b has $ahead local and $behind GitHub commit(s) the other lacks; pull, then push" }
      elseif ($ahead -gt 0 -and $b -eq $base) { Need $rel "$base has $ahead commit(s) not on GitHub; push it yourself or move them to a branch" }
      elseif ($ahead -gt 0) { $toPush = $true; Info "${b}: $ahead commit(s) not on GitHub" }
      elseif ($behind -gt 0) { Info "${b}: $behind commit(s) behind GitHub (a pull will catch up)" }
    } else {
      git -C $d merge-base --is-ancestor $b "origin/$base" 2>$null
      if ($LASTEXITCODE -eq 0) { Info "${b}: only here, but already in $base; safe to delete (git branch -d $b)"; continue }
      $toPush = $true; Info "${b}: never pushed ($(Git-Count $d "origin/$base..$b") commit(s) not in $base)"
    }
    if (-not $toPush) { continue }

    if (-not $name) { Need $rel "$b has unpushed work (not $owner's repo, push it by hand)"; continue }
    if (-not $Push) { Need $rel "push $b"; continue }
    if ($script:pushes -ge $MaxPushes) { $later.Add("push $b in $rel"); Info "${b}: over this run's push cap, next run"; continue }
    Info "pushing $b"
    if (Invoke-GitHub git @('-C', $d, 'push', '--quiet', '-u', 'origin', $b)) { $script:pushes++; Info "${b}: pushed" }
    else { Need $rel "push of $b failed (see above)"; continue }

    # Just pushed and not in a pull request yet. (Branches already on GitHub are checked once per repo below.)
    if ($b -ne $base) {
      $handled["${name}:$b"] = $true
      if ($pr) { Info "${b}: has pull request $pr" } else { Maybe-PR $name $d "origin/$base" $base $b $rel }
    }
  }
  Say ''
}

$found = 0
Get-ChildItem -Path $Root -Filter '.git' -Force -Recurse -Depth 3 -ErrorAction SilentlyContinue |
  Where-Object { $_.FullName -notmatch '[\\/](_backups|node_modules)[\\/]' } |
  Sort-Object FullName | ForEach-Object { $found++; Check-Clone (Split-Path $_.FullName -Parent) }
if ($found -eq 0) { Say "No clones found under $Root (use -Root)." }

# --- Step 3: branches on GitHub ahead of main with no pull request, from the mirrors -----------------
Say "== Branches on GitHub without a pull request ($(if ($fresh) { "today's backup" } else { 'last backup' }))"
$none = $true
foreach ($m in @(Get-ChildItem -Path $Dest -Filter '*.git' -Directory -ErrorAction SilentlyContinue)) {
  $mirror = $m.FullName; $name = $m.BaseName
  $base = git -C $mirror symbolic-ref --quiet --short HEAD 2>$null
  if (-not $base) { continue }
  $pullShas = @(git -C $mirror for-each-ref --format='%(objectname)' 'refs/pull/*/head')
  foreach ($line in @(git -C $mirror for-each-ref --format='%(objectname) %(refname:short)' refs/heads)) {
    $tip, $b = $line -split ' ', 2
    if (-not $b -or $b -eq $base -or $handled.ContainsKey("${name}:$b")) { continue }
    $ahead = Git-Count $mirror "$base..$b"
    if ($ahead -le 0 -or $pullShas -contains $tip) { continue }
    $none = $false; Say "   ${name}: $b ($ahead commit(s) ahead of $base)"
    Maybe-PR $name $mirror $base $base $b "$name on GitHub"
  }
}
if ($none) { Say '   none' }
Say ''

# --- Summary ----------------------------------------------------------------------------------------
Say "== Summary: $found clone(s) checked, $($script:pushes) push(es), $($script:prs) PR(s) opened, $($script:calls) GitHub call(s) after the backup"
if ($needs.Count) { Say 'Needs you:'; $needs | ForEach-Object { Say "  - $_" } } else { Say 'Everything local is on GitHub.' }
if ($later.Count) { Say "Next run (over this run's caps):"; $later | ForEach-Object { Say "  - $_" } }
if ($fresh) { $state.last_run = Now; Save-State }
Save-Report
Write-Host "(Saved to $reportFile)"
exit 0
