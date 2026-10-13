#!/usr/bin/env bash
# Shared helpers for the team simulator. Source it, don't run it.
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WS="${LUUL_WS:-$(cd "$PROJECT_DIR/.." && pwd)/luul-team-workspace}"

# folder | full name | email | role
PEOPLE="you-platform|Abdihakim (Platform)|platform@luul.lab|Platform/DevOps engineer (admin)
alice-dev|Alice (Developer)|alice@luul.lab|Developer (write)
bob-dev|Bob (Developer)|bob@luul.lab|Developer (write)
sara-qa|Sara (QA)|sara@luul.lab|QA engineer (write, owns tests/e2e)
omar-lead|Omar (Lead)|omar@luul.lab|Lead engineer (maintain, approves prod)"

# Run a git command as a person, e.g.:  as alice-dev commit -m "feat: x"
as() {
  local who="$1"; shift
  git -C "$WS/$who" "$@"
}

# Reset every clone to the latest origin/main and delete local branches (fresh start)
fresh_start() {
  while IFS='|' read -r dir _ _ _; do
    local repo="$WS/$dir"
    [ -d "$repo/.git" ] || continue
    git -C "$repo" rebase --abort >/dev/null 2>&1 || true
    git -C "$repo" merge --abort >/dev/null 2>&1 || true
    git -C "$repo" cherry-pick --abort >/dev/null 2>&1 || true
    git -C "$repo" bisect reset >/dev/null 2>&1 || true
    git -C "$repo" fetch -q --prune --prune-tags --tags origin
    git -C "$repo" switch -q -f main
    git -C "$repo" reset -q --hard origin/main
    git -C "$repo" clean -qfd
    git -C "$repo" for-each-ref --format='%(refname:short)' refs/heads | { grep -vx main || true; } | while read -r b; do git -C "$repo" branch -q -D "$b"; done
    git -C "$repo" stash clear
  done <<< "$PEOPLE"
}

# "Merge a PR" in local mode: push the person's current branch straight onto main
merge_to_main() {
  local who="$1"
  as "$who" push -q origin HEAD:main
}

banner() {
  echo
  echo "=================================================================="
  echo " $*"
  echo "=================================================================="
}

# Local mode only: put "GitHub" back to the starting commit, then fresh_start every clone.
reset_world() {
  local origin="$WS/github-origin.git"
  if [ ! -d "$origin" ]; then
    echo "Scenarios run in LOCAL mode (they rewrite history on purpose)."
    echo "First run:  ./sim/create-team.sh --local"
    exit 1
  fi
  git -C "$origin" update-ref refs/heads/main "$(git -C "$origin" rev-parse 'sim-start^{commit}')"
  git -C "$origin" for-each-ref --format='%(refname)' refs/heads refs/tags \
    | { grep -vx -e refs/heads/main -e refs/tags/sim-start || true; } \
    | while read -r ref; do git -C "$origin" update-ref -d "$ref"; done
  fresh_start
}

# Write a file inside a person's clone:  write_file alice-dev path/to/file <<< "content"
write_file() {
  mkdir -p "$(dirname "$WS/$1/$2")"
  cat > "$WS/$1/$2"
}

# Literal search & replace in a person's file, written like sed:  sedi alice-dev 's/old/new/' file
# (\/ \[ \] are unescaped, \n in the replacement is a newline). Fails loudly if "old" is missing.
sedi() {
  python3 - "$WS/$1/$3" "$2" <<'PY'
import re, sys
path, expr = sys.argv[1], sys.argv[2]
parts = re.split(r'(?<!\\)/', expr)
old, new = parts[1], parts[2]
unesc = lambda t: t.replace(r'\/', '/').replace(r'\[', '[').replace(r'\]', ']')
old, new = unesc(old), unesc(new).replace(r'\n', '\n')
text = open(path).read()
if old not in text:
    sys.exit(f"sedi: text not found in {path}: {old}")
open(path, 'w').write(text.replace(old, new, 1))
PY
}
