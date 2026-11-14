<#
Keeps a full local mirror (every branch and tag) of every petravanta GitHub repo. See STANDARDS.md, "Backups".
Run it on your own machine with git on the PATH. With the GitHub CLI signed in (gh auth login) it finds every repo
by itself; without it, it backs up the repos in github\repos.txt, the mirrors it already has, and the origins of
your clones under the folder above -Dest, using plain git.

  .\github\backup-repos.ps1                          # mirror new repos, refresh existing ones
  .\github\backup-repos.ps1 -DryRun                  # show what it would do, change nothing
  .\github\backup-repos.ps1 -Bundle G:\backups       # also write one <repo>.bundle per repo there (the second copy)
  .\github\backup-repos.ps1 -Verify                  # also check each mirror is whole (git fsck)
  .\github\backup-repos.ps1 general,voicetrainer     # only the repos you name
  .\github\backup-repos.ps1 -Delay 5-15              # wait a random 5-15 s between repos (sync-all.ps1 does this)
  .\github\backup-repos.ps1 -Progress FILE           # skip repos listed in FILE, add each one done (lets a cut-short run resume)

Mirrors go to -Dest (default F:\Dev\petravantaapps\_backups).

Gentle on GitHub: one API call lists the repos; everything else is plain git fetch, one repo at a time,
and a repo with nothing new downloads nothing. If GitHub answers 403/429 or asks us to slow down, it stops at once
without retrying and exits with 2.
#>
param(
  [string[]]$Repos = @(),
  [string]$Dest = 'F:\Dev\petravantaapps\_backups',
  [string]$Bundle = '',
  [switch]$DryRun,
  [switch]$Verify,
  [string]$Delay = '0-0',
  [string]$Progress = ''
)
$ErrorActionPreference = 'Stop'
$owner = 'petravanta'

function Invoke-Step([string]$exe, [string[]]$argv) {
  if ($DryRun) { Write-Host "  would run: $exe $($argv -join ' ')"; return $true }
  & $exe @argv | Out-Host
  return ($LASTEXITCODE -eq 0)
}

$limitRe = 'HTTP 403|HTTP 429|403 Forbidden|429 Too Many|rate limit|abuse|secondary rate|too many requests|slow down'
$delayLo, $delayHi = $Delay -split '-' | ForEach-Object { [int]$_ }
$script:fetched = 0
# A git command that talks to GitHub: pause between repos, stop dead on a limit.
function Invoke-GitHub([string[]]$argv) {
  if ($DryRun) { Write-Host "  would run: git $($argv -join ' ')"; return $true }
  if ($script:fetched -gt 0 -and $delayHi -gt 0) { Start-Sleep -Seconds (Get-Random -Minimum $delayLo -Maximum ($delayHi + 1)) }
  $script:fetched++
  $ErrorActionPreference = 'Continue'   # git writes progress to stderr
  $out = (& git @argv 2>&1 | ForEach-Object { "$_" }) -join "`n"
  $rc = $LASTEXITCODE
  if ($out) { Write-Host $out }
  if ($rc -ne 0 -and $out -match $limitRe) {
    Write-Host 'STOPPED: GitHub answered with a limit or a refusal. Not retrying; try again in a few hours.'; exit 2
  }
  return ($rc -eq 0)
}

# Without gh: repos.txt, the mirrors already here, and the origins of local clones. Plain git, no API.
function Get-RepoNamesWithoutGh {
  $names = New-Object System.Collections.Generic.HashSet[string]
  $txt = Join-Path $PSScriptRoot 'repos.txt'
  if (Test-Path $txt) { Get-Content $txt | ForEach-Object { $n = ($_ -replace '#.*', '').Trim(); if ($n) { [void]$names.Add($n) } } }
  if (Test-Path $Dest) { Get-ChildItem -Path $Dest -Filter '*.git' -Directory | ForEach-Object { [void]$names.Add($_.BaseName) } }
  $clones = Split-Path $Dest -Parent
  Get-ChildItem -Path $clones -Filter '.git' -Force -Recurse -Depth 3 -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -notmatch '[\\/](_backups|node_modules)[\\/]' } | ForEach-Object {
      $url = git -C (Split-Path $_.FullName -Parent) config --get remote.origin.url 2>$null
      if ($url -match "github\.com[:/]$owner/([^/]+?)(\.git)?$") { [void]$names.Add($Matches[1]) }
    }
  return @($names | Sort-Object | ForEach-Object { [pscustomobject]@{ name = $_ } })
}

