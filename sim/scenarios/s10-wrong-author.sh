#!/usr/bin/env bash
source "$(dirname "$0")/../lib.sh"
reset_world
# Alice's new laptop has the wrong git identity.
as alice-dev switch -qc feat/LUUL-270-readme
write_file alice-dev README.md <<<'# luul-orders-service'
as alice-dev add -A && as alice-dev -c user.name=root -c user.email=root@localhost commit -qm "docs: add README"
cat >> "$WS/alice-dev/README.md" <<<'Run with: make run'
as alice-dev -c user.name=root -c user.email=root@localhost commit -qam "docs: how to run"

banner "SCENARIO 10 - Commits with the wrong author"
cat <<TXT
WHO:     Alice (Developer)        FOLDER: $WS/alice-dev
PROBLEM: Alice's 2 commits show author "root <root@localhost>". The org requires
         a real identity (and the audit trail must show who did what).
TASK:    Fix her git identity and rewrite the author on both commits before pushing.
GUIDE:   docs/SCENARIOS.md -> Scenario 10
TXT
as alice-dev log --format='%h %an <%ae>  %s' origin/main..HEAD
