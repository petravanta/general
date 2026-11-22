<#
Checks every project against CHECKLIST.md and, if asked, applies the fixes that are safe to automate.
The Windows twin of standards.sh; see STANDARDS.md, "Checking every project".
Needs git and the GitHub CLI (gh auth login) on your own machine.

  .\github\standards.ps1                          # report: every repo against every checklist row; changes nothing
  .\github\standards.ps1 fitness-coach wardrobe   # only these repos
  .\github\standards.ps1 -Only license,claude-md  # only these checklist rows
  .\github\standards.ps1 -Offline                 # file checks only, from the backups; no GitHub calls at all
  .\github\standards.ps1 -Apply                   # also fix what it can: repo settings, backups, and one small
                                                  # pull request per repo (auto-merge, squash) for file fixes

Options: -Root (your clones, default F:\Dev\petravantaapps), -Dest (backups, default <Root>\_backups),
-MaxPRs 2, -MaxSettings 5 (repos), -Delay 5-15 (seconds between GitHub writes), -ReadDelay 2-5 (between reads),
-MinInterval 60 (minutes between -Apply runs).

File checks read each repo's backup mirror (_backups\<repo>.git), so they cost GitHub nothing; run backup-repos
or sync-all first for an up-to-date answer. Settings checks read GitHub (two calls per repo, with pauses).
Same manners as sync-all: one repo at a time, random pauses, small caps per run, and a full stop, without retrying,
the moment GitHub answers 403, 429 or asks us to slow down. That shares sync-all's cool-down (sync-state.txt).
Exit codes: 0 done, 2 stopped by GitHub, 3 too soon or cooling off, 64 bad options.
Works in Windows PowerShell 5.1 and PowerShell 7 (pwsh).
#>
param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$Repos = @(),
  [switch]$Apply,
  [switch]$Offline,
  [string[]]$Only = @(),
  [string]$Root = 'F:\Dev\petravantaapps',
  [string]$Dest = '',
  [int]$MaxPRs = 2,
  [int]$MaxSettings = 5,
  [string]$Delay = '5-15',
  [string]$ReadDelay = '2-5',
  [int]$MinInterval = 60
)
$ErrorActionPreference = 'Continue'   # git and gh write progress to stderr; we read exit codes instead
$owner = 'petravanta'
if (-not $Dest) { $Dest = Join-Path $Root '_backups' }
if ($Apply -and $Offline) { Write-Host "-Apply needs GitHub, so it can't go with -Offline."; exit 64 }
$hub = Split-Path -Parent $PSScriptRoot          # this clone of general: CHECKLIST.md, LICENSE, apps.json, hub lists
$reportFile = Join-Path $Dest 'standards-report.txt'
$syncState = Join-Path $Dest 'sync-state.txt'    # shared with sync-all: the cool-down after GitHub said stop
$myState = Join-Path $Dest 'standards-state.txt' # when -Apply last ran
function Now { [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() }
function When([long]$t) { [DateTimeOffset]::FromUnixTimeSeconds($t).LocalDateTime.ToString('ddd HH:mm') }
function Range([string]$s) { $lo, $hi = $s -split '-' | ForEach-Object { [int]$_ }; return @($lo, $hi) }
$writeLo, $writeHi = Range $Delay
$readLo, $readHi = Range $ReadDelay
$Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$Repos = @($Repos | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })

$log = New-Object System.Collections.Generic.List[string]
function Say([string]$s = '') { Write-Host $s; $log.Add($s) }
function Save-Report { New-Item -ItemType Directory -Force -Path $Dest | Out-Null; $log | Set-Content -Encoding utf8 $reportFile; Write-Host "(Saved to $reportFile)" }

