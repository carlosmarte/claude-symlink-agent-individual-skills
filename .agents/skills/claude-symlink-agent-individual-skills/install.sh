#!/usr/bin/env bash
# install.sh — run the bundled linker directly, no clone/network needed.
#
# Thin launcher that picks an available runtime (Node, then Python 3) and runs
# the skill's linker against the current repo, mirroring every
# .agents/skills/<name> into .claude/skills/<name> as a relative symlink.
#
# Unlike the repo-root install.sh (which clones from GitHub and links globally),
# this one operates on the skill that's already on disk — handy once the skill
# is installed, vendored, or checked out.
#
# All arguments pass straight through to the linker, e.g.:
#   ./install.sh                 # link skills of the repo you're standing in
#   ./install.sh --dry-run       # preview only
#   ./install.sh --force         # replace wrong-target symlinks
#   ./install.sh /path/to/repo   # operate on a specific repo root
#   ./install.sh --json --quiet  # see link-skills.mjs / link_skills.py for the full set
set -euo pipefail

# Directory this script lives in — so it works regardless of the caller's cwd.
SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MJS="$SKILL_DIR/bin/link-skills.mjs"
PY="$SKILL_DIR/bin/link_skills.py"

if command -v node >/dev/null 2>&1; then
  exec node "$MJS" "$@"
elif command -v python3 >/dev/null 2>&1; then
  exec python3 "$PY" "$@"
else
  echo "install.sh needs either 'node' or 'python3' on PATH." >&2
  echo "Run one of these linkers directly instead:" >&2
  echo "  node \"$MJS\" $*" >&2
  echo "  python3 \"$PY\" $*" >&2
  exit 127
fi
