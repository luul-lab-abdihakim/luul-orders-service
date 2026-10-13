# luul-orders-service: team trunk-based project

A practice project that copies how a real team at **Luul Solutions** works with **trunk-based development**:
developers, QA, lead engineers and a platform engineer (**you**), each with their own permissions, plus **10 real problems** with tested solutions.

```
Developer branch ─► PR ─► CI (unit · e2e · docker · secret-scan) ─► CODEOWNERS review ─► squash merge to main
                                                                                             │
                     prod ◄── lead/platform approval ◄── staging (QA e2e) ◄── dev ◄── build once :sha
```

## Start here (in this order)

The **PDF has everything**: `docs/Luul-Team-Trunk-Based-Project.pdf`. The `.md` files are the same content as plain text.

1. **Learn the team:** PDF Part A (sections 1-4), or `docs/ROLES.md`
2. **Learn the developers' side:** PDF Part B (sections 5-8), or `docs/DEVELOPER-VIEW.md`
3. **Create the team on your Mac** (once): `./sim/create-team.sh --local`
4. **Do the developer lab:** PDF section 6
5. **Solve the 10 real problems:** `./sim/scenarios/s01-commit-on-main.sh` ... `s10-...`, with solutions in PDF "Scenarios", or `docs/SCENARIOS.md`
6. **Do it on real GitHub:** PDF section 10, or `docs/GITHUB-MODE.md`
7. **Practise interviews:** PDF section 12 (54 Q&A), or `docs/INTERVIEW-QA.md`. Print `docs/Interview-Practice-Sheet.pdf`
8. **Update your CV:** PDF section 11, or `docs/CV.md`

Start over at any time: `./sim/reset.sh`

## What's inside

| Path | What | Owner (CODEOWNERS) |
|---|---|---|
| `app/pricing.py` | Discount logic + `discounts_v2` feature flag | leads |
| `app/main.py` | HTTP API: `/health`, `/version`, `/price` | developers |
| `config/flags.json` | Feature flags (turning one ON needs lead + QA) | leads + qa |
| `deploy/<env>.env` | Per-environment settings (flags ON in dev/staging, OFF in prod) | platform + leads |
| `tests/unit/` | Unit tests | developers |
| `tests/e2e/` | End-to-end API tests (also run against staging) | qa |
| `.github/workflows/ci.yml` | Required checks on every PR + merge queue | platform |
| `.github/workflows/cd.yml` | Build once → dev → staging → prod (approval) + rollback by SHA | platform |
| `.github/workflows/release.yml` | Tag `v*.*.*` → GitHub Release | platform |
| `.github/CODEOWNERS` | Who approves which files | platform + leads |
| `platform/setup-org.sh` | Teams, permissions, ruleset, environments (gh CLI) | platform |
| `platform/terraform/` | The same thing as code (Terraform GitHub provider) | platform |
| `scripts/install-hooks.sh` | Pre-commit hook: blocks commits on main, secrets, big files | platform |
| `sim/` | Team simulator: 5 people, 10 scenarios, reset | |
| `docs/dev-lab-solution/` | Reference solution for the developer lab (`/orders/summary`) | |

## Commands

```bash
make test        # unit + e2e
make run         # http://localhost:8080/price?amount=100&code=LUUL10
make hooks       # install the team's pre-commit hook
make build       # docker image tagged with the commit SHA
```
