#!/usr/bin/env bash
source "$(dirname "$0")/../lib.sh"
reset_world
# v1.0.0 was fine. 6 commits later QA finds a bug in staging. Which commit broke it?
as you-platform tag -a v1.0.0 -m "Release 1.0.0" && as you-platform push -q origin v1.0.0
# Each step: the person pulls the latest main, changes something, and it gets merged.
step() { as "$1" pull -q --rebase origin main; }
ship() { as "$1" add -A; as "$1" commit -qm "$2"; merge_to_main "$1"; }
step alice-dev; write_file alice-dev docs/runbook.md <<<'# Runbook'; ship alice-dev "docs: runbook"
step bob-dev;   sedi bob-dev 's/VERSION = "1.0.0"/VERSION = "1.0.1"/' app/main.py; ship bob-dev "chore: bump version"
step alice-dev; sedi alice-dev 's/        return 200, {"amount": amount, "code": code, "total": total}/        return 200, {"amount": amount, "code": code, "total": total, "currency": "USD"}/' app/main.py; ship alice-dev "feat: return currency"
step bob-dev;   sedi bob-dev 's/amount = float(query.get("amount", \["0"\])\[0\])/amount = int(query.get("amount", ["0"])[0])  # simplify/' app/main.py; ship bob-dev "refactor: simplify amount parsing"
step alice-dev; write_file alice-dev docs/oncall.md <<<'# On-call'; ship alice-dev "docs: on-call guide"
step bob-dev;   write_file bob-dev docs/API.md <<<'# API'; ship bob-dev "docs: api"
fresh_start

banner "SCENARIO 8 - QA bug in staging: which commit broke it?"
cat <<TXT
WHO:     Sara (QA) + You (Platform)        FOLDER: $WS/sara-qa
BUG:     GET /price?amount=99.50&code=LUUL10  returns 400 "invalid literal for int()".
         In v1.0.0 it returned total 89.55. All tests are green (no test covers decimals).
TASK:    1) Write a test that reproduces the bug.  2) Use git bisect to find the commit.
         3) Fix forward + keep the regression test.
GUIDE:   docs/SCENARIOS.md -> Scenario 8
TXT
as sara-qa log --oneline v1.0.0..origin/main
