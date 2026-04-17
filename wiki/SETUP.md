# Setting Up Your AI Coding Agent for BiSheng C

A guide for configuring AI coding tools so they can write, debug, and reason about
BiSheng C (BSC) code effectively. **Claude Code is used throughout as the primary
example**; the same ideas apply to Cursor, Windsurf, OpenCode, Copilot, and Codex
with adapter-specific paths.

---

## TL;DR Summary

To get an AI agent productive on BSC code, you need three layers of configuration:

1. **Skills / Rules** — the agent must know BSC syntax (especially that `_Owned`/`_Borrow`
   go *after* `*`). Install via `bash <(curl -fsSL .../install.sh) -a claude`.
2. **Project memory (`CLAUDE.md`)** — always-loaded context with critical syntax rules,
   build commands, and project-specific conventions. Auto-written by the installer.
3. **LSP (clangd) integration** — a BSC-aware clangd binary registered for `.cbs`/`.hbs`
   files lets the agent query ownership flow, types, and borrow lifetimes from the
   compiler — far more reliable than guessing from source code alone.

Once those three are in place, your agent can:
- Generate BSC code with correct pointer-qualifier placement
- Diagnose borrow-checker errors by inspecting the variable's ownership timeline
- Translate C code to BSC with appropriate `_Owned`/`_Borrow` annotations
- Use `safe_malloc`/`safe_free` instead of raw `malloc`/`free` where possible

---

## Specifics

### 1. Install the Skills

The skills package teaches the agent BSC's syntax rules — especially the non-obvious ones
that mainstream training data doesn't cover (`_Owned T*` is wrong, `T *_Owned` is right).

**One-liner (recommended):**

```bash
# From your project root
curl -fsSL https://gitee.com/bisheng_c_language_dep/BiShengCSkills/raw/master/install.sh | bash -s -- -a claude
```

What this does:

- Writes 13 skill files into `.claude/commands/` — each invocable as a slash command
  (e.g. `/bsc-ownership`, `/bsc-borrowing`, `/bsc-c-to-bsc`).
- Appends a `# BiSheng C` section to `CLAUDE.md` containing the **critical pointer-qualifier
  grammar** that must always be in context.

**Adapter flags for other tools:**

