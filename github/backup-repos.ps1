<#
Keeps a full local mirror (every branch and tag) of every petravanta GitHub repo. See STANDARDS.md, "Backups".
Run it on your own machine with the GitHub CLI signed in (gh auth login) and git on the PATH.

  .\github\backup-repos.ps1                          # mirror new repos, refresh existing ones
  .\github\backup-repos.ps1 -DryRun                  # show what it would do, change nothing
  .\github\backup-repos.ps1 -Bundle G:\backups       # also write one <repo>.bundle per repo there (the second copy)
  .\github\backup-repos.ps1 -Verify                  # also check each mirror is whole (git fsck)
  .\github\backup-repos.ps1 general,voicetrainer     # only the repos you name

Mirrors go to -Dest (default F:\Dev\petravantaapps\_backups).

Gentle on GitHub: one API call lists the repos; everything else is plain git fetch, one repo at a time,
and a repo with nothing new downloads nothing.
#>
param(
  [string[]]$Repos = @(),
  [string]$Dest = 'F:\Dev\petravantaapps\_backups',
  [string]$Bundle = '',
  [switch]$DryRun,
  [switch]$Verify
)
$ErrorActionPreference = 'Stop'
$owner = 'petravanta'

function Invoke-Step([string]$exe, [string[]]$argv) {
  if ($DryRun) { Write-Host "  would run: $exe $($argv -join ' ')"; return $true }
  & $exe @argv | Out-Host
  return ($LASTEXITCODE -eq 0)
}

# The one API call. Its output is also kept as repos.json (description, visibility, homepage, default branch).
$json = gh repo list $owner --limit 500 --json name,description,visibility,homepageUrl,defaultBranchRef,isArchived,isFork,pushedAt
if ($LASTEXITCODE -ne 0 -or -not $json) { throw "No repos listed for $owner. Is gh signed in?" }
$list = $json | ConvertFrom-Json

if (-not $DryRun) {
  New-Item -ItemType Directory -Force -Path $Dest | Out-Null
  $json | Set-Content -Encoding utf8 (Join-Path $Dest 'repos.json')
  if ($Bundle) { New-Item -ItemType Directory -Force -Path $Bundle | Out-Null }
}

$failed = $false
foreach ($r in $list) {
  $name = $r.name
  if ($Repos.Count -gt 0 -and $Repos -notcontains $name) { continue }
  $mirror = Join-Path $Dest "$name.git"
  if (Test-Path $mirror) {
    Write-Host "refresh $name"
    $ok = Invoke-Step git @('-C', $mirror, 'remote', 'update', '--prune')
  } else {
    Write-Host "mirror  $name (new)"
    $ok = Invoke-Step git @('clone', '--quiet', '--mirror', "https://github.com/$owner/$name.git", $mirror)
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
}

if ($DryRun) { Write-Host 'Dry run: nothing changed.' }
elseif ($failed) { Write-Error 'Some repos failed, see above.'; exit 1 }
else { Write-Host "Backups up to date in $Dest" }
