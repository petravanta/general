<#
Checks that the shared code each app pastes in (google-token.js, drive-store.js, ...) still matches general\shared\.
The Windows twin of sync-shared.sh; see STANDARDS.md, "Pasted shared code". The list of pasted files and their
markers is shared\blocks.txt.

  .\github\sync-shared.ps1               # report: every app clone under Root; changes nothing
  .\github\sync-shared.ps1 wardrobe      # only these apps
  .\github\sync-shared.ps1 -Diff         # also show which lines differ
  .\github\sync-shared.ps1 -Apply        # replace stale copies in your clones' working files (no commit, no push)
  .\github\sync-shared.ps1 -Mirrors      # read the backup mirrors (_backups\<repo>.git) instead of your clones

Options: -Root (your clones, default F:\Dev\petravantaapps), -Dest (backups, default <Root>\_backups),
-Quiet (print nothing; the exit code says it all, as standards.ps1 uses it),
-Force (with -Apply, also replace copies that were edited inside their markers, losing those edits).
A stale copy is "old" when it matches an earlier version of general's file (safe to replace), or "edited" when it
matches none, because the app changed it inside the markers: move those lines after the closing marker first.
A pasted block is the lines from its opening marker comment to its closing one. A file under a shared\ folder with
the same name (js\shared\drive-store.js in an app split into files) is compared whole. Copies are compared line by
line, ignoring the opening comment, indentation, trailing spaces and blank lines.
Exit codes: 0 every copy is current, 1 a copy is stale or broken, 64 bad options. Never touches GitHub.
Works in Windows PowerShell 5.1 and PowerShell 7 (pwsh).
#>
param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$Repos = @(),
  [switch]$Apply,
  [switch]$Mirrors,
  [switch]$Quiet,
  [switch]$Diff,
  [switch]$Force,
  [string]$Root = 'F:\Dev\petravantaapps',
  [string]$Dest = ''
)
$ErrorActionPreference = 'Continue'
$owner = 'petravanta'
if (-not $Dest) { $Dest = Join-Path $Root '_backups' }
if ($Apply -and $Mirrors) { Write-Host "-Apply changes your clones, so it can't go with -Mirrors."; exit 64 }
$hub = Split-Path -Parent $PSScriptRoot
$Repos = @($Repos | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
function Say([string]$s = '') { if (-not $Quiet) { Write-Host $s } }
$utf8 = New-Object System.Text.UTF8Encoding($false)

# --- What is shared ---------------------------------------------------------------------------------
$blocks = @()
foreach ($line in [System.IO.File]::ReadAllLines((Join-Path $hub 'shared\blocks.txt'), $utf8)) {
  $t = $line.Trim()
  if (-not $t -or $t.StartsWith('#')) { continue }
  $c = $t -split '\|'
  if ($c.Count -lt 3) { continue }
  $blocks += [pscustomobject]@{ File = $c[0].Trim(); Start = $c[1].Trim(); End = $c[2].Trim() }
}

function Get-Block([string[]]$lines, [string]$start, [string]$end) {  # first block: opening marker to closing one
  $out = New-Object System.Collections.Generic.List[string]; $on = $false
  foreach ($l in $lines) {
    if (-not $on) { if ($l.Contains($start)) { $on = $true } else { continue } }
    $out.Add($l)
    if ($l.Contains($end)) { break }
  }
  return ,$out.ToArray()
}
function Norm([string[]]$lines) {  # without the opening comment, indentation, trailing spaces and blank lines
  $out = New-Object System.Collections.Generic.List[string]; $inComment = $false
  for ($i = 0; $i -lt $lines.Count; $i++) {
    $l = $lines[$i].TrimEnd("`r")
    if ($i -eq 0 -and $l.Contains('/*')) { if (-not $l.Contains('*/')) { $inComment = $true }; continue }
    if ($inComment) { if ($l.Contains('*/')) { $inComment = $false }; continue }
    $l = $l.Trim()
    if ($l) { $out.Add($l) }
  }
  return ,$out.ToArray()
}
function Read-Lines([string]$path) { return ,([System.IO.File]::ReadAllText($path, $utf8) -split "`n") }

# Every earlier version of a shared file, from general's history, to tell an old copy from an edited one.
$history = @{}
function From-Version($b, [string[]]$normCopy) {  # the date of the version this copy matches, or $null
  if (-not $history.ContainsKey($b.File)) {
    $versions = @()
    foreach ($entry in @(git -C $hub log --format='%h %ad' --date=short -- "shared/$($b.File)" 2>$null)) {
      $h, $when = "$entry" -split ' ', 2
      $text = (git -C $hub show "${h}:shared/$($b.File)" 2>$null) -join "`n"
      if ($LASTEXITCODE -ne 0) { continue }
      $lines = $text -split "`n"
      $blk = Get-Block $lines $b.Start $b.End
      if ($blk.Count -eq 0) { $blk = $lines }
      $versions += [pscustomobject]@{ When = $when; Text = ((Norm $blk) -join "`n") }
    }
    $history[$b.File] = $versions
  }
  $joined = $normCopy -join "`n"
  foreach ($v in $history[$b.File]) { if ($v.Text -ceq $joined) { return $v.When } }
  return $null
}

# --- Which apps -------------------------------------------------------------------------------------
$apps = Get-Content -Raw -Encoding utf8 (Join-Path $hub 'shared\apps.json') | ConvertFrom-Json
if ($Repos.Count -eq 0) { $Repos = @($apps | ForEach-Object { $_.id }) }
$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("sync-shared-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
$sources = @()
if ($Mirrors) {
  foreach ($r in $Repos) {
    if ($r -eq 'general') { continue }
    $m = Join-Path $Dest "$r.git"
    if (-not (Test-Path $m)) { Say "== ${r}: no backup mirror at $m, skipped"; continue }
    $d = Join-Path $tmp $r
    New-Item -ItemType Directory -Force -Path $d | Out-Null
    git -C $m archive --format=zip -o (Join-Path $tmp "$r.zip") HEAD 2>$null
    if ($LASTEXITCODE -eq 0) { Expand-Archive -Path (Join-Path $tmp "$r.zip") -DestinationPath $d -Force }
    $sources += [pscustomobject]@{ Repo = $r; Dir = $d; Label = 'backup mirror, main' }
  }
} else {
  Get-ChildItem -Path $Root -Directory -Recurse -Depth 3 -Force -Filter '.git' -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -notmatch '\\(_backups|node_modules)\\' } | ForEach-Object {
      $d = $_.Parent.FullName
      $u = git -C $d config --get remote.origin.url 2>$null
      if ("$u" -match "github\.com[:/]$owner/([A-Za-z0-9._-]+?)(\.git)?$") {
        $r = $Matches[1]
        if ($r -ne 'general' -and $Repos -contains $r) {
          $b = git -C $d rev-parse --abbrev-ref HEAD 2>$null
          $script:sources += [pscustomobject]@{ Repo = $r; Dir = $d; Label = "$b" }
        }
      }
    }
  if ($sources.Count -eq 0) { Say "No app clones found under $Root (use -Root, or -Mirrors to read the backups)." }
}

# --- Compare ----------------------------------------------------------------------------------------
$stale = 0; $fixed = 0
$staleList = New-Object System.Collections.Generic.List[string]
$skipped = New-Object System.Collections.Generic.List[string]
$touched = New-Object System.Collections.Generic.HashSet[string]   # files this run rewrote
foreach ($src in $sources) {
  $r = $src.Repo; $d = $src.Dir
  Say "== $r   ($d, $($src.Label))"
  $found = $false
  $files = @(Get-ChildItem -Path $d -Recurse -File -Force -Include '*.html', '*.js', '*.mjs', '*.css' -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName.Substring($d.Length) -notmatch '[\\/](\.git|node_modules|vendor|test)[\\/]' })
  foreach ($b in $blocks) {
    $canonPath = Join-Path $hub "shared\$($b.File)"
    $canonLines = Read-Lines $canonPath
    foreach ($fi in $files) {
      $rel = $fi.FullName.Substring($d.Length).TrimStart('\', '/').Replace('\', '/')
      $lines = Read-Lines $fi.FullName
      $whole = ($rel -eq "shared/$($b.File)" -or $rel.EndsWith("/shared/$($b.File)"))
      if (-not $whole -and -not ($lines | Where-Object { $_.Contains($b.Start) } | Select-Object -First 1)) { continue }
      $found = $true
      if ($whole) { $copy = $lines; $want = $canonLines }
      else { $copy = Get-Block $lines $b.Start $b.End; $want = Get-Block $canonLines $b.Start $b.End }
      $name = $b.File.PadRight(16)
      $status = ''
      if (-not $whole -and -not $copy[$copy.Count - 1].Contains($b.End)) { $status = 'broken'; $detail = 'opening marker without its closing one' }
      else {
        $nc = Norm $copy; $nw = Norm $want
        $delta = @(Compare-Object -SyncWindow ([Math]::Max($nc.Count, $nw.Count)) -CaseSensitive $nc $nw)
        if ($delta.Count -eq 0) { Say "   ok       $name $rel"; continue }
        $when = From-Version $b $nc
        if ($when) { $status = 'old'; $detail = "general's copy as of $when, $($delta.Count) line(s) behind" }
        else { $status = 'edited'; $detail = "$($delta.Count) line(s) differ, and it matches no version in general: changed inside its markers?" }
      }
      $stale++; $staleList.Add("${r}: $($b.File) in $rel ($status)")
      Say "   $($status.PadRight(8)) $name ${rel}: $detail"
      if ($Diff -and $status -ne 'broken' -and -not $Quiet) {
        foreach ($x in $delta) { $side = if ($x.SideIndicator -eq '<=') { "- $r" } else { '+ general' }; Say "      $side  $($x.InputObject)" }
      }
      if (-not $Apply) { continue }
      if ($status -eq 'broken') { $skipped.Add("${r}: $rel has no closing marker for $($b.File); fix it by hand"); continue }
      if ($status -eq 'edited' -and -not $Force) {
        $skipped.Add("${r}: $($b.File) in $rel was edited inside its markers; move the app's own lines after the closing marker (or into shared/), then run again, or use -Force to drop them"); continue
      }
      git -C $d diff --quiet HEAD -- $rel 2>$null
      if ($LASTEXITCODE -ne 0 -and -not $touched.Contains($fi.FullName)) { $skipped.Add("${r}: $rel has uncommitted changes; commit or stash them, then run again"); continue }
      if ($whole) { Copy-Item -Force $canonPath $fi.FullName }
      else {
        $text = [System.IO.File]::ReadAllText($fi.FullName, $utf8)
        $nl = if ($text.Contains("`r`n")) { "`r`n" } else { "`n" }
        $all = $text -split "`r?`n"
        $out = New-Object System.Collections.Generic.List[string]; $state = 0
        foreach ($l in $all) {
          if ($state -eq 1) { if ($l.Contains($b.End)) { $state = 2 }; continue }
          if ($state -eq 0 -and $l.Contains($b.Start)) {
            $indent = ([regex]::Match($l, '^[ \t]*')).Value
            foreach ($w in ($want | ForEach-Object { $_.TrimEnd("`r") })) { if ($w) { $out.Add($indent + $w) } else { $out.Add('') } }
            $state = if ($l.Contains($b.End)) { 2 } else { 1 }
            continue
          }
          $out.Add($l)
        }
        [System.IO.File]::WriteAllText($fi.FullName, ($out -join $nl), $utf8)
      }
      [void]$touched.Add($fi.FullName); $fixed++; Say '            replaced with the current copy (not committed)'
    }
  }
  if (-not $found) { Say '   (no pasted shared code)' }
}
if (Test-Path $tmp) { Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue }

Say ''
if ($stale -eq 0) { Say 'Every pasted copy matches general/shared/.' }
else {
  Say "$stale copy(s) out of date (old: safe to replace; edited: the app changed it inside the markers):"; foreach ($x in $staleList) { Say "  - $x" }
  if ($Apply) {
    Say "$fixed replaced in the working files. Review, test, commit and open a pull request in each app."
    if ($skipped.Count -gt 0) { Say 'Not replaced:'; foreach ($x in $skipped) { Say "  - $x" } }
  } else { Say 'Run with -Apply to replace them in your clones, or -Diff to see what changed.' }
}
if ($stale -eq 0 -or ($Apply -and $fixed -eq $stale)) { exit 0 } else { exit 1 }
