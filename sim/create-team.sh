#!/usr/bin/env bash
# Create one local clone per team member, each with their own git identity.
#
#   ./sim/create-team.sh --local                # offline: a local folder acts as "GitHub"
#   ./sim/create-team.sh <git-remote-url>       # real GitHub repo in your sandbox org
#
# Result (next to this project):
#   luul-team-workspace/
#     github-origin.git   (only with --local)
#     you-platform/  alice-dev/  bob-dev/  sara-qa/  omar-lead/
source "$(dirname "$0")/lib.sh"
TARGET="${1:?usage: $0 --local | <git-remote-url>}"

if [ -e "$WS" ]; then
  echo "$WS already exists. Delete it first if you want to start over:  rm -rf \"$WS\""
  exit 1
fi
mkdir -p "$WS"

if [ "$TARGET" = "--local" ]; then
  REMOTE="$WS/github-origin.git"
  git init -q --bare -b main "$REMOTE"
  # seed "GitHub" with the project
  tmp="$(mktemp -d)"
  (cd "$PROJECT_DIR" && git ls-files >/dev/null 2>&1 && git archive HEAD | tar -x -C "$tmp") 2>/dev/null \
    || rsync -a --exclude .git --exclude '__pycache__' --exclude '.terraform' "$PROJECT_DIR/" "$tmp/"
  git -C "$tmp" init -q -b main
  git -C "$tmp" -c user.name="Abdihakim (Platform)" -c user.email=platform@luul.lab add -A
  git -C "$tmp" -c user.name="Abdihakim (Platform)" -c user.email=platform@luul.lab commit -q -m "chore: initial luul-orders-service"
  git -C "$tmp" tag sim-start
  git -C "$tmp" push -q "$REMOTE" main sim-start
  rm -rf "$tmp"
else
  REMOTE="$TARGET"
fi

while IFS='|' read -r dir name email role; do
  git clone -q "$REMOTE" "$WS/$dir"
  git -C "$WS/$dir" config user.name "$name"
  git -C "$WS/$dir" config user.email "$email"
  git -C "$WS/$dir" config pull.rebase true
  printf "  %-14s %-24s %s\n" "$dir" "$name" "$role"
done <<< "$PEOPLE"

echo
echo "Team workspace ready: $WS"
echo "Open a terminal tab per person, e.g.:  cd \"$WS/alice-dev\""
echo "Then run a scenario:                   ./sim/scenarios/s01-commit-on-main.sh"