# --- The checklist ----------------------------------------------------------------------------------
$rows = @()
foreach ($line in Get-Content -Encoding utf8 (Join-Path $hub 'CHECKLIST.md')) {
  if (-not $line.StartsWith('| ')) { continue }
  $cells = $line -split '\|'
  if ($cells.Count -lt 8) { continue }
  $id = $cells[1].Trim()
  if ($id -notmatch '^[a-z][a-z0-9-]*$') { continue }
  if ($Only.Count -gt 0 -and $Only -notcontains $id) { continue }
  $what = $cells[6].Trim() -replace '`', '' -replace ' \(\[[^\]]*\]\([^)]*\)\)', '' -replace '\*', ''
  $rows += [pscustomobject]@{ Id = $id; Level = $cells[2].Trim(); Applies = $cells[3].Trim()
    Check = $cells[4].Trim().Trim('`'); Fix = $cells[5].Trim(); What = $what }
}
if ($rows.Count -eq 0) { Write-Host "No checklist rows found in $hub\CHECKLIST.md."; exit 1 }

# --- Which repos ------------------------------------------------------------------------------------
$apps = Get-Content -Raw -Encoding utf8 (Join-Path $hub 'shared\apps.json') | ConvertFrom-Json
if ($Repos.Count -eq 0) { $Repos = @('general'); foreach ($a in $apps) { $Repos += $a.id } }
function App-Name([string]$r) { foreach ($a in $apps) { if ($a.id -eq $r) { return $a.name } }; return $r }

# --- Talking to GitHub (same rules as sync-all) -----------------------------------------------------
$state = @{ last_run = 0; blocked_until = 0; strikes = 0 }
if (Test-Path $syncState) {
  foreach ($line in Get-Content $syncState) { $k, $v = $line -split '=', 2; if ($state.ContainsKey($k)) { $state[$k] = [long]$v } }
}
$lastApply = 0
if (Test-Path $myState) { foreach ($line in Get-Content $myState) { if ($line -match '^last_apply=(\d+)') { $lastApply = [long]$Matches[1] } } }
$now = Now
if (-not $Offline -and $now -lt $state.blocked_until) {
  if ($Apply) { Write-Host "GitHub asked us to slow down recently. Cooling off until $(When $state.blocked_until); nothing done."; exit 3 }
  Say "GitHub asked us to slow down recently (cool-down until $(When $state.blocked_until)), so this report skips the settings checks."
  $Offline = $true
}
if ($Apply -and ($now - $lastApply) -lt ($MinInterval * 60)) {
  Write-Host "The last -Apply run was $([int](($now - $lastApply) / 60)) min ago; the minimum gap is $MinInterval min. Try after $(When ($lastApply + $MinInterval * 60)), or run without -Apply for a report."
  exit 3
}

$limitRe = 'HTTP 403|HTTP 429|403 Forbidden|429 Too Many|rate limit|abuse|secondary rate|too many requests|slow down'
$flakyRe = 'Could not resolve host|timed out|Connection reset|early EOF|RPC failed|HTTP 50[234]|unable to access'
$script:calls = 0
$script:out = ''
function Stop-ForGitHub {
  $state.strikes++
  $hours = [Math]::Min(48, 6 * [Math]::Pow(2, $state.strikes - 1))
  $state.blocked_until = (Now) + [long]($hours * 3600)
  New-Item -ItemType Directory -Force -Path $Dest | Out-Null
  "last_run=$($state.last_run)`nblocked_until=$($state.blocked_until)`nstrikes=$($state.strikes)`n" | Set-Content -NoNewline -Encoding ascii $syncState
  Say ''
  Say "STOPPED: GitHub answered with a limit or a refusal. Not retrying. Runs that use GitHub (this and sync-all) wait $hours h (until $(When $state.blocked_until))."
  Save-Report
  exit 2
}
# Run a command that talks to GitHub: a pause first, a dead stop on a limit, two retries for a flaky network.
# The output is left in $script:out.
function Invoke-GitHub([bool]$read, [string]$exe, [string[]]$argv) {
  $lo = if ($read) { $readLo } else { $writeLo }; $hi = if ($read) { $readHi } else { $writeHi }
  for ($try = 1; $try -le 3; $try++) {
    if ($script:calls -gt 0 -and $hi -gt 0) { Start-Sleep -Seconds (Get-Random -Minimum $lo -Maximum ($hi + 1)) }
    $script:calls++
    $script:out = (& $exe @argv 2>&1 | ForEach-Object { "$_" }) -join "`n"
    $rc = $LASTEXITCODE
    if ($rc -eq 0) { return $true }
    if ($script:out -match $limitRe) { $script:out -split "`n" | ForEach-Object { Say "      $_" }; Stop-ForGitHub }
    if ($script:out -notmatch $flakyRe -or $try -eq 3) { return $false }
    $wait = 30 * [Math]::Pow(2, $try - 1)
    Say "      network hiccup; waiting $($wait)s before trying again"
    Start-Sleep -Seconds $wait
  }
  return $false
}