| Tool | Flag | Files written |
|---|---|---|
| Claude Code | `-a claude` | `.claude/commands/*.md` + `CLAUDE.md` |
| Cursor | `-a cursor` | `.cursorrules` |
| Windsurf | `-a windsurf` | `.windsurfrules` |
| OpenCode | `-a opencode` | `.opencode/skills/*/SKILL.md` |
| GitHub Copilot | `-a copilot` | `.github/copilot-instructions.md` |
| OpenAI Codex | `-a codex` | `AGENTS.md` |
| All of the above | `-a all` | (each tool's location) |

**Verify:**

```bash
ls .claude/commands/   # should list bsc-overview.md, bsc-ownership.md, ...
grep -c "BiSheng C" CLAUDE.md   # should be ≥ 1
```

### 2. CLAUDE.md — project memory

`CLAUDE.md` is loaded into every Claude Code session as ambient context. The installer
adds the BSC syntax preamble, but you should **also add project-specific things**:

- Build/compile commands the agent needs (custom clang path, include dirs, link flags)
- Test commands (`./run_tests`, `make test`, etc.)
- Local conventions that override defaults (e.g. "we always prefer `safe_malloc` over
  raw `malloc` in this repo")
- Pointers to design docs, ADRs, or key entry-point files

**Example additions for a project:**

```markdown
## Build

Compile BSC sources with the BSC-aware clang:

\`\`\`bash
/home/ziruichen/bsd/llvm-project-dup/build/bin/clang -c src/foo.cbs -o foo.o \
  -I./BiShengCSafety/include
ar rcs libfoo.a foo.o
\`\`\`

## Test

\`\`\`bash
./run_tests   # 80 tests must pass before committing
\`\`\`

## Conventions

- Prefer `safe_malloc<T>(val)` over raw `malloc` in `_Safe` zones
- Member-function syntax: `Type::method(this, ...)` for declaration, `obj->method(...)` for call
- All public APIs go in `.hbs` headers; only `_Safe` functions cross module boundaries
```

The longer your `CLAUDE.md` grows, the more context every turn consumes — keep it tight.
For deeper documentation, write standalone files and *reference* them from `CLAUDE.md`.

### 3. LSP — wire up clangd for `.cbs`/`.hbs`

This is the highest-leverage step for reasoning about ownership and borrows. Without LSP
the agent must read source files and mentally track every move/borrow. With LSP, one
`hover` call on a variable returns its complete ownership timeline.

#### What you need

- A **BSC-aware clangd** binary (built from the BSC compiler tree, not the system clangd).
  Typical location: `/home/<user>/bsd/llvm-project-dup/build/bin/clangd`.
- A Claude Code **plugin** that registers this clangd for `.cbs` and `.hbs` files.

#### Project-local plugin setup (recommended — doesn't pollute user config)

Create the directory layout:

```
your-project/
├── .claude/
│   ├── settings.local.json
│   └── plugins/
│       ├── .claude-plugin/
│       │   └── marketplace.json     # local marketplace declaration
│       └── clangd/
│           └── .claude-plugin/
│               └── plugin.json       # plugin manifest with LSP config
```

**`.claude/plugins/.claude-plugin/marketplace.json`:**

```json
{
  "name": "my-project-local",
  "owner": { "name": "your-name", "email": "you@example.com" },
  "metadata": {
    "description": "Project-local plugins",
    "version": "1.0.0"
  },
  "plugins": [
    {
      "name": "custom-clangd",
      "source": "./clangd",
      "description": "BSC-aware clangd with .cbs/.hbs support",
      "category": "development"
    }
  ]
}
```

**`.claude/plugins/clangd/.claude-plugin/plugin.json`:**

```json
{
  "name": "custom-clangd",
  "description": "BSC-aware clangd with ownership flow analysis",
  "version": "1.0.0",
  "lspServers": {
    "clangd": {
      "command": "/home/ziruichen/bsd/llvm-project-dup/build/bin/clangd",
      "args": ["--background-index"],
      "extensionToLanguage": {
        ".c": "c",
        ".h": "c",
        ".cbs": "c",
        ".hbs": "c",
        ".cpp": "cpp",
        ".cc": "cpp",
        ".cxx": "cpp",
        ".hpp": "cpp",
        ".hxx": "cpp"
      }
    }
  }
}
```

(Replace the `command` path with your BSC clangd location.)

**`.claude/settings.local.json` — register the marketplace and enable the plugin:**

```json
{
  "extraKnownMarketplaces": {
    "my-project-local": {
      "source": {
        "source": "directory",
        "path": "/absolute/path/to/your-project/.claude/plugins"
      }
    }
  },
  "enabledPlugins": {
    "custom-clangd@my-project-local": true
  }
}
```

The path under `source.path` **must be absolute** — the schema validator rejects relative paths.

#### Activate the plugin

In Claude Code:

```
/plugin install custom-clangd@my-project-local
```

Pick **"Install for you, in this repo only (local scope)"**. Then:

```
/reload-plugins
```

You should see something like `Reloaded: 3 plugins · ... · 3 plugin LSP servers` —
the third LSP server is your BSC clangd.

#### Verify LSP works

In any `.cbs` file, ask Claude Code to hover on a variable. It should return an
**Ownership Flow** block:

```
### variable `fp`

Type: `FILE *_Owned (aka struct _IO_FILE *_Owned)`

Ownership Flow:
line 119: Declared
line 119: Copied in
  FILE* _Owned fp = __take_from_raw(fopen(filename, "r"));
line 130: Moved into __move_to_raw()
  __move_to_raw(fp)
line 152: Freed
Live range: lines 119-152
```

If you get `No LSP server available for file type: .cbs`, the plugin isn't loaded —
re-check the install step and run `/reload-plugins`.

#### Optional: `.clangd` config for include paths

clangd can't find headers without knowing your include paths. Drop a `.clangd` file
at the project root:

```yaml
CompileFlags:
  Add:
    - -I/absolute/path/to/your/include/dir
    - -I/another/include/dir
    - -xc
```

This silences spurious "header not found" diagnostics in the agent's view of the file.

### 4. Settings reference

The full schema for `.claude/settings.local.json` is large; here are the BSC-relevant fields:

| Field | Purpose |
|---|---|
| `env` | Environment variables visible to all spawned processes — useful for `CC`, `CXX`, `PATH` so the agent finds the BSC clang. |
| `permissions.allow` | Pre-approved Bash patterns (e.g. `Bash(./run_tests)`, `Bash(/path/to/bsc-clang:*)`). Each entry skips the permission prompt. |
| `extraKnownMarketplaces` | Declares additional plugin marketplaces — needed once for the local clangd plugin. |
| `enabledPlugins` | Map of `plugin@marketplace` → `true`. Activates installed plugins. |

**Example with all three:**

```json
{
  "env": {
    "CC": "/home/you/bsd/llvm-project-dup/build/bin/clang",
    "PATH": "/home/you/bsd/llvm-project-dup/build/bin:$PATH"
  },
  "permissions": {
    "allow": [
      "Bash(/home/you/bsd/llvm-project-dup/build/bin/clang:*)",
      "Bash(ar rcs:*)",
      "Bash(./run_tests)"
    ]
  },
  "extraKnownMarketplaces": {
    "my-project-local": {
      "source": {
        "source": "directory",
        "path": "/absolute/path/to/your-project/.claude/plugins"
      }
    }
  },
  "enabledPlugins": {
    "custom-clangd@my-project-local": true
  }
}
```

### 5. What to commit vs. what to gitignore

Decide per-team:

- **Commit** (`.claude/settings.json`): rules everyone on the project should share —
  pre-approved BSC clang invocations, the marketplace declaration, the plugin enable line.
- **Local-only** (`.claude/settings.local.json`, gitignored by default): personal paths
  that differ between machines, e.g. each developer's clangd binary location.

A common pattern: commit the marketplace declaration in `settings.json`, but each developer
keeps their own absolute clangd `command` path in their local plugin manifest (which is
NOT under `.claude/plugins/.claude-plugin/`, only the wrapper is).

If the clangd path is the same across the team (e.g. CI-installed), commit everything.

---

## Troubleshooting

### `No LSP server available for file type: .cbs`

The local plugin isn't loaded. Steps:

1. Confirm files exist: `ls .claude/plugins/.claude-plugin/marketplace.json` and
   `ls .claude/plugins/clangd/.claude-plugin/plugin.json`
2. Run `/plugin install custom-clangd@my-project-local` and pick local scope.
3. Run `/reload-plugins`. The output should mention "3 plugin LSP servers" (or 1+ if
   you didn't have other LSP plugins).
4. Try `hover` again.

### `Plugin has an invalid manifest file ... Validation errors: lspServers: Invalid input`

The `lspServers` field must be **inline JSON**, not a path string like `"../.lsp.json"`.
See section 3 — the `plugin.json` example has the correct inline form.

### `extraKnownMarketplaces.<name>.source.source: Invalid input`

The schema requires nested `source.source` with one of: `"directory"`, `"file"`,
`"github"`, `"git"`, `"url"`, `"npm"`, `"settings"`. For local plugins use `"directory"`
with an **absolute path** under `source.path`.

### LSP returns `<recovery-expr>` for member-function calls

clangd doesn't fully understand BSC's `obj->method()` member-function syntax. This affects
`findReferences` and `incomingCalls` — they often miss call sites. Workaround: use Grep
for call-site enumeration, and use LSP only for **single-variable ownership/type queries**
where it's reliable.

---

## What you actually get out of this

After a complete setup, the agent can:

- **Write correct BSC syntax** without the user having to correct `_Owned T*` mistakes.
- **Diagnose borrow errors** by hovering on the named variable and reading its
  chronological ownership timeline (Declared → Moved → Freed) — typically 5–10× faster
  than re-reading the function manually.
- **Translate C to BSC** by loading the `/c-to-bsc` skill, which prevents the common
  zero-annotation translation failure mode.
- **Reference error codes** via the `/bsc-errors` skill, which knows every `BSC-Exxxx`
  diagnostic and the typical fix.

What it still can't do well:

- Refactor across many files using only LSP — the member-function call syntax confuses
  `findReferences`. Always cross-check with Grep before deleting/renaming a symbol.
- Understand `_Trait` dispatch perfectly — clangd indexes the trait declarations but
  doesn't always resolve dynamic dispatch sites.

These are clangd limitations, not Claude Code limitations. As BSC tooling matures, more
will move into the LSP.
