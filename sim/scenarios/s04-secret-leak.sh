#!/usr/bin/env bash
source "$(dirname "$0")/../lib.sh"
reset_world
# Bob commits an AWS key on his branch and pushes it.
as bob-dev switch -qc feat/LUUL-230-s3-export
write_file bob-dev config/aws.env <<'ENV'
AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
ENV
as bob-dev add -A && as bob-dev commit -qm "feat(LUUL-230): add S3 export config"
write_file bob-dev app/export.py <<'PY'
"""Export orders to S3 (credentials come from the environment, not from git)."""
import os

BUCKET = os.environ.get("EXPORT_BUCKET", "luul-orders-export")
PY
as bob-dev add -A && as bob-dev commit -qm "feat(LUUL-230): export module"
as bob-dev push -qu origin feat/LUUL-230-s3-export

banner "SCENARIO 4 - A secret was pushed"
cat <<TXT
WHO:     Bob (Developer) + You (Platform)     FOLDER: $WS/bob-dev
PROBLEM: The secret-scan job failed on Bob's PR: config/aws.env contains an AWS key.
         It is in the FIRST commit of the branch, and the branch is already pushed.
TASK:    1) Treat the key as stolen: rotate it.  2) Remove it from the branch history.
         3) Make sure it can't happen again.
GUIDE:   docs/SCENARIOS.md -> Scenario 4
TXT
as bob-dev log --oneline --stat origin/main..HEAD
