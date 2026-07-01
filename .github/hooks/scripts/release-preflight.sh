#!/usr/bin/env bash
# .github/hooks/scripts/release-preflight.sh
#
# Pre-flight check for react-manifest-rails releases.
# Called by the release-preflight hook before any `git tag v*` or
# `git push ... v*` command runs.
#
# Exit 0 → allow the command.
# Exit 1 → block the command (hook prints the error to the agent).

set -euo pipefail

REPO_ROOT="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
VERSION_FILE="$REPO_ROOT/lib/react_manifest/version.rb"
CHANGELOG_FILE="$REPO_ROOT/CHANGELOG.md"
GEMFILE_LOCK="$REPO_ROOT/Gemfile.lock"

# ── 1. Read current VERSION ────────────────────────────────────────────────
CURRENT_VERSION=$(ruby -e "
  content = File.read('$VERSION_FILE')
  m = content.match(/VERSION\s*=\s*[\"']([^\"']+)[\"']/)
  abort 'Could not parse VERSION' unless m
  puts m[1]
")

echo "[release-preflight] Current VERSION: $CURRENT_VERSION"

# ── 2. Detect the tag being pushed ────────────────────────────────────────
# $RELEASE_TAG can be set explicitly; otherwise derive from git describe.
if [[ -n "${RELEASE_TAG:-}" ]]; then
  TAG="$RELEASE_TAG"
else
  TAG=$(git -C "$REPO_ROOT" describe --tags --abbrev=0 2>/dev/null || echo "")
fi

# Strip leading 'v'
TAG_VERSION="${TAG#v}"

ERRORS=()

# ── 3. Tag ↔ VERSION must match ───────────────────────────────────────────
if [[ -n "$TAG_VERSION" && "$TAG_VERSION" != "$CURRENT_VERSION" ]]; then
  ERRORS+=("VERSION mismatch: lib/react_manifest/version.rb says '$CURRENT_VERSION' but tag is '$TAG' (v$TAG_VERSION)")
fi

# ── 4. CHANGELOG must have a versioned entry (not just [Unreleased]) ──────
if ! grep -qE "^\#\# \[$CURRENT_VERSION\]" "$CHANGELOG_FILE"; then
  ERRORS+=("CHANGELOG.md has no entry for [$CURRENT_VERSION]. Rename [Unreleased] → [$CURRENT_VERSION] - $(date +%Y-%m-%d)")
fi

# [Unreleased] should be empty / absent (all changes promoted to versioned entry)
UNRELEASED_LINES=$(awk '/^\#\# \[Unreleased\]/{found=1; next} found && /^\#\# \[/{exit} found{print}' "$CHANGELOG_FILE" | { grep -v '^\s*$' || true; } | wc -l | tr -d ' ')
if [[ "$UNRELEASED_LINES" -gt 0 ]]; then
  ERRORS+=("CHANGELOG.md [Unreleased] section still has $UNRELEASED_LINES non-blank lines. Move them to the [$CURRENT_VERSION] entry.")
fi

# ── 5. Gemfile.lock must reflect current version ──────────────────────────
if ! grep -q "react-manifest-rails ($CURRENT_VERSION)" "$GEMFILE_LOCK" && \
   ! grep -q "version: $CURRENT_VERSION" "$GEMFILE_LOCK"; then
  ERRORS+=("Gemfile.lock does not reflect version $CURRENT_VERSION. Run: bundle install")
fi

# ── 6. No uncommitted changes to release-critical files ───────────────────
DIRTY=$(git -C "$REPO_ROOT" status --porcelain -- \
  lib/react_manifest/version.rb CHANGELOG.md Gemfile.lock 2>/dev/null || echo "")
if [[ -n "$DIRTY" ]]; then
  ERRORS+=("Release-critical files have uncommitted changes:\n$DIRTY\nCommit them before tagging.")
fi

# ── 7. Run test suite (Minitest via rake) ─────────────────────────────────
echo ""
echo "[release-preflight] Running test suite..."
bundle exec rake test 2>&1 | tee /tmp/test-preflight.log
if ! grep -qE "[0-9]+ runs, [0-9]+ assertions, 0 failures, 0 errors" /tmp/test-preflight.log; then
  ERRORS+=("Test suite failed. Fix failing tests before releasing.")
fi

# ── 8. Run RuboCop ────────────────────────────────────────────────────────
echo ""
echo "[release-preflight] Running RuboCop..."
bundle exec rubocop --parallel --no-color 2>&1 | tee /tmp/rubocop-preflight.log
if ! grep -q "no offenses detected" /tmp/rubocop-preflight.log; then
  ERRORS+=("RuboCop offenses detected. Run: bundle exec rubocop -a")
fi

# ── Report ─────────────────────────────────────────────────────────────────
if [[ ${#ERRORS[@]} -gt 0 ]]; then
  echo ""
  echo "╔══════════════════════════════════════════════════════════════╗"
  echo "║  react-manifest-rails release preflight FAILED              ║"
  echo "╚══════════════════════════════════════════════════════════════╝"
  for err in "${ERRORS[@]}"; do
    echo -e "  ✗ $err"
  done
  echo ""
  echo "Fix the above issues, then retry the tag/push."
  echo ""
  echo "Release checklist:"
  echo "  1. Bump VERSION in lib/react_manifest/version.rb"
  echo "  2. Update CHANGELOG.md: rename [Unreleased] → [X.Y.Z] - $(date +%Y-%m-%d)"
  echo "  3. Run: bundle install"
  echo "  4. git add lib/react_manifest/version.rb CHANGELOG.md Gemfile.lock"
  echo "  5. git commit -m \"Release vX.Y.Z\""
  echo "  6. git tag -a vX.Y.Z -m \"Release vX.Y.Z\""
  echo "  7. git push origin master vX.Y.Z"
  exit 1
fi

echo ""
echo "✓ All release checks passed for v$CURRENT_VERSION — proceed."
exit 0
