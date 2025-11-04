#!/usr/bin/env bash
set -euo pipefail

REMOTE="${REMOTE:-upstream}"
LOCAL_BRANCH="${LOCAL_BRANCH:-main}"
UPSTREAM_BRANCH="${UPSTREAM_BRANCH:-}"   # leave blank to auto-detect

# ensure we're in a git repo
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "Not a git repo"; exit 1; }

# auto-detect upstream default branch if not provided
if [ -z "$UPSTREAM_BRANCH" ]; then
  UPSTREAM_BRANCH="$(git ls-remote --symref "$REMOTE" HEAD | awk '/^ref:/ {print $3}' | sed 's#refs/heads/##')"
  [ -n "$UPSTREAM_BRANCH" ] || { echo "Could not detect upstream default branch"; exit 1; }
fi

echo "→ Checking out $LOCAL_BRANCH"
git checkout "$LOCAL_BRANCH"

echo "→ Fetching $REMOTE/$UPSTREAM_BRANCH"
git fetch "$REMOTE" "$UPSTREAM_BRANCH"

echo "→ Merging $REMOTE/$UPSTREAM_BRANCH into $LOCAL_BRANCH"
set +e
git merge "$REMOTE/$UPSTREAM_BRANCH"
rc=$?
set -e

if [ $rc -ne 0 ]; then
  echo
  echo "⚠️  Merge conflicts detected."
  echo "   Resolve conflicts, then run:"
  echo "     git add -A && git commit"
  echo "     git push origin $LOCAL_BRANCH"
  exit $rc
fi

echo "→ Pushing to origin/$LOCAL_BRANCH"
git push origin "$LOCAL_BRANCH"

echo "✅ Synced and pushed."
