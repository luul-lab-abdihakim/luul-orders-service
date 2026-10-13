#!/usr/bin/env bash
source "$(dirname "$0")/../lib.sh"
reset_world
# Two PRs are green on their own, but main breaks after both merge (no textual conflict!).
as alice-dev switch -qc feat/LUUL-220-welcome10
sedi alice-dev 's/"WELCOME5": 5,  # 5% off/"WELCOME10": 10,  # 10% off (replaces WELCOME5)/' app/pricing.py
as alice-dev commit -qam "feat(LUUL-220): replace WELCOME5 with WELCOME10"

as bob-dev switch -qc test/LUUL-221-welcome-tests
write_file bob-dev tests/unit/test_welcome.py <<'PY'
import unittest
from app.pricing import calculate_total


class WelcomeTests(unittest.TestCase):
    def test_welcome5(self):
        self.assertEqual(calculate_total(200, "WELCOME5"), 190)
PY
as bob-dev add -A && as bob-dev commit -qm "test(LUUL-221): cover WELCOME5 code"

# both PRs had green CI against the OLD main, both get merged
merge_to_main alice-dev
as bob-dev pull -q --rebase origin main
merge_to_main bob-dev

banner "SCENARIO 3 - main is RED after two green PRs"
cat <<TXT
WHO:     You (Platform) + Alice + Bob     FOLDER: $WS/you-platform
PROBLEM: CD failed on main: unit tests fail. Every PR was green. Nobody can ship now.
TASK:    Find the breaking commit, get main green FAST (revert), then fix it properly
         and add a guardrail so it cannot happen again.
GUIDE:   docs/SCENARIOS.md -> Scenario 3
TXT
