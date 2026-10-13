#!/usr/bin/env bash
source "$(dirname "$0")/../lib.sh"
reset_world
# Alice and Bob change the same discount in parallel.
as alice-dev switch -qc feat/LUUL-210-luul10-15
sedi alice-dev 's/"LUUL10": 10,   # 10% off/"LUUL10": 15,   # 15% off/' app/pricing.py
sedi alice-dev 's/calculate_total(100, "LUUL10"), 90)/calculate_total(100, "LUUL10"), 85)/' tests/unit/test_pricing.py
sedi alice-dev 's/calculate_total(100, "luul10"), 90)/calculate_total(100, "luul10"), 85)/' tests/unit/test_pricing.py
sedi alice-dev 's/calculate_total(1000, "LUUL10", {"discounts_v2": True}), 850)/calculate_total(1000, "LUUL10", {"discounts_v2": True}), 800)/' tests/unit/test_pricing.py
sedi alice-dev 's/self.assertEqual(body\["total"\], 180)/self.assertEqual(body["total"], 170)/' tests/e2e/test_api.py
as alice-dev commit -qam "feat(LUUL-210): LUUL10 gives 15%"
merge_to_main alice-dev                       # Alice's PR was merged first

as bob-dev switch -qc feat/LUUL-211-luul10-12
sedi bob-dev 's/"LUUL10": 10,   # 10% off/"LUUL10": 12,   # 12% off\n    "SUMMER20": 20, # summer campaign/' app/pricing.py
sedi bob-dev 's/calculate_total(100, "LUUL10"), 90)/calculate_total(100, "LUUL10"), 88)/' tests/unit/test_pricing.py
write_file bob-dev tests/unit/test_summer.py <<'PY'
import unittest
from app.pricing import calculate_total


class SummerTests(unittest.TestCase):
    def test_summer20(self):
        self.assertEqual(calculate_total(100, "SUMMER20"), 80)
PY
as bob-dev add -A && as bob-dev commit -qm "feat(LUUL-211): LUUL10 12% + new SUMMER20 code"
as bob-dev push -qu origin feat/LUUL-211-luul10-12

banner "SCENARIO 2 - Merge conflict between two developers"
cat <<TXT
WHO:     Bob (Developer)          FOLDER: $WS/bob-dev
PROBLEM: Alice's PR (LUUL10 = 15%) is already merged. Bob's PR (LUUL10 = 12%) now
         conflicts. GitHub says: "This branch has conflicts that must be resolved".
TASK:    Ask the lead (Omar) which value is right. Omar says: "LUUL10 stays 15% (product
         agreed), but KEEP Bob's new SUMMER20 code". Rebase Bob's branch on origin/main,
         resolve by keeping BOTH, run tests, push safely.
GUIDE:   docs/SCENARIOS.md -> Scenario 2
TXT
