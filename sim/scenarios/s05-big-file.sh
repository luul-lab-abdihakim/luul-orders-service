#!/usr/bin/env bash
source "$(dirname "$0")/../lib.sh"
reset_world
# Alice accidentally commits a 12 MB database dump together with her code change.
as alice-dev switch -qc feat/LUUL-240-health-details
sedi alice-dev 's/return 200, {"status": "ok"}/return 200, {"status": "ok", "service": "luul-orders"}/' app/main.py
sedi alice-dev 's/self.assertEqual(get("\/health"), (200, {"status": "ok"}))/self.assertEqual(get("\/health"), (200, {"status": "ok", "service": "luul-orders"}))/' tests/e2e/test_api.py
mkdir -p "$WS/alice-dev/data" && head -c 12582912 /dev/urandom > "$WS/alice-dev/data/prod-dump.sql"
as alice-dev add -A && as alice-dev commit -qm "feat(LUUL-240): add service name to /health"

banner "SCENARIO 5 - A 12 MB file is in the commit"
cat <<TXT
WHO:     Alice (Developer)        FOLDER: $WS/alice-dev
PROBLEM: Alice's last commit (not pushed yet) contains data/prod-dump.sql (12 MB,
         and it could contain customer data!). It must never reach GitHub.
TASK:    Keep the code change, remove the dump from the commit, stop it happening again.
GUIDE:   docs/SCENARIOS.md -> Scenario 5
TXT
as alice-dev show --stat --oneline HEAD
