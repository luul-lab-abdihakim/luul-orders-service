#!/usr/bin/env bash
# Platform engineer: set up teams, permissions, protection and environments for a
# trunk-based repo in a GitHub ORGANIZATION. (The same thing is in platform/terraform/.)
#
# Usage:  ./platform/setup-org.sh <practice-org> <repo>
# Optional: add real people to teams (GitHub usernames, space separated):
#   DEVELOPERS="friend1 friend2" QA="friend3" LEADS="friend4" ./platform/setup-org.sh my-lab-org luul-orders-service
set -euo pipefail
ORG="${1:?usage: $0 <practice-org> <repo>}"
REPO="${2:?usage: $0 <practice-org> <repo>}"

# Safety: this is a PRACTICE script. Never change the real company org by accident.
if [[ "$(echo "$ORG" | tr '[:upper:]' '[:lower:]')" == "luul-solutions" && "${ALLOW_REAL_ORG:-}" != "yes" ]]; then
  echo "STOP: '$ORG' is the real company organization. Use a practice org."
  echo "(Only with approval from your lead/admins: ALLOW_REAL_ORG=yes $0 $ORG $REPO)"
  exit 1
fi

say() { echo; echo "==> $*"; }

# ---------------------------------------------------------------- 1. Teams
# GitHub repo roles, from least to most power: read < triage < push(write) < maintain < admin
create_team() {  # name, repo role, description
  say "Team '$1' -> repo role '$2'"
  if ! gh api "orgs/$ORG/teams/$1" >/dev/null 2>&1; then
    gh api -X POST "orgs/$ORG/teams" -f name="$1" -f description="$3" -f privacy=closed >/dev/null
  fi
  gh api -X PUT "orgs/$ORG/teams/$1/repos/$ORG/$REPO" -f permission="$2" >/dev/null
}
create_team developers push     "Developers: write code, open PRs, cannot change settings or deploy to prod"
create_team qa         push     "QA: own e2e tests, review flag changes, triage bugs"
create_team leads      maintain "Lead engineers: review money logic, approve prod deploys, manage releases"
create_team platform   admin    "Platform/DevOps: own pipelines, repo settings, rulesets, environments"

add_members() {
  local team="$1"; shift
  for user in "$@"; do
    gh api -X PUT "orgs/$ORG/teams/$team/memberships/$user" -f role=member >/dev/null && echo "   added $user to $team"
  done
}
add_members developers ${DEVELOPERS:-}
add_members qa ${QA:-}
add_members leads ${LEADS:-}
add_members platform ${PLATFORM:-}

# ---------------------------------------------------------------- 2. Repo settings
say "Merge settings: squash only, delete branch after merge, suggest updating branches"
gh repo edit "$ORG/$REPO" \
  --enable-squash-merge --enable-merge-commit=false --enable-rebase-merge=false \
  --delete-branch-on-merge --allow-update-branch --enable-auto-merge

say "Security: secret scanning + push protection (free on public repos)"
gh api -X PATCH "repos/$ORG/$REPO" --input - >/dev/null <<'JSON' || echo "   (skipped: not available on this plan/visibility)"
{"security_and_analysis": {"secret_scanning": {"status": "enabled"},
                           "secret_scanning_push_protection": {"status": "enabled"}}}
JSON

# ---------------------------------------------------------------- 3. Ruleset on main
say "Ruleset 'protect-trunk' on main"
existing=$(gh api "repos/$ORG/$REPO/rulesets" -q '.[] | select(.name=="protect-trunk") | .id' || true)
method=POST; path="repos/$ORG/$REPO/rulesets"
if [ -n "$existing" ]; then method=PUT; path="repos/$ORG/$REPO/rulesets/$existing"; fi

gh api -X "$method" "$path" --input - >/dev/null <<'JSON'
{
  "name": "protect-trunk",
  "target": "branch",
  "enforcement": "active",
  "conditions": { "ref_name": { "include": ["~DEFAULT_BRANCH"], "exclude": [] } },
  "bypass_actors": [
    { "actor_id": 1, "actor_type": "OrganizationAdmin", "bypass_mode": "pull_request" }
  ],
  "rules": [
    { "type": "deletion" },
    { "type": "non_fast_forward" },
    { "type": "required_linear_history" },
    { "type": "pull_request",
      "parameters": {
        "required_approving_review_count": 1,
        "require_code_owner_review": true,
        "dismiss_stale_reviews_on_push": true,
        "require_last_push_approval": true,
        "required_review_thread_resolution": true
      } },
    { "type": "required_status_checks",
      "parameters": {
        "strict_required_status_checks_policy": true,
        "required_status_checks": [
          { "context": "unit-tests" },
          { "context": "e2e-tests" },
          { "context": "docker-build" },
          { "context": "secret-scan" }
        ]
      } }
  ]
}
JSON

# ---------------------------------------------------------------- 4. Environments
say "Environments: dev (auto), staging (auto, main only), prod (leads + platform approve)"
LEADS_ID=$(gh api "orgs/$ORG/teams/leads" -q .id)
PLATFORM_ID=$(gh api "orgs/$ORG/teams/platform" -q .id)

gh api -X PUT "repos/$ORG/$REPO/environments/dev" >/dev/null
for env in staging prod; do
  if [ "$env" = prod ]; then
    body=$(printf '{"wait_timer":0,"prevent_self_review":false,"reviewers":[{"type":"Team","id":%s},{"type":"Team","id":%s}],"deployment_branch_policy":{"protected_branches":false,"custom_branch_policies":true}}' "$LEADS_ID" "$PLATFORM_ID")
  else
    body='{"deployment_branch_policy":{"protected_branches":false,"custom_branch_policies":true}}'
  fi
  echo "$body" | gh api -X PUT "repos/$ORG/$REPO/environments/$env" --input - >/dev/null
  # only main may deploy to staging/prod
  gh api -X POST "repos/$ORG/$REPO/environments/$env/deployment-branch-policies" -f name=main -f type=branch >/dev/null 2>&1 || true
done

# ---------------------------------------------------------------- 5. CODEOWNERS
say "Next step for you: CODEOWNERS uses @ORG_NAME. Fix it with a PR:"
echo "   sed -i '' 's/ORG_NAME/$ORG/g' .github/CODEOWNERS"
echo
echo "Done. Check: https://github.com/$ORG/$REPO/settings"
