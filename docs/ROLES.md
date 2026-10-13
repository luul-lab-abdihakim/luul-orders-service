# Team, roles and permissions: luul-orders-service

The team works **trunk-based**: one protected `main`, small PRs, feature flags, and every merge flows through CI/CD.

## The people

| Person (simulator folder) | Role | GitHub team | Repo permission |
|---|---|---|---|
| **You** (`you-platform`) | Platform / DevOps engineer | `platform` | **Admin** |
| **Omar** (`omar-lead`) | Lead engineer | `leads` | **Maintain** |
| **Alice** (`alice-dev`) | Developer | `developers` | **Write** |
| **Bob** (`bob-dev`) | Developer | `developers` | **Write** |
| **Sara** (`sara-qa`) | QA engineer | `qa` | **Write** |

GitHub repo roles, from least to most power: **Read → Triage → Write → Maintain → Admin**.
Rule: give each team the **least** power it needs (*principle of least privilege*).

## What each role can do

| Action | Developer | QA | Lead | Platform |
|---|:-:|:-:|:-:|:-:|
| Clone, create branches, push branches | ✅ | ✅ | ✅ | ✅ |
| Open PRs, review PRs | ✅ | ✅ | ✅ | ✅ |
| Push directly to `main` | ❌ | ❌ | ❌ | ❌ (only break-glass bypass, audited) |
| Merge a PR (after checks + approvals) | ✅ | ✅ | ✅ | ✅ |
| Approve changes to `app/pricing.py` (money logic) | ❌ | ❌ | ✅ | ❌ |
| Approve changes to `tests/e2e/` | ❌ | ✅ | ❌ | ❌ |
| Approve turning a feature flag on (`config/flags.json`) | ❌ | ✅ + | ✅ (both) | ❌ |
| Approve changes to `.github/`, `Dockerfile`, `platform/` | ❌ | ❌ | ❌ | ✅ |
| Approve a **prod** deployment | ❌ | ❌ | ✅ | ✅ |
| Manage releases/tags, labels, milestones | ❌ | ❌ | ✅ | ✅ |
| Change repo settings, rulesets, environments, secrets | ❌ | ❌ | ❌ | ✅ |
| Add/remove people from teams (onboarding/offboarding) | ❌ | ❌ | ❌ | ✅ (org owner) |

## How the rules are enforced (who builds them: **you**)

| Guardrail | File / setting | Enforces |
|---|---|---|
| Ruleset `protect-trunk` | `platform/setup-org.sh`, `platform/terraform/main.tf` | No direct push, no force-push, no delete, linear history, 1 approval, code-owner review, last-push approval, all conversations resolved |
| Required status checks | same ruleset | `unit-tests` (devs), `e2e-tests` (QA), `docker-build` + `secret-scan` (platform). Branch must be up to date |
| CODEOWNERS | `.github/CODEOWNERS` | The *right* people approve the *right* files |
| Environments | `dev` auto, `staging` main-only, `prod` main-only + leads/platform approval | Only reviewed code reaches prod, and only the right people can release it |
| Settings per environment | `deploy/dev.env`, `deploy/staging.env`, `deploy/prod.env` (platform + leads own them) | A feature can be ON in dev/staging and OFF in prod. Same image, different settings |
| Squash-merge only + auto-delete branches | repo settings | One commit per PR on trunk, no stale branches |
| Secret scanning + push protection + `secret-scan` job + pre-commit hook | settings, `ci.yml`, `scripts/install-hooks.sh` | Keys never reach GitHub |
| Dependabot | `.github/dependabot.yml` | Actions and base images stay patched |

## The flow of one change (who does what)

1. **Developer** creates `feat/LUUL-123-x` from the latest `main`, codes, puts unfinished work behind a flag, and opens a PR.
2. **CI** runs `unit-tests`, `e2e-tests`, `docker-build` and `secret-scan`. All are required.
3. **CODEOWNERS** auto-requests reviewers: a lead for pricing, QA for e2e, platform for pipelines.
4. **Merge** (squash). Then **CD** builds one image `:<sha>` → dev → staging (QA's e2e tests run against staging).
5. **Lead or Platform** approves the `prod` deployment.
6. **Release the feature:** a PR flips the flag in `config/flags.json` and needs **lead + QA** approval.