# The one API call. Its output is also kept as repos.json (description, visibility, homepage, default branch).
$json = $null
if (Get-Command gh -ErrorAction SilentlyContinue) {
  $errFile = [IO.Path]::GetTempFileName()
  $ErrorActionPreference = 'Continue'
  $json = gh repo list $owner --limit 500 --json name,description,visibility,homepageUrl,defaultBranchRef,isArchived,isFork,pushedAt 2>$errFile
  $listed = ($LASTEXITCODE -eq 0 -and $json)
  $ErrorActionPreference = 'Stop'
  if (-not $listed) {
    $err = Get-Content -Raw $errFile; Write-Host $err
    if ($err -match $limitRe) { Write-Host 'STOPPED: GitHub answered with a limit. Not retrying.'; exit 2 }
    Write-Host 'The GitHub CLI is installed but not signed in. Run: gh auth login'
    $json = $null
  }
} else {
  Write-Host 'The GitHub CLI (gh) is not installed, so new repos on GitHub are not found automatically.'
  Write-Host '  To add it: winget install --id GitHub.cli   then open a new terminal and run: gh auth login'
}
if ($json) { $list = $json | ConvertFrom-Json }
else {
  $list = Get-RepoNamesWithoutGh
  if (-not $list) { throw "No repos to back up: add names to $(Join-Path $PSScriptRoot 'repos.txt'), or install gh." }
  Write-Host "Using plain git for $($list.Count) repos from repos.txt, existing mirrors and local clones."
}

if (-not $DryRun) {
  New-Item -ItemType Directory -Force -Path $Dest | Out-Null
  if ($json) { $json | Set-Content -Encoding utf8 (Join-Path $Dest 'repos.json') }
  if ($Bundle) { New-Item -ItemType Directory -Force -Path $Bundle | Out-Null }
}

$failed = $false
foreach ($r in $list) {
  $name = $r.name
  if ($Repos.Count -gt 0 -and $Repos -notcontains $name) { continue }
  if ($Progress -and (Test-Path $Progress) -and (Get-Content $Progress) -contains $name) { Write-Host "skip    $name (refreshed earlier, resuming)"; continue }
  $mirror = Join-Path $Dest "$name.git"
  if (Test-Path $mirror) {
    Write-Host "refresh $name"
    $ok = Invoke-GitHub @('-C', $mirror, 'remote', 'update', '--prune')
  } else {
    Write-Host "mirror  $name (new)"
    $ok = Invoke-GitHub @('clone', '--quiet', '--mirror', "https://github.com/$owner/$name.git", $mirror)
  }
  if (-not $ok) { Write-Warning "FAILED $name"; $failed = $true; continue }
  if ($Verify -and -not (Invoke-Step git @('-C', $mirror, 'fsck', '--connectivity-only', '--no-progress'))) {
    Write-Warning "BROKEN $name"; $failed = $true
  }
  if ($Bundle) {
    # An empty repo has nothing to bundle.
    $hasRefs = $DryRun -or (git -C $mirror for-each-ref --count=1)
    if ($hasRefs) { Invoke-Step git @('-C', $mirror, 'bundle', 'create', (Join-Path $Bundle "$name.bundle"), '--all') | Out-Null }
  }
  if ($Progress -and -not $DryRun) { Add-Content -Encoding ascii $Progress $name }
}

if ($DryRun) { Write-Host 'Dry run: nothing changed.' }
elseif ($failed) { Write-Error 'Some repos failed, see above.'; exit 1 }
else { Write-Host "Backups up to date in $Dest" }
