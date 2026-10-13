# Incident drills (game days)

Each drill script reproduces a real incident in a simulated 5-person team. The runbook below resolves it.
Every runbook below is tested end to end.

```bash
# from the repository root
./sim/create-team.sh --local          # once: creates ../luul-team-workspace with 5 people
./sim/scenarios/s01-commit-on-main.sh # start a scenario (it resets everything first)
```
`W=../luul-team-workspace` (the folder with every team member's clone, created next to the repo).
Every scenario starts with a fresh world, so each drill can be repeated. To reset by hand: `./sim/reset.sh`.

> In **local mode**, "merge the PR" means `git push origin HEAD:main`. On real GitHub you would open a PR (`gh pr create`) and merge after checks and approvals. See `docs/GITHUB-MODE.md`.

---

## Scenario 1: Bob committed on `main` by mistake
**Role:** Developer · **Folder:** `$W/bob-dev` · **Frequency:** common

**Problem:** Bob forgot to branch. He has 2 commits on local `main`. On GitHub, `git push` is rejected:
`remote: error: GH013: Repository rule violations found for refs/heads/main. Changes must be made through a pull request.`

**Fix:**
```bash
cd $W/bob-dev
git status -sb                               # "## main...origin/main [ahead 2]"
git switch -c feat/LUUL-201-student20        # 1. a branch that points at the 2 commits
git switch main
git reset --hard origin/main                 # 2. main goes back to match GitHub
git switch feat/LUUL-201-student20
make test
git push -u origin feat/LUUL-201-student20   # 3. now open a PR
```
**Why it works:** a branch is just a pointer. The new branch keeps the commits, and the reset only moves `main`.
**Prevent it (platform):** the ruleset rejects pushes to main. `make hooks` installs a pre-commit hook that says *"do not commit on main"*.
**Key point:** *"I move the commits to a feature branch, reset local main to origin/main, and open a PR. Our ruleset blocks direct pushes to main, and our pre-commit hook catches it even earlier."*

---

## Scenario 2: Merge conflict between two developers
**Roles:** Developer + Lead · **Folder:** `$W/bob-dev`

**Problem:** Alice's PR changed `LUUL10` to 15% and was merged. Bob's PR changes `LUUL10` to 12% **and** adds a new `SUMMER20` code on the same lines, so the two PRs conflict. Omar (lead) decides: **keep 15%, and keep Bob's SUMMER20.**

**Fix:**
```bash
cd $W/bob-dev
git fetch origin
git rebase origin/main            # CONFLICT in app/pricing.py and tests/unit/test_pricing.py
git status                        # "both modified" = UU
```
Open `app/pricing.py`:
```
<<<<<<< HEAD                       <- during a REBASE, HEAD = origin/main (Alice)
    "LUUL10": 15,   # 15% off
=======
    "LUUL10": 12,   # 12% off      <- Bob's commit
    "SUMMER20": 20, # summer campaign
>>>>>>> 5f100e4 (feat(LUUL-211): ...)
```
Edit it so it keeps **both** decisions, and delete the 3 marker lines:
```python
    "LUUL10": 15,   # 15% off
    "SUMMER20": 20, # summer campaign
```
For the test file, take main's version (Alice's 15% tests):
```bash
git checkout --ours tests/unit/test_pricing.py   # in a rebase, "ours" = the branch you rebase ONTO
git add app/pricing.py tests/unit/test_pricing.py
git rebase --continue
git commit --amend -m "feat(LUUL-211): add SUMMER20 code"   # message no longer says 12%
make test                                        # must be green before you push
git push --force-with-lease                      # safe: fails if someone else pushed to your branch
```
**Careful:** in a **merge**, "ours" = your branch. In a **rebase**, "ours" = the branch you rebase onto. People mix this up all the time.
**Prevent it:** small PRs that merge the same day. Rebase on `main` every morning (`git pull --rebase origin main`).
**Key point:** *"I rebase on main, resolve with the other author or the lead when it's a business decision, run tests locally, and push with --force-with-lease. Trunk-based development keeps conflicts small because branches live hours, not weeks."*

