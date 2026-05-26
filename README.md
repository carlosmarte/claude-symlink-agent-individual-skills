# claude-symlink-agent-individual-skills

Mirror each individual skill under `.agents/skills/<name>/` into a `.claude/skills/<name>`
relative symlink so Claude Code's harness auto-discovers it — but only for skills that
don't already have a correct link. Idempotent and non-destructive.

## Install with `npx skills`

The quickest approach uses the open `skills` CLI. To install everything project-wide:

```sh
npx skills add carlosmarte/claude-symlink-agent-individual-skills
```

Or globally across your system:

```sh
npx skills add carlosmarte/claude-symlink-agent-individual-skills -g
```

Preview the available skills before installing:

```sh
npx skills add carlosmarte/claude-symlink-agent-individual-skills --list
```

To add just this skill to Claude Code globally:

```sh
npx skills add carlosmarte/claude-symlink-agent-individual-skills \
  --skill claude-symlink-agent-individual-skills -g -a claude-code
```

To combine multiple skills and agents, specify them together:

```sh
npx skills add carlosmarte/claude-symlink-agent-individual-skills \
  --skill claude-symlink-agent-individual-skills --skill agent-skill-kit-commons \
  -g -a claude-code -y
```

Management commands let you list, update, or remove installed skills afterward.

## Alternative: one-shot install via `curl`

Requiring no `npx`/Node.js, use the bundled installer:

```sh
curl -fsSL https://raw.githubusercontent.com/carlosmarte/claude-symlink-agent-individual-skills/main/install.sh | bash
```

This clones the repository and creates symlinks in `~/.claude/skills/`. The process is
idempotent (existing correct links are left alone; real files/directories are never
clobbered) and can be customized with flags:

```sh
# Also link into the current project's .claude/skills after the global install
curl -fsSL https://raw.githubusercontent.com/carlosmarte/claude-symlink-agent-individual-skills/main/install.sh | bash -s -- --run

# Preview only — change nothing
curl -fsSL https://raw.githubusercontent.com/carlosmarte/claude-symlink-agent-individual-skills/main/install.sh | bash -s -- --dry-run
```

You can specify checkout location, branch/tag, or link directory via flags or environment
variables (`--checkout` / `CHECKOUT_DIR`, `--ref` / `REF`, `--link-dir` / `LINK_DIR`,
`--force`). Run `install.sh --help` for the full list.

## Usage (without installing)

The skill ships zero-dependency linkers (Node or Python 3 — pick whichever runtime is
handy). They detect the repo root via `git rev-parse --show-toplevel`, falling back to
`$PWD`:

```sh
# Node
node .agents/skills/claude-symlink-agent-individual-skills/bin/link-skills.mjs --dry-run

# Python 3
python3 .agents/skills/claude-symlink-agent-individual-skills/bin/link_skills.py --dry-run
```

Drop `--dry-run` to apply. See
[`.agents/skills/claude-symlink-agent-individual-skills/SKILL.md`](.agents/skills/claude-symlink-agent-individual-skills/SKILL.md)
for the full behavior table, flags, and safety guarantees.
