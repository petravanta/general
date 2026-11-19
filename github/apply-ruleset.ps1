<#
Applies main-branch-ruleset.json (no force pushes, no deleting main) and repo-settings.json
(auto-merge on, squash merges, delete branches after merge) to the hub and every app repo, and switches
GitHub Pages to deploy from Actions in repos that have .github/workflows/pages.yml (STANDARDS.md,
"Version and build info"); repos without that workflow keep deploying from the branch.
The Windows twin of apply-ruleset.sh; see STANDARDS.md, "Protecting main".
Run it once from your own machine with the GitHub CLI signed in as petravanta (gh auth login):

  .\github\apply-ruleset.ps1                          # all repos below
  .\github\apply-ruleset.ps1 new-app-repo             # just the ones you name
  .\github\apply-ruleset.ps1 dance-floor wardrobe     # several (a comma list works too)
  .\github\apply-ruleset.ps1 -DryRun                  # show what it would do, change nothing

Running it again updates the rule and settings in place, so it's also how you roll out a change to either.
Works in Windows PowerShell 5.1 and PowerShell 7 (pwsh).
#>
param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$Repos = @(),
  [switch]$DryRun
)
$ErrorActionPreference = 'Stop'
$owner = 'petravanta'
$settings = Join-Path $PSScriptRoot 'repo-settings.json'
$ruleset = Join-Path $PSScriptRoot 'main-branch-ruleset.json'

# Keep this list in step with repos=(...) in apply-ruleset.sh.
$all = @('general', 'fitness-coach', 'skating-mentor', 'voicetrainer', 'nutrition-helper', 'special-trip-planner',
  'photo-timeline', 'project-tracker', 'study-buddy', 'mind-palace', 'dance-floor', 'wardrobe', 'mixmaster')
$Repos = @($Repos | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
if ($Repos.Count -eq 0) { $Repos = $all }

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
  Write-Host 'The GitHub CLI (gh) is not on the PATH. Install it from https://cli.github.com/ and run gh auth login.'; exit 1
}

# Runs gh and stops the script if it fails, like set -e in the bash version.
function Invoke-Gh([string[]]$argv) {
  if ($DryRun -and $argv[1] -eq '-X') { Write-Host "  would run: gh $($argv -join ' ')"; return '' }
  $out = & gh @argv
  if ($LASTEXITCODE -ne 0) { Write-Host "FAILED: gh $($argv -join ' ')"; exit 1 }
  return ($out -join "`n")
}

foreach ($r in $Repos) {
  Invoke-Gh @('api', '-X', 'PATCH', "repos/$owner/$r", '--input', $settings) | Out-Null
  if (-not $DryRun) { Write-Host "settings $r" }
  # Parse the list here rather than with --jq: Windows PowerShell 5.1 mangles quotes inside native arguments.
  # (5.1 also hands back a JSON array as one object, so walk it with foreach, not the pipeline.)
  $existing = Invoke-Gh @('api', "repos/$owner/$r/rulesets") | ConvertFrom-Json
  $id = $null
  foreach ($rs in $existing) { if ($rs.name -eq 'Protect main') { $id = $rs.id; break } }
  if ($id) {
    Invoke-Gh @('api', '-X', 'PUT', "repos/$owner/$r/rulesets/$id", '--input', $ruleset) | Out-Null
    if (-not $DryRun) { Write-Host "updated $r" }
  } else {
    Invoke-Gh @('api', '-X', 'POST', "repos/$owner/$r/rulesets", '--input', $ruleset) | Out-Null
    if (-not $DryRun) { Write-Host "added $r" }
  }
  # Only repos that already have the Pages workflow, so nothing stops deploying. A missing file is not an error here
  # (5.1 turns a native command's stderr into errors, so relax 'Stop' just for this probe).
  $ErrorActionPreference = 'Continue'
  & gh api "repos/$owner/$r/contents/.github/workflows/pages.yml" *> $null
  $hasPages = ($LASTEXITCODE -eq 0)
  $ErrorActionPreference = 'Stop'
  if ($hasPages) {
    Invoke-Gh @('api', '-X', 'PUT', "repos/$owner/$r/pages", '-f', 'build_type=workflow') | Out-Null
    if (-not $DryRun) { Write-Host "pages from actions $r" }
  }
}