# --- Checks -----------------------------------------------------------------------------------------
# Files are read straight out of the mirror (git show), and matched here rather than with git grep,
# because Windows PowerShell 5.1 mangles quotes inside native arguments.
function Mirror([string]$r) { Join-Path $Dest "$r.git" }
function Have-Mirror([string]$r) { Test-Path (Mirror $r) }
$fileCache = @{}
function Read-File([string]$r, [string]$path) {
  $key = "$r|$path"
  if (-not $fileCache.ContainsKey($key)) {
    $text = (git -C (Mirror $r) show "HEAD:$path" 2>$null) -join "`n"
    $fileCache[$key] = if ($LASTEXITCODE -eq 0) { $text } else { $null }
  }
  return $fileCache[$key]
}
$treeCache = @{}
function Tree([string]$r) {
  if (-not $treeCache.ContainsKey($r)) { $treeCache[$r] = @(git -C (Mirror $r) ls-tree -r --name-only HEAD 2>$null) }
  return $treeCache[$r]
}
function Source-Files([string]$r) {  # the app's own pages, scripts, styles and manifests
  Tree $r | Where-Object { $_ -match '\.(html|js|css|webmanifest)$' -and $_ -notmatch '^(vendor|node_modules|test)/' }
}
function Mirror-Has([string]$r, [string]$paths) {
  foreach ($p in ($paths -split ',')) {
    $p = $p.Replace('{repo}', $r)
    git -C (Mirror $r) cat-file -e "HEAD:$p" 2>$null
    if ($LASTEXITCODE -eq 0) { return $true }
  }
  return $false
}
function Mirror-Grep([string]$r, [string]$paths, [string]$re) {
  $re = '(?m)' + $re.Replace('{repo}', $r)
  if ($paths) {
    $files = @()
    foreach ($p in ($paths -split ',')) {
      $p = $p.Replace('{repo}', $r)
      $files += @(Tree $r | Where-Object { $_ -eq $p -or $_.StartsWith("$p/") })
    }
  } else { $files = @(Source-Files $r) }
  foreach ($f in $files) { $t = Read-File $r $f; if ($t -and $t -cmatch $re) { return $true } }
  return $false
}
function Has-Tag([string]$r, [string]$tag) {
  switch ($tag) {
    'all' { return $true }
    'hub' { return $r -eq 'general' }
    'apps' { return $r -ne 'general' }
    'data' { return ($r -ne 'general' -and (Have-Mirror $r) -and (Mirror-Has $r 'data')) }
    'drive' { return ((Have-Mirror $r) -and (Mirror-Grep $r '' 'accounts\.google\.com/gsi|googleapis\.com/(auth|drive|upload)')) }
    'photos' { return ((Have-Mirror $r) -and (Mirror-Grep $r '' 'accept="image|accept=.image/')) }
  }
  return $false
}
function Applies-To([string]$r, [string]$applies) {
  $tokens = $applies -split '\s+' | Where-Object { $_ }
  if ($tokens -contains "!$r") { return $false }
  $pos = @($tokens | Where-Object { -not $_.StartsWith('!') })
  if ($pos.Count -eq 0) { return $true }
  foreach ($t in $pos) { if (Has-Tag $r $t) { return $true } }
  return $false
}
$script:clones = $null
function Clone-Of([string]$r) {  # any working clone under Root whose origin is this repo
  if ($null -eq $script:clones) {
    $script:clones = @()
    Get-ChildItem -Path $Root -Directory -Recurse -Depth 3 -Force -Filter '.git' -ErrorAction SilentlyContinue |
      Where-Object { $_.FullName -notmatch '\\(_backups|node_modules)\\' } |
      ForEach-Object { $u = git -C $_.Parent.FullName config --get remote.origin.url 2>$null; if ($u) { $script:clones += "$u" } }
  }
  foreach ($u in $script:clones) { if ($u -match "github\.com[:/]$owner/$([regex]::Escape($r))(\.git)?$") { return $true } }
  return $false
}

