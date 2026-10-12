#!/usr/bin/env bash
# skills/install.sh — link the valda skills into your Claude Code skills directory.
# Safe to re-run (ln -sfn refreshes the symlinks).
set -euo pipefail

SRC="$(cd "$(dirname "$0")" && pwd)"
DEST_DIR="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"
mkdir -p "$DEST_DIR"

for skill in valda-music valda-drums; do
	if [ ! -f "$SRC/$skill/SKILL.md" ]; then
		echo "install.sh: $SRC/$skill has no SKILL.md" >&2
		exit 1
	fi
	dest="$DEST_DIR/$skill"
	if [ -e "$dest" ] && [ ! -L "$dest" ]; then
		echo "install.sh: $dest already exists and is not a symlink — remove it first" >&2
		exit 1
	fi
	ln -sfn "$SRC/$skill" "$dest"
	echo "$skill skill linked: $dest -> $SRC/$skill"
done
echo "Restart Claude Code (or start a new session) to pick them up."