---

## Scenario 3: `main` is RED after two green PRs
**Roles:** Platform (you) + Developers · **Folder:** `$W/you-platform`

**Problem:** Alice replaced `WELCOME5` with `WELCOME10`. Bob added a test for `WELCOME5`. Each PR was green against the *old* main. There's no textual conflict, but together they break `main`. CD is red, and **nobody can ship**.

**Fix: make main green first, then fix properly.**
```bash
cd $W/you-platform
git pull
make test-unit                         # FAILS: test_welcome5
git log --oneline -5
git bisect start HEAD sim-start        # bad = now, good = last known good
git bisect run make test-unit          # Git tests commits for you -> "<sha> is the first bad commit"
git bisect reset
git switch -c revert/LUUL-221
git revert <sha-from-bisect>           # undo Bob's commit with a NEW commit (history kept)
make test-unit                         # green again
git push origin HEAD:main              # (GitHub: PR + fast review, "revert first, ask later")
```
Then Bob fixes his test the right way in a new PR: `WELCOME10` → `calculate_total(200, "WELCOME10") == 180`.

**Prevent it (platform):** in the ruleset, set **"Require branches to be up to date before merging"** (`strict_required_status_checks_policy: true`, already in `setup-org.sh`). Even better, use a **merge queue**: GitHub tests each PR *combined with* the latest main before merging. `ci.yml` already listens to `merge_group`.
**Key point:** *"A broken trunk blocks everyone, so the rule is: revert first, then fix forward. I use git bisect to find the commit fast. Then I prevent semantic conflicts with up-to-date checks and a merge queue."*

---

## Scenario 4: A secret was pushed
**Roles:** Developer + Platform/Security · **Folder:** `$W/bob-dev`

**Problem:** the first commit of Bob's pushed branch contains `config/aws.env` with an AWS key. The `secret-scan` check failed.