$settings = @{}
function Read-Settings([string]$r) {
  if ($Offline) { return $false }
  if ($settings.ContainsKey($r)) { return [bool]$settings[$r] }
  $settings[$r] = $null
  if (-not (Invoke-GitHub $true 'gh' @('api', "repos/$owner/$r"))) { return $false }
  $info = $script:out | ConvertFrom-Json
  if (-not (Invoke-GitHub $true 'gh' @('api', "repos/$owner/$r/rulesets"))) { return $false }
  $names = @(); foreach ($rs in ($script:out | ConvertFrom-Json)) { $names += $rs.name }
  $settings[$r] = @{ allow_auto_merge = [bool]$info.allow_auto_merge; allow_squash_merge = [bool]$info.allow_squash_merge
    delete_branch_on_merge = [bool]$info.delete_branch_on_merge; pages = [bool]$info.has_pages; rulesets = $names }
  return $true
}

# Returns ok | gap | manual | skip
function Run-Check([string]$r, $row) {
  $kind, $rest = $row.Check -split ' ', 2
  $paths = ''
  if ($kind -match '^([a-z-]+):(.*)$') { $kind = $Matches[1]; $paths = $Matches[2] }
  if ($kind -eq 'manual') { return 'manual' }
  if ($kind -in @('file', 'grep', 'nogrep', 'shared') -and -not (Have-Mirror $r)) { return 'skip' }
  if ($kind -in @('setting', 'ruleset', 'pages') -and -not (Read-Settings $r)) { return 'skip' }
  $okay = switch ($kind) {
    'file' { Mirror-Has $r $rest }
    'grep' { Mirror-Grep $r $paths $rest }
    'nogrep' { -not (Mirror-Grep $r $paths $rest) }
    'shared' { & (Join-Path $PSScriptRoot 'sync-shared.ps1') -Mirrors -Quiet -Dest $Dest $r *> $null; $LASTEXITCODE -eq 0 }
    'hub-file' { Test-Path (Join-Path $hub $rest.Replace('{repo}', $r)) }
    'hub-grep' { $t = Get-Content -Raw -Encoding utf8 (Join-Path $hub $paths) -ErrorAction SilentlyContinue; [bool]($t -and $t -cmatch ('(?m)' + $rest.Replace('{repo}', $r))) }
    'setting' { [bool]$settings[$r][$rest] }
    'ruleset' { $settings[$r].rulesets -contains $rest }
    'pages' { [bool]$settings[$r].pages }
    'mirror' { Have-Mirror $r }
    'clone' { Clone-Of $r }
    default { $null }
  }
  if ($null -eq $okay) { return 'skip' }
  if ($okay) { return 'ok' } else { return 'gap' }
}

