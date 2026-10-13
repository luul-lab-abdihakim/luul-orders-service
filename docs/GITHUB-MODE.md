# GitHub setup: teams, permissions and approvals

How to stand up the platform guardrails in a GitHub organization: teams, rulesets, CODEOWNERS, environments and approvals. The incident drills in `SCENARIOS.md` run locally.

> ⚠️ Run this in a **sandbox organization**. Changing a production organization's settings requires approval. The scripts and Terraform refuse to run against `Luul-Solutions`.

## Setup (about 20 minutes, free)

0. **Give the GitHub CLI the extra permissions** (once): `gh auth refresh -h github.com -s admin:org,delete_repo`
1. **Create a sandbox org** in the browser: https://github.com/account/organizations/new?plan=free → name e.g. `luul-lab-abdihakim` → "belongs to: My personal account".
2. **Create the repo and push the project:**
   ```bash
   # from the repository root
   git init -b main && git add . && git commit -m "chore: initial luul-orders-service"
   gh repo create luul-lab-abdihakim/luul-orders-service --public --source=. --push
   ```
   (Public = free rulesets, environments with reviewers, and secret scanning.)
3. **Platform setup.** Pick ONE way:
   ```bash
   # a) script
   ./platform/setup-org.sh luul-lab-abdihakim luul-orders-service

   # b) Terraform ("GitHub as code", great for your CV)
   cd platform/terraform
   cp terraform.tfvars.example terraform.tfvars      # set org, and YOUR login as team members
   export GITHUB_TOKEN=$(gh auth token)
   terraform init && terraform plan                  # READ the plan
   terraform apply
   cd ../..
   # Terraform here manages teams, permissions, the ruleset and environments.
   # Set the repo's merge + security settings with gh (the script does this for you):
   gh repo edit luul-lab-abdihakim/luul-orders-service --enable-squash-merge --enable-merge-commit=false \
     --enable-rebase-merge=false --delete-branch-on-merge --allow-update-branch --enable-auto-merge
   echo '{"security_and_analysis":{"secret_scanning":{"status":"enabled"},"secret_scanning_push_protection":{"status":"enabled"}}}' \
     | gh api -X PATCH repos/luul-lab-abdihakim/luul-orders-service --input -
   ```
   Use only ONE way. If you ran the script first, Terraform fails with "name already exists". Delete the teams, ruleset and environments first, or use `terraform import`.
4. **Fix CODEOWNERS** in your first PR (good first trunk-based change):
   ```bash
   git switch -c chore/codeowners-org
   sed -i '' 's/ORG_NAME/luul-lab-abdihakim/g' .github/CODEOWNERS
   git commit -am "chore: point CODEOWNERS at our teams" && git push -u origin HEAD
   gh pr create --fill
   ```
5. **Real teammates (optional but best):** invite a friend or a second GitHub account. Put them in teams:
   `DEVELOPERS="friend-login" ./platform/setup-org.sh luul-lab-abdihakim luul-orders-service`
   Alone? You're an **org owner**, so you can use the ruleset **bypass** (break-glass) to merge your own PRs. Notice that GitHub logs every bypass.

### Operational notes (verified on GitHub)
- **A brand-new org can be slow at first.** The very first push or PR may start **no workflow run**. Wait a few minutes, or push another commit. After that, runs start within seconds.
- **Team members:** the script adds you to all 4 teams automatically (GitHub adds whoever creates a team). **Terraform does not**: put your login in `members` in `terraform.tfvars`, or the teams stay empty and **nobody can approve prod**. The deployment waits forever.
- **Set up protections BEFORE the first push.** The CD run from the very first push can reach prod without approval, because the prod environment didn't exist yet.
- **You cannot approve your own PR** (`Can not approve your own pull request`), so With a single maintainer you merge with `gh pr merge --squash --admin` after all checks are green. At work: never `--admin` to skip a red check.
- **`secret-scan` passes** even though Scenario 4 contains a fake AWS key, because `.gitleaks.toml` allowlists that one training file. Remove it from the allowlist and watch the scanner catch it.
- **Dependabot opens PRs by itself** within minutes (G9).
- **Prod waits for approval** from @leads or @platform (G3): Actions → the CD run → **Review deployments**.

## Operational scenarios

### G1: A developer pushes straight to main
```bash
git switch main && echo x >> README.md && git commit -am "oops" && git push
# remote: error: GH013: Repository rule violations found ... Changes must be made through a pull request.
```
Fix it like local Scenario 1. **Lesson:** the ruleset protects trunk even from admins, unless they deliberately bypass.

### G2: A developer edits the pipeline
Change `.github/workflows/ci.yml` in a PR. The PR shows **"Review required from @org/platform"** (CODEOWNERS).
**Lesson:** pipelines are production infrastructure. Only the platform team approves them.

### G3: Who may release to prod?
Merge a PR. Then **Actions → CD** runs dev → staging and **waits at `prod`**: *"Waiting for review: leads, platform"*. Click **Review deployments → Approve**. A developer sees the button disabled.
**Lesson:** environments + required reviewers = segregation of duties (an audit requirement in many companies).

### G4: Turning a feature on
```bash
git switch -c feat/LUUL-300-enable-discounts-v2 origin/main
sed -i '' 's/"discounts_v2": false/"discounts_v2": true/' config/flags.json
git commit -am "feat(LUUL-300): enable discounts_v2" && git push -u origin HEAD && gh pr create --fill
```
CODEOWNERS requests **leads + QA**. QA first tests in staging with `FLAG_DISCOUNTS_V2=true`.
**Lesson:** *deploy ≠ release*. Code was deployed weeks ago. This PR is the release.

### G5: Rollback a bad prod deploy
```bash
gh run list --workflow CD                       # find the last GOOD commit
gh workflow run CD -f sha=$(git rev-parse <good-short-sha>)   # needs the FULL 40-character ID
# then fix trunk:  git revert <bad-sha>  ->  PR
```
The rollback uses the code, QA tests **and** `deploy/*.env` of that old commit, so everything matches the old image. With a short ID like `62bd687` the checkout fails, because Git treats it as a branch name.

### G6: Onboarding and offboarding
```bash
# onboarding (platform)
gh api -X PUT orgs/<org>/teams/developers/memberships/<login> -f role=member
# new developer's laptop
ssh-keygen -t ed25519 -C "name@luul.com" && gh ssh-key add ~/.ssh/id_ed25519.pub
git config --global user.name "Name" && git config --global user.email "name@luul.com"
git clone git@github.com:<org>/luul-orders-service.git && cd luul-orders-service && make hooks
# offboarding (same day they leave): remove access, then rotate any shared secrets they knew
gh api -X DELETE orgs/<org>/memberships/<login>
```
With Terraform: add or remove the login in `var.teams` → PR → `terraform apply`. Access changes are then reviewed and audited.

### G7: Flaky e2e test blocks everyone
**Wrong:** remove `e2e-tests` from the required checks. **Right:** QA marks the test `@unittest.skip("flaky: LUUL-310")` in a PR (QA approves it via CODEOWNERS), opens a ticket, and fixes it within a set time.

### G8: Semantic conflict (local Scenario 3), the platform fix
Settings → Rules → `protect-trunk` → enable **Require merge queue**. Every PR is tested on top of the latest main before it lands.

### G9: Dependabot PR
Dependabot opens `Bump actions/checkout from 4 to 5`. CI runs, platform reviews (it's `.github/`), merge.

### G10: Emergency (break-glass)
Prod is down and CI is broken. An org admin can **bypass** the ruleset (the merge box shows "bypass rules"). It's logged in the org audit log. Afterwards: postmortem, and fix the cause.
