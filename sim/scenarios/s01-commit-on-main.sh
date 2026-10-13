#!/usr/bin/env bash
source "$(dirname "$0")/../lib.sh"
reset_world
# Bob forgot to create a branch and committed straight on his local main.
sedi bob-dev 's/"WELCOME5": 5,  # 5% off/"WELCOME5": 5,  # 5% off\n    "STUDENT20": 20,  # 20% off for students/' app/pricing.py
as bob-dev commit -qam "feat: add STUDENT20 code"
write_file bob-dev tests/unit/test_student.py <<'PY'
import unittest
from app.pricing import calculate_total


class StudentTests(unittest.TestCase):
    def test_student20(self):
        self.assertEqual(calculate_total(100, "STUDENT20"), 80)
PY
as bob-dev add -A && as bob-dev commit -qm "test: STUDENT20"

banner "SCENARIO 1 - Bob committed on main by mistake"
cat <<TXT
WHO:     Bob (Developer)          FOLDER: $WS/bob-dev
PROBLEM: Bob made 2 commits directly on his local 'main'. On GitHub the push is
         REJECTED (main is protected), and his main is now different from origin/main.
TASK:    Move both commits to a new branch, reset main to origin/main, push the branch.
GUIDE:   docs/SCENARIOS.md -> Scenario 1
TXT
as bob-dev log --oneline -3
