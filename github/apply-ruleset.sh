#!/usr/bin/env bash
# Applies main-branch-ruleset.json (no force pushes, no deleting main) to the hub and every app repo.
# Run it once from your own machine with the GitHub CLI signed in as petravanta (gh auth login):
#   ./github/apply-ruleset.sh                 # all repos below
#   ./github/apply-ruleset.sh new-app-repo    # just the ones you name
# Running it again updates the rule in place, so it's also how you roll out a change to the rule.
set -euo pipefail
cd "$(dirname "$0")"
repos=(general fitness-coach skating-mentor voicetrainer nutrition-helper special-trip-planner photo-timeline project-tracker study-buddy)
if [ $# -gt 0 ]; then repos=("$@"); fi
for r in "${repos[@]}"; do
  id=$(gh api "repos/petravanta/$r/rulesets" --jq '.[] | select(.name=="Protect main") | .id')
  if [ -n "$id" ]; then
    gh api -X PUT "repos/petravanta/$r/rulesets/$id" --input main-branch-ruleset.json >/dev/null && echo "updated $r"
  else
    gh api -X POST "repos/petravanta/$r/rulesets" --input main-branch-ruleset.json >/dev/null && echo "added $r"
  fi
done
