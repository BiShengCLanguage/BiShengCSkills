#!/bin/bash
# install.sh — Install BiSheng C Skills for AI coding tools
#
# One-liner install (no manual clone needed):
#   curl -fsSL https://raw.githubusercontent.com/BiShengCLanguage/BiShengCSkills/master/install.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/BiShengCLanguage/BiShengCSkills/master/install.sh | bash -s -- -a claude
#
# Or with git:
#   bash <(curl -fsSL https://raw.githubusercontent.com/BiShengCLanguage/BiShengCSkills/master/install.sh)
#
# Usage (if already cloned):
#   bash install.sh                          # install for all detected tools in current project
#   bash install.sh -a claude                # install for Claude Code only
#   bash install.sh -a cursor                # install for Cursor only
#   bash install.sh -a opencode              # install for OpenCode only
#   bash install.sh -a all                   # install for all tools
#   bash install.sh -a all /path/to/project  # install to specific project
#   bash install.sh --uninstall              # remove all installed skills
#   bash install.sh --list                   # list available skills
#
# Supported tools:
#   claude         — Claude Code, per-project install (.claude/skills/)
#   claude-plugin  — Claude Code, global plugin install (~/.claude/plugins/) + per-project CLAUDE.md
#                    Run from inside your project directory. Prompts for compile command and
#                    optional clangd path. Logs BSC skill loads and BSC agent invocations to
#                    ~/.claude/bsc-usage.log (override with BSC_LOG_FILE).
#   cursor         — Cursor IDE (.cursorrules)
#   windsurf       — Windsurf IDE (.windsurfrules)
#   opencode       — OpenCode (.opencode/skills/)
#   copilot        — GitHub Copilot (.github/copilot-instructions.md)
#   codex          — OpenAI Codex CLI (AGENTS.md)

set -euo pipefail

REPO_URL="https://github.com/BiShengCLanguage/BiShengCSkills.git"
REPO_SSH="git@github.com:BiShengCLanguage/BiShengCSkills.git"
CACHE_DIR="${BSC_SKILLS_DIR:-/tmp/BiShengCSkills}"

# --- Bootstrap: if run via curl|bash, clone the repo first ---
if [ -z "${BASH_SOURCE[0]:-}" ] || [ ! -f "${BASH_SOURCE[0]:-}" ] || [ ! -d "$(dirname "${BASH_SOURCE[0]:-/dev/null}")/skills" ]; then
    echo "BiSheng C Skills Installer"
    echo "=========================="
    echo ""

    if [ -d "$CACHE_DIR/skills" ]; then
        echo "Updating cached repo at $CACHE_DIR..."
        git -C "$CACHE_DIR" pull --quiet 2>/dev/null || true
    else
        echo "Downloading BiSheng C Skills..."
        rm -rf "$CACHE_DIR"
        git clone --depth 1 --quiet "$REPO_URL" "$CACHE_DIR" 2>/dev/null \
            || git clone --depth 1 --quiet "$REPO_SSH" "$CACHE_DIR"
    fi

    echo ""
    exec bash "$CACHE_DIR/install.sh" "$@"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="$SCRIPT_DIR/skills"
AGENTS_DIR="$SCRIPT_DIR/agents"
ERRORS_DIR="$SCRIPT_DIR/errors"
ADAPTER="all"
TARGET="."
ACTION="install"
LITE=false

# --- Parse args ---
while [ $# -gt 0 ]; do
    case "$1" in
        -a|--adapter)  ADAPTER="$2"; shift 2 ;;
        --uninstall)   ACTION="uninstall"; shift ;;
        --list)        ACTION="list"; shift ;;
        --lite)        LITE=true; shift ;;
        -h|--help)     ACTION="help"; shift ;;
        *)             TARGET="$1"; shift ;;
    esac
done

# --- Lite mode: 5 condensed skills for less-capable models ---
if [ "$LITE" = "true" ]; then
    SKILLS_DIR="$SCRIPT_DIR/lite/skills"
    AGENTS_DIR=""   # no agents in lite mode