**Step 1, ALWAYS first: rotate the key.** Assume it's stolen, because bots scan GitHub within seconds.
```bash
aws iam create-access-key --user-name luul-export          # new key -> store in GitHub Secrets / Vault
aws iam delete-access-key --user-name luul-export --access-key-id AKIA...OLD
```
**Step 2: remove it from the branch history** (the branch isn't merged yet):
```bash
cd $W/bob-dev
git log --oneline --stat origin/main..HEAD   # see which commits contain aws.env
git reset --soft origin/main                 # un-commit the whole branch, keep the changes staged
git rm --cached config/aws.env               # take the secret out of the commit
rm config/aws.env
echo "*.env" >> .gitignore && git add .gitignore
git commit -m "feat(LUUL-230): export module (credentials from env)"
git push --force-with-lease                  # replace the branch on GitHub
```
**If it was already merged to main:** rotate (done), then rewrite history with `git filter-repo --path config/aws.env --invert-paths`. Coordinate with the whole team (everyone must re-clone) and ask GitHub Support to purge cached views. That's why **rotation** is the real fix.

**Prevent it (platform):** push protection (`setup-org.sh`), the `secret-scan` job (gitleaks), the pre-commit hook (`make hooks`), and **OIDC** so CI never needs static cloud keys.
**Key point:** *"Rotate first, clean history second. A key on GitHub for even a minute is compromised. Then add push protection and gitleaks, and move CI to OIDC so there are no long-lived keys."*

---

## Scenario 5: A 12 MB database dump in a commit
**Role:** Developer · **Folder:** `$W/alice-dev`

**Problem:** Alice's last commit (not pushed) contains `data/prod-dump.sql` together with her real code change. It's big, and it may contain customer data.
```bash
cd $W/alice-dev
git show --stat HEAD                     # see the dump in the commit
git rm --cached data/prod-dump.sql       # remove from the commit, keep it on disk
rm -rf data/                             # and delete it: prod data does not belong on a laptop
printf "data/\n*.sql\n" >> .gitignore
git add .gitignore
git commit --amend --no-edit             # rewrite the LAST commit (OK: not pushed yet)
git show --stat HEAD                     # only code + .gitignore now
make test
```
**Prevent it:** the pre-commit hook blocks files over 5 MB. For big files you really need, use **Git LFS** (`git lfs track "*.bin"`) or object storage (S3).
**Key point:** *"Since it wasn't pushed, I amended the commit. If it had been pushed, I'd rewrite the branch with --force-with-lease, or use git filter-repo if it reached main. With possible customer data, it's also a data-protection incident."*

---

## Scenario 6: QA lost a day of work
**Role:** QA · **Folder:** `$W/sara-qa`

**Problem:** Sara ran `git reset --hard origin/main` and her 2 new e2e test commits disappeared.
```bash
cd $W/sara-qa
git reflog                       # every move of HEAD, including the "lost" commits
# 9d281fc HEAD@{1}: commit: test(LUUL-250): e2e for amount=0     <- this is what we want
git reset --hard HEAD@{1}        # or: git switch -c rescue 9d281fc
git log --oneline -3             # both commits are back
make test-e2e
git push -u origin qa/LUUL-250-more-e2e     # push often: GitHub is your backup
```
**Key point:** *"git reflog records every HEAD movement locally. Lost commits stay recoverable for 30 days by default, so committed work is almost never lost. I find the commit and reset or branch to it."*

---

## Scenario 7: A 2-week "big bang" branch
**Roles:** Developer + Lead · **Folder:** `$W/bob-dev`

**Problem:** `feat/big-bang` is old and has 4 unrelated commits. One of them turns ON the unfinished `discounts_v2` flag. Omar refuses to review it. In trunk-based development, **you split it**.
```bash
cd $W/bob-dev
git fetch
git log --oneline origin/main..feat/big-bang
#   e529d29 test: e2e BLACKFRIDAY
#   5ceaab6 chore: turn on discounts_v2 so I can test     <- must NOT ship
#   3bdb9a5 docs: API reference
#   c465100 feat: BLACKFRIDAY code

# PR 1: the feature + its tests, from the LATEST main
git switch -c feat/LUUL-280-blackfriday origin/main
git cherry-pick c465100 e529d29
make test
git push -u origin HEAD

# PR 2: docs on their own
git switch -c docs/LUUL-281-api-docs origin/main
git cherry-pick 3bdb9a5
git push -u origin HEAD

# The flag commit is dropped. To test locally, use: FLAG_DISCOUNTS_V2=true make run
git push origin --delete feat/big-bang
git branch -D feat/big-bang
```
**Prevent it:** the CI `branch-age` warning (in luul-trunk-lab), the PR template checklist, and the team agreement: *merge at least daily, hide unfinished work behind flags*.
**Key point:** *"I split long branches into small PRs by cherry-picking onto fresh branches from main, so each one has one purpose and is easy to review and revert. Flags are turned on in their own PR, approved by the lead and QA."*

---

## Scenario 8: QA finds a bug in staging. Which commit broke it?
**Roles:** QA + Platform · **Folder:** `$W/sara-qa`

**Problem:** `GET /price?amount=99.50&code=LUUL10` returns **400** (`invalid literal for int()`). In `v1.0.0` it returned `89.55`. Six commits have been merged since, and all tests are green because no test covers decimals.
```bash
cd $W/sara-qa
git pull
# 1. A script that exits 0 = good, 1 = bad
cat > /tmp/repro.sh <<'EOF'
#!/usr/bin/env bash
python3 -c "
from app.main import route
s, b = route('/price?amount=99.50&code=LUUL10')
raise SystemExit(0 if s == 200 and b['total'] == 89.55 else 1)"
EOF
chmod +x /tmp/repro.sh

# 2. Binary search: bad = HEAD, good = v1.0.0
git bisect start HEAD v1.0.0
git bisect run /tmp/repro.sh       # -> "79ede4b refactor: simplify amount parsing" is the first bad commit
git show <that-sha>                # int(...) instead of float(...)
git bisect reset

# 3. Fix forward + regression test (QA owns tests/e2e)
git switch -c fix/LUUL-290-decimal-amounts
#   app/main.py: change int(...) back to float(...)
cat >> tests/e2e/test_api.py <<'EOF'


class RegressionTests(unittest.TestCase):
    def test_decimal_amount_LUUL_290(self):
        self.assertEqual(get("/price?amount=99.50&code=LUUL10")[1]["total"], 89.55)
EOF
make test
git commit -am "fix(LUUL-290): accept decimal amounts + regression test"
git push -u origin HEAD
```
**Key point:** *"QA reproduces the bug as a test, then git bisect finds the guilty commit in a few steps, even among hundreds. We fix forward and keep the regression test so it can't come back."*

---

## Scenario 9: Hotfix for a version already in production
**Roles:** Lead / Platform · **Folder:** `$W/omar-lead`

**Problem:** production runs `v1.1.0` from `release/1.1`. Customers type `" LUUL10 "` with spaces and get no discount. Bob's fix is already merged on **main**, but main also has new work that isn't ready, so we can't ship main today.
```bash
cd $W/omar-lead
git fetch --tags
git log --oneline v1.1.0..origin/main          # find the fix commit: "fix(LUUL-261): ..."
git switch release/1.1                         # (first time: git switch -c release/1.1 origin/release/1.1)
git cherry-pick -x <fix-sha>                   # -x writes "cherry picked from <sha>" in the message
make test
git push
git tag -a v1.1.1 -m "Release 1.1.1: ignore spaces in discount codes"
git push origin v1.1.1                         # release.yml creates the GitHub Release
git log --oneline v1.1.0..v1.1.1               # ONLY the fix is in the release
```
**Rule:** fix on **trunk first**, then cherry-pick to the release branch. Never fix only the release branch, or the bug comes back in the next version.
**Key point:** *"We release from trunk with tags. When we must patch an older release, we cherry-pick the fix from main into the release branch, tag a patch version, and the pipeline ships it."*

---

## Scenario 10: Commits with the wrong author
**Role:** Developer · **Folder:** `$W/alice-dev`

**Problem:** Alice's new laptop isn't configured, so her 2 commits say `root <root@localhost>`.
```bash
cd $W/alice-dev
git log --format='%h %an <%ae> %s' origin/main..HEAD
git config user.name "Alice (Developer)"
git config user.email "alice@luul.lab"
git rebase origin/main --exec 'git commit --amend --no-edit --reset-author'
git log --format='%h %an <%ae> %s' origin/main..HEAD     # fixed on both commits
```
**Prevent it:** onboarding checklist (see GITHUB-MODE G6). The org can require **signed commits** (`git config commit.gpgsign true` with an SSH or GPG key), so GitHub shows "Verified".

---

## Quick reference: problem → command

| Problem | Command |
|---|---|
| Committed on main | `git switch -c feat/x` → `git switch main` → `git reset --hard origin/main` |
| Conflict | `git rebase origin/main` → edit → `git add` → `git rebase --continue` |
| Main is red | `git bisect run make test` → `git revert <sha>` |
| Secret pushed | **rotate** → `git reset --soft origin/main` → `git rm --cached` → `--force-with-lease` |
| Big file in last commit | `git rm --cached <file>` → `.gitignore` → `git commit --amend` |
| Lost commits | `git reflog` → `git reset --hard HEAD@{n}` |
| Long branch | `git switch -c small origin/main` → `git cherry-pick <shas>` |
| Who broke it? | `git bisect start HEAD <good>` → `git bisect run <test>` |
| Patch an old release | `git switch release/x` → `git cherry-pick -x <sha>` → tag |
| Wrong author | `git rebase origin/main --exec 'git commit --amend --no-edit --reset-author'` |
