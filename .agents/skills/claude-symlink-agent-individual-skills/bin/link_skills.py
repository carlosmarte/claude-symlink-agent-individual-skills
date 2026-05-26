#!/usr/bin/env python3
"""link_skills.py — mirror each .agents/skills/<name> into .claude/skills/<name>
as a relative symlink, but ONLY for skills that don't already have one.

Zero dependencies — Python 3 standard library only (os / pathlib / subprocess).

Usage:
    python3 link_skills.py [root] [--dry-run] [--force] [--json] [--quiet]

    root        Repo root to operate on. Defaults to `git rev-parse --show-toplevel`,
                falling back to the current working directory.
    --dry-run   Report what would happen; create nothing.
    --force     Replace an existing WRONG symlink (one pointing somewhere else).
                Never deletes a real directory or file.
    --json      Emit a machine-readable JSON report instead of the text table.
    --quiet     Suppress per-skill lines; print only the summary (text mode).

Exit codes: 0 = no problems, 1 = at least one CONFLICT left unresolved.
"""

import json
import os
import subprocess
import sys
from pathlib import Path


def repo_root(positional: str | None) -> Path:
    if positional:
        return Path(positional).resolve()
    try:
        top = subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            capture_output=True,
            text=True,
            check=True,
        ).stdout.strip()
        if top:
            return Path(top)
    except (subprocess.CalledProcessError, FileNotFoundError):
        pass
    return Path.cwd()


def main() -> int:
    args = sys.argv[1:]
    flags = {a for a in args if a.startswith("--")}
    positional = [a for a in args if not a.startswith("--")]
    dry_run = "--dry-run" in flags
    force = "--force" in flags
    json_out = "--json" in flags
    quiet = "--quiet" in flags

    root = repo_root(positional[0] if positional else None)
    src_dir = root / ".agents" / "skills"
    dst_dir = root / ".claude" / "skills"

    if not src_dir.exists():
        msg = f"No source directory: {src_dir}"
        if json_out:
            print(json.dumps({"root": str(root), "error": msg, "results": []}, indent=2))
        else:
            print(msg, file=sys.stderr)
        return 1

    # A skill is any subdirectory of .agents/skills/ that contains a SKILL.md.
    skills = sorted(
        p.name
        for p in src_dir.iterdir()
        if p.is_dir() and (p / "SKILL.md").exists()
    )

    results = []
    for name in skills:
        src = src_dir / name           # .agents/skills/<name>
        dst = dst_dir / name           # .claude/skills/<name>
        # Relative target keeps the link host-independent: ../../.agents/skills/<name>
        link_target = os.path.relpath(src, dst_dir)
        src_real = src.resolve()

        if not dst.exists() and not dst.is_symlink():
            status, action = "CREATE", "linked"
            if not dry_run:
                dst_dir.mkdir(parents=True, exist_ok=True)
                dst.symlink_to(link_target)
        elif dst.is_symlink():
            resolved = dst.resolve() if dst.exists() else None
            if resolved == src_real:
                status, action = "PASS", "already-correct"
            elif force:
                status, action = "REPLACE", "relinked"
                if not dry_run:
                    dst.unlink()  # safe: only removing a symlink, never a real dir
                    dst.symlink_to(link_target)
            else:
                status = "CONFLICT"
                action = f"wrong-target -> {os.readlink(dst)} (use --force to replace)"
        else:
            # A real file or directory occupies the slot — never auto-clobber.
            status, action = "CONFLICT", "real path exists (refusing to clobber)"

        results.append(
            {"name": name, "status": status, "action": action, "target": link_target}
        )

    conflicts = sum(1 for r in results if r["status"] == "CONFLICT")

    if json_out:
        print(
            json.dumps(
                {
                    "root": str(root),
                    "dryRun": dry_run,
                    "source": str(src_dir),
                    "dest": str(dst_dir),
                    "results": results,
                },
                indent=2,
            )
        )
    else:
        if not quiet:
            for r in results:
                print(f"{r['status']:<9} {r['name']}  ({r['action']})")
            if results:
                print("")
        created = sum(1 for r in results if r["status"] == "CREATE")
        replaced = sum(1 for r in results if r["status"] == "REPLACE")
        passed = sum(1 for r in results if r["status"] == "PASS")
        prefix = "[dry-run] " if dry_run else ""
        print(
            f"{prefix}{len(skills)} skill(s): {created} created, {replaced} relinked, "
            f"{passed} already correct, {conflicts} conflict(s)."
        )

    return 1 if conflicts > 0 else 0


if __name__ == "__main__":
    sys.exit(main())
