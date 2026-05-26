#!/usr/bin/env bash
# install.sh — clone claude-symlink-agent-individual-skills and symlink each
# bundled skill into ~/.claude/skills/ so Claude Code auto-discovers it.
#
# No Node.js required. Idempotent: re-running converges and never clobbers a
# real file/directory. Pipe-friendly:
#
#   curl -fsSL https://raw.githubusercontent.com/carlosmarte/claude-symlink-agent-individual-skills/main/install.sh | bash
#
# Flags (or env vars):
#   --repo <owner/repo>     REPO         (default: carlosmarte/claude-symlink-agent-individual-skills)
#   --ref <branch|tag>      REF          (default: main)
#   --checkout <dir>        CHECKOUT_DIR (default: ${XDG_DATA_HOME:-$HOME/.local/share}/<repo-name>)
#   --link-dir <dir>        LINK_DIR     (default: $HOME/.claude/skills)
#   --force                 FORCE=1      replace a wrong-target symlink (never a real path)
#   --run                   RUN=1        also link into the CURRENT project's .claude/skills
#   --dry-run               DRY_RUN=1    report only; change nothing
#   -h | --help
set -euo pipefail

REPO="${REPO:-carlosmarte/claude-symlink-agent-individual-skills}"
REF="${REF:-main}"
LINK_DIR="${LINK_DIR:-$HOME/.claude/skills}"
FORCE="${FORCE:-0}"
RUN="${RUN:-0}"
DRY_RUN="${DRY_RUN:-0}"
CHECKOUT_DIR="${CHECKOUT_DIR:-}"

while [ $# -gt 0 ]; do
  case "$1" in
    --repo) REPO="$2"; shift 2 ;;
    --ref) REF="$2"; shift 2 ;;
    --checkout) CHECKOUT_DIR="$2"; shift 2 ;;
    --link-dir) LINK_DIR="$2"; shift 2 ;;
    --force) FORCE=1; shift ;;
    --run) RUN=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) grep -E '^#( |$)' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

REPO_NAME="${REPO##*/}"
: "${CHECKOUT_DIR:=${XDG_DATA_HOME:-$HOME/.local/share}/$REPO_NAME}"

say() { printf '%s\n' "$*"; }
run() { if [ "$DRY_RUN" = 1 ]; then say "[dry-run] $*"; else "$@"; fi; }

# 1. Clone or update the checkout.
if [ -d "$CHECKOUT_DIR/.git" ]; then
  say "Updating existing checkout: $CHECKOUT_DIR"
  run git -C "$CHECKOUT_DIR" fetch --quiet origin "$REF"
  run git -C "$CHECKOUT_DIR" checkout --quiet "$REF"
  run git -C "$CHECKOUT_DIR" pull --quiet --ff-only origin "$REF" || true
else
  say "Cloning $REPO@$REF into $CHECKOUT_DIR"
  run mkdir -p "$(dirname "$CHECKOUT_DIR")"
  run git clone --quiet --branch "$REF" "https://github.com/$REPO.git" "$CHECKOUT_DIR"
fi

SRC_DIR="$CHECKOUT_DIR/.agents/skills"
if [ ! -d "$SRC_DIR" ]; then
  echo "No .agents/skills in checkout: $SRC_DIR" >&2
  exit 1
fi

# 2. Link each skill into LINK_DIR (global). Diff-and-fill, never destructive.
created=0; passed=0; replaced=0; conflicts=0
run mkdir -p "$LINK_DIR"
for src in "$SRC_DIR"/*/; do
  [ -f "${src}SKILL.md" ] || continue
  name="$(basename "$src")"
  src="${src%/}"
  dst="$LINK_DIR/$name"
  if [ ! -e "$dst" ] && [ ! -L "$dst" ]; then
    say "CREATE    $name"
    run ln -s "$src" "$dst"; created=$((created+1))
  elif [ -L "$dst" ]; then
    if [ "$(readlink "$dst")" = "$src" ]; then
      say "PASS      $name"; passed=$((passed+1))
    elif [ "$FORCE" = 1 ]; then
      say "REPLACE   $name"
      run rm "$dst"; run ln -s "$src" "$dst"; replaced=$((replaced+1))
    else
      say "CONFLICT  $name (wrong-target -> $(readlink "$dst"); use --force)"; conflicts=$((conflicts+1))
    fi
  else
    say "CONFLICT  $name (real path exists; refusing to clobber)"; conflicts=$((conflicts+1))
  fi
done

say ""
say "Global: $created created, $replaced relinked, $passed already correct, $conflicts conflict(s) -> $LINK_DIR"

# 3. Optionally also link into the current project's .claude/skills.
if [ "$RUN" = 1 ]; then
  say ""
  say "--run: linking into current project ($PWD/.claude/skills) via bundled linker"
  linker_mjs="$CHECKOUT_DIR/.agents/skills/claude-symlink-agent-individual-skills/bin/link-skills.mjs"
  linker_py="$CHECKOUT_DIR/.agents/skills/claude-symlink-agent-individual-skills/bin/link_skills.py"
  extra=""; [ "$DRY_RUN" = 1 ] && extra="--dry-run"; [ "$FORCE" = 1 ] && extra="$extra --force"
  if command -v node >/dev/null 2>&1; then
    node "$linker_mjs" "$PWD" $extra
  elif command -v python3 >/dev/null 2>&1; then
    python3 "$linker_py" "$PWD" $extra
  else
    echo "--run needs node or python3 on PATH; skipped project linking." >&2
  fi
fi

[ "$conflicts" -gt 0 ] && exit 1 || exit 0