# --- File fixes, made in a scratch clone of the mirror and sent as one pull request --------------------
$utf8 = New-Object System.Text.UTF8Encoding($false)   # no BOM, LF endings, like the rest of the repos
function Write-Text([string]$path, [string]$text) { [System.IO.File]::WriteAllText($path, $text.Replace("`r`n", "`n"), $utf8) }
function Fix-Files([string]$r, [string]$w, [string[]]$fixes) {
  foreach ($f in $fixes) {
    switch ($f) {
      'license' {
        $year = git -C $w log --reverse --format=%ad --date=format:%Y | Select-Object -First 1
        if (-not $year) { $year = (Get-Date).Year }
        $text = [System.IO.File]::ReadAllText((Join-Path $hub 'LICENSE')) -replace '(?m)^Copyright \(c\) \d{4}', "Copyright (c) $year"
        Write-Text (Join-Path $w 'LICENSE') $text
      }
      'readme-license' {
        $p = Join-Path $w 'README.md'
        $text = if (Test-Path $p) { [System.IO.File]::ReadAllText($p) } else { "# $(App-Name $r)`n" }
        if (-not $text.EndsWith("`n")) { $text += "`n" }
        Write-Text $p ($text + "`n## License`n`nMIT, see [LICENSE](LICENSE).`n")
      }
      'claude-md' {
        $p = Join-Path $w 'CLAUDE.md'
        $text = if (Test-Path $p) { "@AGENTS.md`n`n" + [System.IO.File]::ReadAllText($p) } else { "@AGENTS.md`n" }
        Write-Text $p $text
      }
      'agents-md' {
        $name = App-Name $r
        Write-Text (Join-Path $w 'AGENTS.md') (@(
          '# Notes for coding agents', '',
          "Follow the shared standards in https://github.com/petravanta/general/blob/main/STANDARDS.md (hub link, theme switch, shared look, installing on a phone, user data). This file only adds what's specific to $name.", '',
          "- (Add what an agent needs to know about $name here: how to run it, where its data lives, what never to rename.)", '',
          "Checked against General as of $(Get-Date -Format 'yyyy-MM-dd').", ''
        ) -join "`n")
      }
      'manifest-id' {
        foreach ($m in @('manifest.webmanifest', 'pwa\manifest.webmanifest')) {
          $p = Join-Path $w $m
          if (-not (Test-Path $p)) { continue }
          $text = [System.IO.File]::ReadAllText($p)
          if ($text -match '"id"\s*:') { $text = $text -replace '("id"\s*:\s*")[^"]*"', "`${1}/$r/`"" }
          else { $text = ([regex]'\{').Replace($text, "{`n  `"id`": `"/$r/`",", 1) }
          Write-Text $p $text
        }
      }
    }
  }
}

# --- Run --------------------------------------------------------------------------------------------
Say "Checking $($Repos.Count) repo(s) against $($rows.Count) checklist row(s)$(if ($Offline) { ', files only (offline)' })."
Say "Files are read from the backups in $Dest; refresh them first (backup-repos or sync-all) for today's state."
Say ''
$needs = New-Object System.Collections.Generic.List[string]
$gapsBy = [ordered]@{}; $planned = [ordered]@{}; $fixesFor = @{}; $manualIds = New-Object System.Collections.Generic.List[string]
$totalGaps = 0
foreach ($r in $Repos) {
  if (-not (Have-Mirror $r)) { $needs.Add("${r}: no backup mirror yet, so its file checks were skipped (run backup-repos.ps1 $r)") }
  $lines = @(); $ok = 0; $gap = 0; $soft = 0; $skipped = 0
  foreach ($row in $rows) {
    if (-not (Applies-To $r $row.Applies)) { continue }
    switch (Run-Check $r $row) {
      'ok' { $ok++ }
      'manual' { if (-not $manualIds.Contains($row.Id)) { $manualIds.Add($row.Id) } }
      'skip' { $skipped++ }
      'gap' {
        if ($row.Level -eq 'planned') { $planned[$row.Id] = @($planned[$row.Id]) + $r; break }
        if ($row.Level -eq 'must') { $tag = 'GAP'; $gap++ } else { $tag = 'should'; $soft++ }
        $note = ''
        if ($row.Fix -ne '-') { $note = '  [-Apply fixes]'; if (-not $fixesFor[$r]) { $fixesFor[$r] = @() }; $fixesFor[$r] += $row.Fix }
        $lines += ('   {0,-6} {1,-17} {2}{3}' -f $tag, $row.Id, $row.What, $note)
        $gapsBy[$row.Id] = @($gapsBy[$row.Id] | Where-Object { $_ }) + $r
      }
    }
  }
  $totalGaps += $gap
  Say "== $r   $ok ok, $gap gap(s), $soft should$(if ($skipped) { ", $skipped skipped" })"
  foreach ($l in $lines) { Say $l }
}
Say ''
Say "== By concern (repos that don't follow it yet)"
if ($gapsBy.Count -eq 0) { Say '   none: every repo follows every checked row' }
foreach ($id in $gapsBy.Keys) { Say ('   {0,-17} {1}' -f $id, ($gapsBy[$id] -join ' ')) }
foreach ($id in $planned.Keys) { Say ''; Say "Planned, not rolled out yet: $id (missing in $(@($planned[$id] | Where-Object { $_ }).Count) repo(s))" }
if ($manualIds.Count -gt 0) { Say ''; Say "To check by hand in each app: $($manualIds -join ' ')" }
Say ''

# --- Apply ------------------------------------------------------------------------------------------
if ($Apply) {
  Say '== Applying fixes'
  $prs = 0; $settingsDone = 0
  $later = New-Object System.Collections.Generic.List[string]
  $stamp = Get-Date -Format 'yyyyMMdd'
  $ps = (Get-Process -Id $PID).Path
  foreach ($r in $Repos) {
    $fx = @($fixesFor[$r] | Where-Object { $_ })
    if ($fx.Count -eq 0) { continue }
    # Repo settings and the ruleset: apply-ruleset does both, three calls per repo.
    if ($fx -contains 'settings') {
      if ($settingsDone -ge $MaxSettings) { $later.Add("settings for $r") }
      else {
        Say "   ${r}: applying repo settings and the Protect main ruleset"
        $ok = Invoke-GitHub $false $ps @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $PSScriptRoot 'apply-ruleset.ps1'), $r)
        $script:out -split "`n" | Where-Object { $_ } | ForEach-Object { Say "      $_" }
        if ($ok) { $settingsDone++ } else { $needs.Add("${r}: apply-ruleset failed (see above)") }
      }
    }
    if ($fx -contains 'backup') {
      Say "   ${r}: making its first backup mirror"
      & $ps -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'backup-repos.ps1') -Dest $Dest $r 2>&1 | ForEach-Object { Say "      $_" }
      if ($LASTEXITCODE -eq 2) { Stop-ForGitHub }
      if ($LASTEXITCODE -ne 0) { $needs.Add("${r}: backup failed (see above)") }
    }
    # File fixes: one branch, one small pull request, auto-merge (squash) on.
    $files = @(@('license', 'readme-license', 'claude-md', 'agents-md', 'manifest-id') | Where-Object { $fx -contains $_ })
    if ($files.Count -eq 0) { continue }
    if (-not (Have-Mirror $r)) { $needs.Add("${r}: file fixes need a backup mirror first"); continue }
    $open = git -C (Mirror $r) for-each-ref --format='%(refname:short)' 'refs/heads/standards/*' | Select-Object -First 1
    if ($open) { $needs.Add("${r}: branch $open from an earlier run is still on GitHub; merge or delete it first"); continue }
    if ($prs -ge $MaxPRs) { $later.Add("pull request for $r ($($files -join ' '))"); continue }
    $w = Join-Path $Dest "_work\$r"; $b = "standards/$stamp"
    if (Test-Path $w) { Remove-Item -Recurse -Force $w }
    New-Item -ItemType Directory -Force -Path (Join-Path $Dest '_work') | Out-Null
    git clone --quiet (Mirror $r) $w 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) { git -C $w remote set-url origin "https://github.com/$owner/$r.git"; git -C $w checkout --quiet -b $b 2>&1 | Out-Null }
    if ($LASTEXITCODE -ne 0) { $needs.Add("${r}: couldn't prepare a scratch clone in $w"); continue }
    $base = git -C (Mirror $r) symbolic-ref --quiet --short HEAD; if (-not $base) { $base = 'main' }
    Fix-Files $r $w $files
    git -C $w add -A
    git -C $w diff --cached --quiet
    if ($LASTEXITCODE -eq 0) { Say "   ${r}: nothing to change after all"; Remove-Item -Recurse -Force $w; continue }
    $title = "Apply shared standards: $($files -join ' ')"
    git -C $w commit --quiet -m $title -m 'Checklist rows from general/CHECKLIST.md, applied by github/standards.ps1.'
    $body = "Brings $r in line with these rows of the [standards checklist](https://github.com/$owner/general/blob/main/CHECKLIST.md):`n`n"
    foreach ($f in $files) { foreach ($row in $rows) { if ($row.Fix -eq $f) { $body += "- **$($row.Id)**: $($row.What)`n" } } }
    $body += "`nOpened by ``github/standards.ps1 -Apply``; auto-merge (squash) is on, as STANDARDS.md *Merging pull requests* describes."
    $bodyFile = Join-Path $Dest '_work\pr-body.md'; Write-Text $bodyFile $body   # a file, so 5.1 can't mangle the quotes
    Say "   ${r}: pushing $b ($($files -join ' '))"
    if (-not (Invoke-GitHub $false 'git' @('-C', $w, 'push', '--quiet', '-u', 'origin', $b))) {
      $script:out -split "`n" | ForEach-Object { Say "      $_" }; $needs.Add("${r}: push of $b failed (see above)"); continue
    }
    if (-not (Invoke-GitHub $false 'gh' @('pr', 'create', '--repo', "$owner/$r", '--head', $b, '--base', $base, '--title', $title, '--body-file', $bodyFile))) {
      $script:out -split "`n" | ForEach-Object { Say "      $_" }; $needs.Add("${r}: pushed $b but couldn't open the pull request"); continue
    }
    $url = ([regex]::Matches($script:out, 'https://github\.com/\S+/pull/\d+') | Select-Object -Last 1).Value
    $prs++
    Say "      opened $url"
    if (-not (Invoke-GitHub $false 'gh' @('pr', 'merge', '--auto', '--squash', $url))) {
      $needs.Add("${r}: $url is open but auto-merge couldn't be turned on (is Allow auto-merge on? apply-ruleset.ps1 $r), so merge it by hand")
    }
    Remove-Item -Recurse -Force $w
  }
  "last_apply=$now`n" | Set-Content -NoNewline -Encoding ascii $myState
  Say "   $settingsDone repo(s) got settings, $prs pull request(s) opened, $($script:calls) GitHub call(s) in all"
  if ($later.Count -gt 0) { Say "Next run (over this run's caps):"; foreach ($l in $later) { Say "  - $l" } }
  Say ''
}

Say "== Summary: $totalGaps must-have gap(s) across $($Repos.Count) repo(s), $($script:calls) GitHub call(s)"
if ($needs.Count -gt 0) { Say 'Needs you:'; foreach ($n in $needs) { Say "  - $n" } }
if (-not $Apply -and $fixesFor.Count -gt 0) { Say 'Rows marked [-Apply fixes] can be fixed with: .\github\standards.ps1 -Apply' }
Save-Report
exit 0
