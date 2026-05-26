#!/usr/bin/env node
// link-skills.mjs — mirror each .agents/skills/<name> into .claude/skills/<name>
// as a relative symlink, but ONLY for skills that don't already have one.
//
// Zero dependencies — Node standard library only (node: fs / path / child_process).
//
// Usage:
//   node link-skills.mjs [root] [--dry-run] [--force] [--json] [--quiet]
//
//   root        Repo root to operate on. Defaults to `git rev-parse --show-toplevel`,
//               falling back to the current working directory.
//   --dry-run   Report what would happen; create nothing.
//   --force     Replace an existing WRONG symlink (one pointing somewhere else).
//               Never deletes a real directory or file.
//   --json      Emit a machine-readable JSON report instead of the text table.
//   --quiet     Suppress per-skill lines; print only the summary (text mode).
//
// Exit codes: 0 = no problems (everything created/already-correct/skipped-clean),
//             1 = at least one CONFLICT left unresolved.

import { execFileSync } from "node:child_process";
import {
  existsSync,
  lstatSync,
  mkdirSync,
  readdirSync,
  readlinkSync,
  realpathSync,
  rmSync,
  symlinkSync,
} from "node:fs";
import { join, relative, resolve } from "node:path";

const args = process.argv.slice(2);
const flags = new Set(args.filter((a) => a.startsWith("--")));
const positional = args.filter((a) => !a.startsWith("--"));
const DRY_RUN = flags.has("--dry-run");
const FORCE = flags.has("--force");
const JSON_OUT = flags.has("--json");
const QUIET = flags.has("--quiet");

function repoRoot() {
  if (positional[0]) return resolve(positional[0]);
  try {
    const top = execFileSync("git", ["rev-parse", "--show-toplevel"], {
      encoding: "utf8",
      stdio: ["ignore", "pipe", "ignore"],
    }).trim();
    if (top) return top;
  } catch {
    /* not a git repo — fall through */
  }
  return process.cwd();
}

const ROOT = repoRoot();
const SRC_DIR = join(ROOT, ".agents", "skills");
const DST_DIR = join(ROOT, ".claude", "skills");

if (!existsSync(SRC_DIR)) {
  const msg = `No source directory: ${SRC_DIR}`;
  if (JSON_OUT) {
    console.log(JSON.stringify({ root: ROOT, error: msg, results: [] }, null, 2));
  } else {
    console.error(msg);
  }
  process.exit(1);
}

// A skill is any subdirectory of .agents/skills/ that contains a SKILL.md.
const skills = readdirSync(SRC_DIR, { withFileTypes: true })
  .filter((d) => d.isDirectory() && existsSync(join(SRC_DIR, d.name, "SKILL.md")))
  .map((d) => d.name)
  .sort();

const results = [];

function resolveLink(p) {
  // Absolute path the symlink resolves to, or null if it dangles.
  try {
    return realpathSync(p);
  } catch {
    return null;
  }
}

for (const name of skills) {
  const src = join(SRC_DIR, name); // .agents/skills/<name>
  const dst = join(DST_DIR, name); // .claude/skills/<name>
  // Relative target keeps the link host-independent: ../../.agents/skills/<name>
  const linkTarget = relative(DST_DIR, src);
  const srcReal = realpathSync(src);

  let status, action;

  const exists = (() => {
    try {
      lstatSync(dst); // lstat: does NOT follow the link
      return true;
    } catch {
      return false;
    }
  })();

  if (!exists) {
    status = "CREATE";
    action = "linked";
    if (!DRY_RUN) {
      mkdirSync(DST_DIR, { recursive: true });
      symlinkSync(linkTarget, dst);
    }
  } else if (lstatSync(dst).isSymbolicLink()) {
    if (resolveLink(dst) === srcReal) {
      status = "PASS";
      action = "already-correct";
    } else if (FORCE) {
      status = "REPLACE";
      action = "relinked";
      if (!DRY_RUN) {
        rmSync(dst); // safe: only removing a symlink, never a real dir
        symlinkSync(linkTarget, dst);
      }
    } else {
      status = "CONFLICT";
      action = `wrong-target -> ${readlinkSync(dst)} (use --force to replace)`;
    }
  } else {
    // A real file or directory occupies the slot — never auto-clobber.
    status = "CONFLICT";
    action = "real path exists (refusing to clobber)";
  }

  results.push({ name, status, action, target: linkTarget });
}

const conflicts = results.filter((r) => r.status === "CONFLICT").length;

if (JSON_OUT) {
  console.log(
    JSON.stringify(
      { root: ROOT, dryRun: DRY_RUN, source: SRC_DIR, dest: DST_DIR, results },
      null,
      2,
    ),
  );
} else {
  if (!QUIET) {
    for (const r of results) {
      console.log(`${r.status.padEnd(9)} ${r.name}  (${r.action})`);
    }
    if (results.length) console.log("");
  }
  const created = results.filter((r) => r.status === "CREATE").length;
  const replaced = results.filter((r) => r.status === "REPLACE").length;
  const passed = results.filter((r) => r.status === "PASS").length;
  const prefix = DRY_RUN ? "[dry-run] " : "";
  console.log(
    `${prefix}${skills.length} skill(s): ${created} created, ${replaced} relinked, ` +
      `${passed} already correct, ${conflicts} conflict(s).`,
  );
}

process.exit(conflicts > 0 ? 1 : 0);
