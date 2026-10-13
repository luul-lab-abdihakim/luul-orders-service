#!/usr/bin/env bash
source "$(dirname "$0")/../lib.sh"
reset_world
# Sara writes 2 new e2e tests, then wipes them with reset --hard.
as sara-qa switch -qc qa/LUUL-250-more-e2e
cat >> "$WS/sara-qa/tests/e2e/test_api.py" <<'PY'


class MoreApiTests(unittest.TestCase):
    def test_version_endpoint(self):
        status, body = get("/version")
        self.assertEqual(status, 200)
        self.assertIn("commit", body)
PY
as sara-qa commit -qam "test(LUUL-250): e2e for /version"
cat >> "$WS/sara-qa/tests/e2e/test_api.py" <<'PY'


class PriceEdgeCases(unittest.TestCase):
    def test_zero_amount(self):
        self.assertEqual(get("/price?amount=0")[1]["total"], 0)
PY
as sara-qa commit -qam "test(LUUL-250): e2e for amount=0"
as sara-qa reset -q --hard origin/main

banner "SCENARIO 6 - QA lost a day of work"
cat <<TXT
WHO:     Sara (QA)                FOLDER: $WS/sara-qa
PROBLEM: Sara ran 'git reset --hard origin/main' to "clean up" and her 2 commits
         with new e2e tests are gone. git log does not show them.
TASK:    Get the 2 commits back.
GUIDE:   docs/SCENARIOS.md -> Scenario 6
TXT
