#!/bin/bash
# Install git hooks for Medical Event Recorder
# Run from repo root: bash scripts/install-hooks.sh

HOOKS_SRC="scripts/hooks"
HOOKS_DEST=".git/hooks"

cp "$HOOKS_SRC/pre-commit" "$HOOKS_DEST/pre-commit"
chmod +x "$HOOKS_DEST/pre-commit"

echo "✅ MER pre-commit hook installed."
