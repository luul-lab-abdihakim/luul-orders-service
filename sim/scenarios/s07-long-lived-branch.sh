#!/usr/bin/env bash
source "$(dirname "$0")/../lib.sh"
reset_world
# Bob worked 2 weeks alone on one big branch that mixes 4 different things.
as bob-dev switch -qc feat/big-bang
sedi bob-dev 's/"WELCOME5": 5,  # 5% off/"WELCOME5": 5,  # 5% off\n    "BLACKFRIDAY": 30,  # 30% off/' app/pricing.py
write_file bob-dev tests/unit/test_blackfriday.py <<'PY'
import unittest
from app.pricing import calculate_total


class BlackFridayTests(unittest.TestCase):
    def test_blackfriday(self):
        self.assertEqual(calculate_total(100, "BLACKFRIDAY"), 70)
PY
as bob-dev add -A && as bob-dev commit -qm "feat: BLACKFRIDAY code"
write_file bob-dev docs/API.md <<'MD'
# luul-orders-service API
- GET /health
- GET /version
- GET /price?amount=<number>&code=<code>
MD
as bob-dev add -A && as bob-dev commit -qm "docs: API reference"
sedi bob-dev 's/"discounts_v2": false/"discounts_v2": true/' config/flags.json
as bob-dev commit -qam "chore: turn on discounts_v2 so I can test"
cat >> "$WS/bob-dev/tests/e2e/test_api.py" <<'PY'


class BlackFridayApi(unittest.TestCase):
    def test_blackfriday_api(self):
        self.assertEqual(get("/price?amount=100&code=BLACKFRIDAY")[1]["total"], 70)
PY
as bob-dev commit -qam "test: e2e BLACKFRIDAY"
as bob-dev push -qu origin feat/big-bang

# meanwhile the rest of the team kept merging small PRs
as alice-dev switch -qc docs/changelog
write_file alice-dev CHANGELOG.md <<<'# Changelog'
as alice-dev add -A && as alice-dev commit -qm "docs: start changelog" && merge_to_main alice-dev
as sara-qa switch -qc qa/readme
write_file sara-qa tests/e2e/README.md <<<'Run: make test-e2e  (BASE_URL=... to test an environment)'
as sara-qa add -A && as sara-qa commit -qm "docs: how to run e2e" && as sara-qa pull -q --rebase origin main && merge_to_main sara-qa

banner "SCENARIO 7 - A 2-week 'big bang' branch"
cat <<TXT
WHO:     Bob (Developer) + Omar (Lead)     FOLDER: $WS/bob-dev
PROBLEM: feat/big-bang is old, has 4 unrelated commits, and one of them turns ON an
         unfinished feature flag in production. Omar refuses to review it.
TASK:    Split it into small PRs from the latest main (trunk-based way), drop the
         flag change, and delete the big branch.
GUIDE:   docs/SCENARIOS.md -> Scenario 7
TXT
as bob-dev log --oneline origin/main..feat/big-bang