fi

TARGET="$(cd "$TARGET" && pwd)"

# --- Help ---
if [ "$ACTION" = "help" ]; then
    echo "Usage: install.sh [-a adapter] [--lite] [--uninstall] [--list] [project_dir]"
    echo ""
    echo "Adapters: claude, claude-plugin, cursor, windsurf, opencode, copilot, codex, all"
    echo ""
    echo "Examples:"
    echo "  bash install.sh                    # auto-detect tools, install to current dir"
    echo "  bash install.sh -a claude          # Claude Code, per-project install"
    echo "  bash install.sh -a claude-plugin   # Claude Code, global plugin + this project's CLAUDE.md"
    echo "  bash install.sh -a claude --lite   # Claude Code, 5 condensed skills for weaker models"
    echo "  bash install.sh -a cursor .        # Cursor rules in current dir"
    echo "  bash install.sh --list             # show all available skills"
    echo "  bash install.sh --uninstall        # remove BSC skills"
    exit 0
fi

# --- List ---
if [ "$ACTION" = "list" ]; then
    echo "Available BiSheng C Skills:"
    echo ""
    for skill_dir in "$SKILLS_DIR"/*/; do
        name="$(basename "$skill_dir")"
        desc=$(sed -n 's/^description: "\(.*\)"/\1/p' "$skill_dir/SKILL.md" 2>/dev/null | head -1)
        printf "  %-25s %s\n" "$name" "$desc"
    done
    echo ""
    echo "Total: $(ls -d "$SKILLS_DIR"/*/ | wc -l) skills"
    exit 0
fi

