#!/usr/bin/env bash
source "$(dirname "$0")/../lib.sh"
reset_world
# v1.1.0 is in production from release/1.1. main has moved on. A bug fix lands on main.
as you-platform tag -a v1.1.0 -m "Release 1.1.0" && as you-platform push -q origin v1.1.0
as you-platform push -q origin v1.1.0^{commit}:refs/heads/release/1.1
as alice-dev switch -qc feat/LUUL-260-new-flag
sedi alice-dev 's/"discounts_v2": false/"discounts_v2": false,\n  "express_checkout": false/' config/flags.json
as alice-dev commit -qam "feat(LUUL-260): add express_checkout flag (off)" && merge_to_main alice-dev
as bob-dev pull -q && as bob-dev switch -qc fix/LUUL-261-strip-code
sedi bob-dev 's/percent = DISCOUNT_CODES.get((code or "").upper(), 0)/percent = DISCOUNT_CODES.get((code or "").strip().upper(), 0)/' app/pricing.py
write_file bob-dev tests/unit/test_strip.py <<'PY'
import unittest
from app.pricing import calculate_total


class StripTests(unittest.TestCase):
    def test_spaces_around_code(self):
        self.assertEqual(calculate_total(100, " LUUL10 "), 90)
PY
as bob-dev add -A && as bob-dev commit -qm "fix(LUUL-261): ignore spaces around discount code" && merge_to_main bob-dev
fresh_start

banner "SCENARIO 9 - Hotfix for a version already in production"
cat <<TXT
WHO:     Omar (Lead) / You (Platform)      FOLDER: $WS/omar-lead
PROBLEM: Customers on v1.1.0 type " LUUL10 " (with spaces) and get no discount.
         Bob's fix is already merged on MAIN. But main also has new unfinished work,
         so we cannot ship main today. Production runs from release/1.1.
TASK:    Put ONLY Bob's fix on release/1.1 and release v1.1.1.
GUIDE:   docs/SCENARIOS.md -> Scenario 9
TXT
as omar-lead log --oneline v1.1.0..origin/main
