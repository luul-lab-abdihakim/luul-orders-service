#!/usr/bin/env bash
# Installs a pre-commit hook for every team member (platform team provides this).
# It blocks: commits directly on main, likely secrets, and files bigger than 5 MB.
set -euo pipefail
HOOK="$(git rev-parse --git-dir)/hooks/pre-commit"

cat > "$HOOK" <<'HOOK_EOF'
#!/usr/bin/env bash
branch=$(git symbolic-ref --short HEAD 2>/dev/null || echo "")
if [ "$branch" = "main" ]; then
  echo "BLOCKED: do not commit on main. Run: git switch -c feat/<ticket>-<name>"
  exit 1
fi

if git diff --cached -U0 | grep -E '^\+' | grep -Eq '(AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY-----|(password|secret|token)[[:space:]]*[:=][[:space:]]*["'"'"']?[A-Za-z0-9/+]{8,})'; then
  echo "BLOCKED: this commit looks like it contains a secret (key, password or token)."
  echo "Remove it, use GitHub Secrets / a vault, then: git restore --staged <file>"
  exit 1
fi

while IFS= read -r file; do
  [ -f "$file" ] || continue
  size=$(wc -c < "$file")
  if [ "$size" -gt 5242880 ]; then
    echo "BLOCKED: $file is $((size / 1024 / 1024)) MB. Big files do not belong in Git (use Git LFS or object storage)."
    exit 1
  fi
done < <(git diff --cached --name-only --diff-filter=AM)
HOOK_EOF

chmod +x "$HOOK"
echo "pre-commit hook installed in $HOOK"