# --- Helper: concatenate all skills into single doc ---
concat_all_skills() {
    # === HEADER: Critical rules at top (primacy effect) ===
    cat << 'HEADER_EOF'
# BiSheng C (BSC) Language Reference

> BiSheng C is a superset of C with Rust-inspired memory safety, traits, generics, and async/await.
> Source files: `.cbs`. Header files: `.hbs`. Compiler: `clang file.cbs -o output`.

## CRITICAL: Pointer Qualifier Grammar — Read Before Writing Any BSC Code

`_Owned` and `_Borrow` are **pointer qualifiers** (like `const`). They go AFTER `*`, NEVER before the type.

Grammar: `base_type *qualifier variable_name`

Think of it like `const`: you write `int *const p`, not `const int* p` for a const pointer. Same rule: write `int *_Owned p`, not `_Owned int* p`.

Correct:
```c
char *_Owned msg = (char *_Owned)malloc(14);
int *_Owned p = (int *_Owned)malloc(sizeof(int));
const int *_Borrow r = &_Const x;
int *_Borrow mr = &_Mut y;
free((void *_Owned)p);
```

Wrong — causes compilation error "unknown type name '_Owned'":
```c
_Owned char* msg = malloc(14);     // WRONG
_Borrow int* r = &_Const x;       // WRONG
```

If you ever write `_Owned T*` or `_Borrow T*`, rewrite it: move the qualifier after `*` → `T *_Owned`.

`malloc()` MUST be cast: `(T *_Owned)malloc(n)`. `free()` MUST cast: `free((void *_Owned)p)`.

## C-to-BSC Translation

If translating/porting C code to BSC, you MUST read the "C to BiSheng C Translation Skill" section below BEFORE starting. Changing file extensions alone is NOT a translation — every pointer must be annotated with `_Owned` or `_Borrow`.

---

HEADER_EOF

    # === BODY: All skills ===
    for skill_dir in "$SKILLS_DIR"/*/; do
        name="$(basename "$skill_dir")"
        src="$skill_dir/SKILL.md"
        [ -f "$src" ] || continue
        # Strip YAML frontmatter, output body
        sed '1,/^---$/d' "$src"
        echo ""
        echo "---"
        echo ""
    done

    # === FOOTER: Repeat critical rule (recency effect) ===
    cat << 'FOOTER_EOF'

## Reminder: Pointer Qualifier Placement

Before returning BSC code, verify: `_Owned` and `_Borrow` go AFTER `*`.
- `char *_Owned` — CORRECT
- `_Owned char*` — WRONG (compilation error)

Pattern: `T *_Owned`, `T *_Borrow`. Never `_Owned T*`, never `_Borrow T*`.
FOOTER_EOF
}

# --- Helper: extract description from SKILL.md ---
get_desc() {
    sed -n 's/^description: "\(.*\)"/\1/p' "$1" | head -1
}

# --- Helper: strip YAML frontmatter ---
strip_frontmatter() {
    sed '1,/^---$/d' "$1"
}

# --- Helper: write always-loaded BSC rules to a target file (CLAUDE.md / AGENTS.md) ---
write_always_loaded_rules() {
    local target_file="$1"
    if [ -f "$target_file" ] && grep -q "BiSheng C" "$target_file" 2>/dev/null; then
        return
    fi
    cat >> "$target_file" << 'RULES_EOF'

# Working Principles

## 1. Think Before Coding

Don't assume. Don't hide confusion. Surface tradeoffs.

Before implementing:

- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them — don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

Minimum code that solves the problem. Nothing speculative.

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

Touch only what you must. Clean up only your own mess.

When editing existing code:

- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it — don't delete it.

When your changes create orphans:

- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

Define success criteria. Loop until verified.

Transform tasks into verifiable goals:

- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:

1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

---

# BiSheng C (BSC) — MUST READ before writing any .cbs code

## Pointer Qualifier Grammar (CRITICAL)

`_Owned` and `_Borrow` are **pointer qualifiers**, like `const`. They go AFTER `*`, NEVER before the type.

Grammar: `base_type *qualifier variable_name`

Think of it like `const`: you write `int *const p`, not `const int* p` for a const pointer.
Same rule: `int *_Owned p`, not `_Owned int* p`.

### Correct

```c
char *_Owned msg = (char *_Owned)malloc(14);
int *_Owned p = (int *_Owned)malloc(sizeof(int));
const int *_Borrow r = &_Const x;
int *_Borrow mr = &_Mut y;
free((void *_Owned)p);
```

### Wrong — causes compilation error: "unknown type name '_Owned'"

```c
_Owned char* msg = malloc(14);     // WRONG — _Owned is not a type
_Borrow int* r = &_Const x;       // WRONG — _Borrow is not a type
```

**Self-check before returning BSC code**: if you wrote `_Owned T*` or `_Borrow T*`,
rewrite to `T *_Owned`. The pattern is ALWAYS `T *_Owned`.

## Quick Reference

- Files: `.cbs` (source), `.hbs` (header). Compile: `clang file.cbs -o output`
- `.c`/`.h` files can be compiled as BSC with `-x bsc` (or `-xbsc`, both work): `clang -x bsc file.c -o output`
- `#include "bishengc_safety.hbs"` for safe APIs
- Prefer `safe_malloc<T>(val)` (returns `T *_Owned`, no cast) and `safe_free((void *_Owned)p)`
- Raw↔`_Owned` direct C casts are **forbidden even in `_Unsafe`**. Use the builtins:
  - Raw → `_Owned`: `__take_from_raw(raw_ptr)` (after null-check if nullability-check is on)
  - `_Owned` → raw: `__move_to_raw(owned_ptr)` (transfers ownership) OR `(T *)&_Mut *owned_ptr` (just borrows, keeps ownership)

## BSC Project Compile Command

**[FILL IN: how to compile and verify BSC files in THIS project]**

Replace this block with your project's specifics. Examples:

```
Compiler: /path/to/bsc/bin/clang   (NOT system clang — BSC needs a custom build)
Includes: -I/path/to/libcbs/src -I./include
Verify:   make check-file FILE=<file>
    # or: /path/to/bsc/bin/clang -I<includes> -x bsc <file> -fsyntax-only
```

If this section still says `[FILL IN: ...]`, **ASK the user** for the project's compile command before writing or editing any BSC code. The generic `clang <file> -fsyntax-only` below will fail for most projects (wrong compiler, missing include flags).

## Code Verification

After writing or editing any `.cbs`/`.hbs` file (or `.c`/`.h` compiled with `-x bsc`), run the project's verify command from the section above. Fix all compiler errors before reporting the task complete.

## LSP — Use Proactively

BSC-aware clangd exposes ownership flow and live ranges. Before non-trivial changes to
`_Owned`/`_Borrow` code, `hover` on the variable to see where it was moved, borrowed, or
freed — don't guess from local context. For the full reference (availability probe,
known clangd limitations, fallback-to-Grep rules), load `/bsc-lsp`.

## When to Load Other Skills

- Non-trivial BSC change (new struct, new `_Owned`/`_Borrow` signature, refactor crossing ownership timelines, `_Safe`/`_Unsafe` boundary decision) → load `/bsc-design` BEFORE planning.
- Translating/porting C to BSC → load `/c-to-bsc` BEFORE starting. Changing file extensions alone is NOT a translation.
RULES_EOF
}

# --- Helper: write LITE always-loaded BSC rules (condensed for weaker models) ---
write_always_loaded_rules_lite() {
    local target_file="$1"
    if [ -f "$target_file" ] && grep -q "BiSheng C" "$target_file" 2>/dev/null; then
        return
    fi
    cat >> "$target_file" << 'LITE_RULES_EOF'

# BiSheng C (BSC) — Project Rules

## Pointer Qualifier Grammar (CRITICAL)

`_Owned`, `_Borrow`, `_Nullable`, `_Nonnull` are pointer qualifiers, like `const`. They go AFTER `*`, never before the type.

Correct: `int *_Owned p`, `const int *_Borrow r`, `int *_Owned _Nullable q`
Wrong:   `_Owned int *p`, `_Nullable int *q`  (causes "unknown type name" error)

## Quick Rules

- `.c`/`.h` files: compile with `clang -x bsc file.c -o output` (no renaming needed)
- Include `bishengc_safety.hbs` for `safe_malloc<T>(val)` and `safe_free((void *_Owned)p)`
- Raw↔`_Owned` C casts are **forbidden everywhere**, even in `_Unsafe`. Use `__take_from_raw(raw_ptr)` and `__move_to_raw(owned_ptr)` instead of `(T *_Owned)` / `(T *)` casts
- `_Owned` and `_Borrow` are **non-null by default** — add `_Nullable` if the value may be null
- Use `nullptr`, never `NULL`, in BSC code
- Inside `_Safe`: `&` is forbidden — use `&_Const x` (read) or `&_Mut x` (write)

## BSC Project Compile Command

**[FILL IN: how to compile and verify BSC files in THIS project]**

Replace this block with your project's actual command, e.g.:

```
Compiler: /path/to/bsc/bin/clang   (NOT system clang)
Verify:   /path/to/bsc/bin/clang -I./include -x bsc <file> -fsyntax-only
```

If this block still says `[FILL IN: ...]`, **ASK the user** for the project's compile command before writing or editing any BSC code.

## Code Verification

After writing or editing any `.c`, `.h`, `.cbs`, or `.hbs` file, run the project's verify command from above. Fix all compiler errors before reporting the task complete.
LITE_RULES_EOF
}

# --- Install: Claude Code ---
install_claude() {
    local skills_dst="$TARGET/.claude/skills"
    mkdir -p "$skills_dst"
    local count=0

    for skill_dir in "$SKILLS_DIR"/*/; do
        name="$(basename "$skill_dir")"
        src="$skill_dir/SKILL.md"
        [ -f "$src" ] || continue

        mkdir -p "$skills_dst/$name"
        cp "$src" "$skills_dst/$name/SKILL.md"
        count=$((count + 1))
    done

    # Agents (read-only planning helpers; subagents don't inherit skills, so
    # their BSC knowledge is embedded in the agent file itself).
    local agents_dst="$TARGET/.claude/agents"
    local agent_count=0
    if [ -d "$AGENTS_DIR" ]; then
        mkdir -p "$agents_dst"
        for agent_file in "$AGENTS_DIR"/*.md; do
            [ -f "$agent_file" ] || continue
            cp "$agent_file" "$agents_dst/"
            agent_count=$((agent_count + 1))
        done
    fi

    # Install CLAUDE.md with always-loaded BSC rules
    local claude_md="$TARGET/CLAUDE.md"
    if [ "$LITE" = "true" ]; then
        write_always_loaded_rules_lite "$claude_md"
        echo "  Claude Code: installed $count lite skills to .claude/skills/"
        echo "  Claude Code: added condensed BSC rules to CLAUDE.md"
        return
    fi
    write_always_loaded_rules "$claude_md"
    if ! grep -q "bsc-planner" "$claude_md" 2>/dev/null; then
        cat >> "$claude_md" << 'CLAUDE_EXTRA_EOF'

## When to Delegate to the `bsc-planner` Agent

Use the `bsc-planner` subagent (via the Agent tool) when planning a non-trivial BSC change that requires reading many `.cbs` files to understand ownership flow — refactors, new APIs, cross-module impact analysis, anything that would burn main context. The agent is read-only and returns a plan; the main thread implements. Do NOT delegate for single-file edits, typo fixes, or borrow-checker errors on a known function — handle those directly.

## When to Invoke `bsc-learn` (At Session End)

After a non-trivial BSC coding session — any session where you modified or created `.cbs`/`.hbs` files, hit borrow-checker or ownership errors, translated C to BSC, or debugged destructor/move semantics — invoke `bsc-learn` via the Agent tool.

Pass it:
1. A brief summary of the main issues you encountered (what the checker rejected, what took iteration, what was surprising).
2. The git commit range covering this session (e.g. `HEAD~3..HEAD` or specific SHAs).

The agent reads the diff and the existing skill files, then returns proposed skill improvements as text. Present the proposals to the user for approval before applying any edits. Do NOT apply edits autonomously.

Skip `bsc-learn` for: sessions with only comment edits, single-line typo fixes, or no `.cbs` changes.
CLAUDE_EXTRA_EOF
    fi

    echo "  Claude Code: installed $count skills to .claude/skills/"
    if [ "$agent_count" -gt 0 ]; then
        echo "  Claude Code: installed $agent_count agents to .claude/agents/"
    fi
    echo "  Claude Code: added BSC syntax rules to CLAUDE.md"
    echo "    Skills auto-invoke on relevant context; also invokable as /bsc-overview, /bsc-design, etc."
}

# --- Install: Claude Code (global plugin via the official CLI) ---
# Registers the BSC marketplace and installs bisheng-c-skills@bsc through
# `claude plugin marketplace add` + `claude plugin install`. This places the
# plugin in Claude Code's registry so it shows up in /plugin and gets normal
# update/uninstall handling.
#
# Then writes per-project CLAUDE.md and prompts for compile command + optional
# clangd path. Run from inside your project directory.
install_claude_plugin() {
    local marketplace_name="bsc"
    local plugin_id="bisheng-c-skills@${marketplace_name}"
    # The marketplace source must live somewhere stable across reboots.
    # /tmp gets wiped, $SCRIPT_DIR may be /tmp/BiShengCSkills under curl-pipe,
    # so we sync into ~/.local/share/bisheng-c-skills (override via env).
    local stable_source="${BSC_PLUGIN_SOURCE:-$HOME/.local/share/bisheng-c-skills}"

    if ! command -v claude >/dev/null 2>&1; then
        echo "ERROR: 'claude' CLI not found on PATH." >&2
        echo "  Install Claude Code first (https://docs.claude.com/en/docs/claude-code)," >&2
        echo "  then re-run:  bash install.sh -a claude-plugin" >&2
        exit 1
    fi

    if [ ! -f "$SCRIPT_DIR/.claude-plugin/marketplace.json" ]; then
        echo "ERROR: $SCRIPT_DIR/.claude-plugin/marketplace.json not found." >&2
        echo "  Re-run the curl-pipe installer, or run from a fresh clone." >&2
        exit 1
    fi

    # Sync the repo into the stable location. Prefer git pull if it's already
    # a working tree we control; otherwise mirror $SCRIPT_DIR with rsync/cp.
    echo "  Claude plugin: syncing source to $stable_source"
    mkdir -p "$(dirname "$stable_source")"
    if [ -d "$stable_source/.git" ]; then
        git -C "$stable_source" fetch --quiet origin 2>/dev/null || true
        git -C "$stable_source" reset --hard origin/master --quiet 2>/dev/null \
            || git -C "$stable_source" pull --quiet 2>/dev/null \
            || true
    elif [ -d "$SCRIPT_DIR/.git" ]; then
        # Cloning from $SCRIPT_DIR (a local clone) gives the same content
        # without re-hitting the network.
        rm -rf "$stable_source"
        git clone --quiet "$SCRIPT_DIR" "$stable_source" 2>/dev/null \
            || cp -a "$SCRIPT_DIR" "$stable_source"
    else
        # No git anywhere — straight copy. Preserves modes (executable bits).
        rm -rf "$stable_source"
        cp -a "$SCRIPT_DIR" "$stable_source"
    fi

    if [ ! -f "$stable_source/.claude-plugin/marketplace.json" ]; then
        echo "ERROR: sync failed — $stable_source has no marketplace.json" >&2
        exit 1
    fi

    # Clean up any orphaned manual install from earlier installer versions.
    local orphan="$HOME/.claude/plugins/bisheng-c-skills"
    if [ -d "$orphan" ] && [ ! -L "$orphan" ]; then
        echo "  Claude plugin: removing orphaned manual install at $orphan"
        rm -rf "$orphan"
    fi

    # If the marketplace 'bsc' is already registered (possibly pointing at
    # a stale path like /tmp/BiShengCSkills from an older installer run),
    # remove it so we can re-register against $stable_source.
    if claude plugin marketplace list 2>/dev/null | grep -q '^[[:space:]]*bsc\b'; then
        echo "  Claude plugin: refreshing existing marketplace 'bsc'"
        claude plugin marketplace remove bsc >/dev/null 2>&1 || true
    fi

    # Register the marketplace from the stable source.
    echo "  Claude plugin: adding marketplace 'bsc' from $stable_source"
    claude plugin marketplace add "$stable_source" 2>&1 | sed 's/^/    /' || {
        echo "ERROR: 'claude plugin marketplace add' failed." >&2
        exit 1
    }

    # Install (or update) the plugin from that marketplace.
    echo "  Claude plugin: installing $plugin_id"
    claude plugin install "$plugin_id" 2>&1 | sed 's/^/    /' || {
        echo "ERROR: 'claude plugin install $plugin_id' failed." >&2
        exit 1
    }

    # Plugin root is wherever the CLI placed it. We find it for the clangd-config
    # write below; if we can't locate it, we fall back to the legacy path.
    local plugin_root
    plugin_root="$(find "$HOME/.claude/plugins/cache/$marketplace_name" -mindepth 2 -maxdepth 2 -type d -name 'bisheng-c-skills*' 2>/dev/null | head -1)"
    [ -z "$plugin_root" ] && plugin_root="$HOME/.claude/plugins/bisheng-c-skills"

    echo "  Claude plugin: BSC skill loads and BSC agent invocations log to ~/.claude/bsc-usage.log"

    # 2. Per-project CLAUDE.md (existing behavior, reused). Prompts for compile
    # command and clangd path. Skipped if stdin is not a tty (e.g. CI).
    local claude_md="$TARGET/CLAUDE.md"
    if [ "$LITE" = "true" ]; then
        write_always_loaded_rules_lite "$claude_md"
    else
        write_always_loaded_rules "$claude_md"
    fi

    # Use /dev/tty for prompts so that piping the installer (curl | bash, or
    # bash <(curl ...) where fd 0 may be the script fd) still gets a real tty.
    if [ -r /dev/tty ] && [ -w /dev/tty ]; then
        echo ""
        echo "  Project setup for: $TARGET"
        printf "    Compile command for THIS project (blank to leave FILL-IN): " > /dev/tty
        IFS= read -r compile_cmd < /dev/tty || compile_cmd=""
        printf "    Path to BSC-aware clangd binary (blank if none): " > /dev/tty
        IFS= read -r clangd_path < /dev/tty || clangd_path=""

        # If user gave a compile command, replace the FILL-IN block.
        if [ -n "${compile_cmd:-}" ]; then
            # Use a tmp file; sed -i differs across BSD/GNU.
            local tmp; tmp="$(mktemp)"
            awk -v cmd="$compile_cmd" '
                /^\*\*\[FILL IN: how to compile/ {
                    print "**Compile command for this project:**"
                    print ""
                    print "```"
                    print cmd
                    print "```"
                    skip = 1
                    next
                }
                skip && /^If this section still says/ { skip = 0; next }
                skip && /^If this block still says/  { skip = 0; next }
                !skip { print }
            ' "$claude_md" > "$tmp" && mv "$tmp" "$claude_md"
            echo "    Wrote compile command to CLAUDE.md"
        else
            echo "    Left FILL-IN block in CLAUDE.md — edit it before using BSC tooling"
        fi

        # If user gave a clangd path, validate and write to plugin config so the
        # custom-clangd plugin (or a future LSP integration) can pick it up.
        if [ -n "${clangd_path:-}" ]; then
            if [ -x "$clangd_path" ]; then
                printf '{\n  "clangd": "%s"\n}\n' "$clangd_path" > "$plugin_root/clangd-config.json"
                echo "    Recorded clangd at $clangd_path → $plugin_root/clangd-config.json"
            else
                echo "    WARNING: $clangd_path is not executable — skipped recording it"
            fi
        else
            echo "    Skipped clangd setup. To add later:  bash install.sh -a claude-plugin"
        fi
    else
        echo "  (non-interactive: skipped compile/clangd prompts; CLAUDE.md left with FILL-IN)"
    fi
}

# --- Install: Cursor ---
install_cursor() {
    local dst="$TARGET/.cursorrules"
    concat_all_skills > "$dst"
    echo "  Cursor: wrote .cursorrules ($(wc -l < "$dst") lines)"
}

# --- Install: Windsurf ---
install_windsurf() {
    local dst="$TARGET/.windsurfrules"
    concat_all_skills > "$dst"
    echo "  Windsurf: wrote .windsurfrules ($(wc -l < "$dst") lines)"
}

# --- Install: OpenCode ---
install_opencode() {
    local skills_dst="$TARGET/.opencode/skills"
    mkdir -p "$skills_dst"
    local count=0

    for skill_dir in "$SKILLS_DIR"/*/; do
        name="$(basename "$skill_dir")"
        src="$skill_dir/SKILL.md"
        [ -f "$src" ] || continue

        mkdir -p "$skills_dst/$name"
        cp "$src" "$skills_dst/$name/SKILL.md"
        count=$((count + 1))
    done

    # Install AGENTS.md with always-loaded BSC rules (same content as CLAUDE.md)
    if [ "$LITE" = "true" ]; then
        write_always_loaded_rules_lite "$TARGET/AGENTS.md"
    else
        write_always_loaded_rules "$TARGET/AGENTS.md"
    fi

    echo "  OpenCode: installed $count skills to .opencode/skills/"
    echo "  OpenCode: added BSC rules to AGENTS.md"
}

# --- Install: Copilot ---
install_copilot() {
    local dst_dir="$TARGET/.github"
    mkdir -p "$dst_dir"
    concat_all_skills > "$dst_dir/copilot-instructions.md"
    echo "  Copilot: wrote .github/copilot-instructions.md"
}

# --- Install: Codex ---
install_codex() {
    local dst="$TARGET/AGENTS.md"
    concat_all_skills > "$dst"
    echo "  Codex: wrote AGENTS.md ($(wc -l < "$dst") lines)"
}

# --- Uninstall ---
if [ "$ACTION" = "uninstall" ]; then
    echo "Removing BiSheng C Skills from $TARGET..."

    # Claude Code
    if [ -d "$TARGET/.claude/skills" ]; then
        for skill_dir in "$SKILLS_DIR"/*/; do
            name="$(basename "$skill_dir")"
            rm -rf "$TARGET/.claude/skills/$name"
        done
        echo "  Removed Claude Code skills"
    fi
    if [ -d "$TARGET/.claude/agents" ] && [ -d "$AGENTS_DIR" ]; then
        for agent_file in "$AGENTS_DIR"/*.md; do
            [ -f "$agent_file" ] || continue
            rm -f "$TARGET/.claude/agents/$(basename "$agent_file")"
        done
        echo "  Removed Claude Code agents"
    fi
    # Legacy path: older installs wrote to .claude/commands/
    if [ -d "$TARGET/.claude/commands" ]; then
        for skill_dir in "$SKILLS_DIR"/*/; do
            name="$(basename "$skill_dir")"
            rm -f "$TARGET/.claude/commands/$name.md"
        done
    fi

    # OpenCode
    if [ -d "$TARGET/.opencode/skills" ]; then
        for skill_dir in "$SKILLS_DIR"/*/; do
            name="$(basename "$skill_dir")"
            rm -rf "$TARGET/.opencode/skills/$name"
        done
        echo "  Removed OpenCode skills"
    fi

    # Single-file tools — only remove if it's ours
    for f in .cursorrules .windsurfrules .github/copilot-instructions.md AGENTS.md; do
        if [ -f "$TARGET/$f" ] && head -1 "$TARGET/$f" | grep -q "BiSheng C"; then
            rm -f "$TARGET/$f"
            echo "  Removed $f"
        fi
    done

    # Claude Code global plugin (legacy manual install — pre-marketplace flow)
    plugin_root="${BSC_PLUGIN_ROOT:-$HOME/.claude/plugins/bisheng-c-skills}"
    if [ -d "$plugin_root" ]; then
        rm -rf "$plugin_root"
        echo "  Removed legacy plugin dir at $plugin_root"
    fi

    # Claude Code marketplace flow — uninstall plugin, drop marketplace, drop source
    if command -v claude >/dev/null 2>&1; then
        claude plugin uninstall bisheng-c-skills@bsc >/dev/null 2>&1 \
            && echo "  Uninstalled bisheng-c-skills@bsc plugin"
        claude plugin marketplace remove bsc >/dev/null 2>&1 \
            && echo "  Removed marketplace 'bsc'"
    fi
    stable_source="${BSC_PLUGIN_SOURCE:-$HOME/.local/share/bisheng-c-skills}"
    if [ -d "$stable_source" ]; then
        rm -rf "$stable_source"
        echo "  Removed marketplace source at $stable_source"
    fi

    echo "Done."
    exit 0
fi

# --- Install ---
echo "Installing BiSheng C Skills to: $TARGET"
echo ""

case "$ADAPTER" in
    claude)         install_claude ;;
    claude-plugin)  install_claude_plugin ;;
    cursor)         install_cursor ;;
    windsurf)       install_windsurf ;;
    opencode)       install_opencode ;;
    copilot)        install_copilot ;;
    codex)          install_codex ;;
    all)
        install_claude
        install_cursor
        install_windsurf
        install_opencode
        install_copilot
        install_codex
        ;;
    *)
        echo "Unknown adapter: $ADAPTER" >&2
        echo "Supported: claude, claude-plugin, cursor, windsurf, opencode, copilot, codex, all" >&2
        exit 1
        ;;
esac

# Copy error reference if present
if [ -d "$ERRORS_DIR" ]; then
    echo ""
    echo "  Error reference available at: $SCRIPT_DIR/errors/"
    echo "  (AI-friendly JSON: $SCRIPT_DIR/errors/ai/bsc-errors.json)"
fi

echo ""
echo "Done! Skills are now available in your project."
