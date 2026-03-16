#!/bin/bash
# install.sh — Install BiSheng C Skills for AI coding tools
#
# One-liner install (no manual clone needed):
#   curl -fsSL https://gitee.com/bisheng_c_language_dep/BiShengCSkills/raw/master/install.sh | bash
#   curl -fsSL https://gitee.com/bisheng_c_language_dep/BiShengCSkills/raw/master/install.sh | bash -s -- -a claude
#
# Or with git:
#   bash <(curl -fsSL https://gitee.com/bisheng_c_language_dep/BiShengCSkills/raw/master/install.sh)
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
#   claude    — Claude Code CLI / VSCode extension (.claude/commands/)
#   cursor    — Cursor IDE (.cursorrules)
#   windsurf  — Windsurf IDE (.windsurfrules)
#   opencode  — OpenCode (.opencode/skills/)
#   copilot   — GitHub Copilot (.github/copilot-instructions.md)
#   codex     — OpenAI Codex CLI (AGENTS.md)

set -euo pipefail

REPO_URL="https://gitee.com/bisheng_c_language_dep/BiShengCSkills.git"
REPO_SSH="git@gitee.com:bisheng_c_language_dep/BiShengCSkills.git"
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
ERRORS_DIR="$SCRIPT_DIR/errors"
ADAPTER="all"
TARGET="."
ACTION="install"

# --- Parse args ---
while [ $# -gt 0 ]; do
    case "$1" in
        -a|--adapter)  ADAPTER="$2"; shift 2 ;;
        --uninstall)   ACTION="uninstall"; shift ;;
        --list)        ACTION="list"; shift ;;
        -h|--help)     ACTION="help"; shift ;;
        *)             TARGET="$1"; shift ;;
    esac
done

TARGET="$(cd "$TARGET" && pwd)"

# --- Help ---
if [ "$ACTION" = "help" ]; then
    echo "Usage: install.sh [-a adapter] [--uninstall] [--list] [project_dir]"
    echo ""
    echo "Adapters: claude, cursor, windsurf, opencode, copilot, codex, all"
    echo ""
    echo "Examples:"
    echo "  bash install.sh                    # auto-detect tools, install to current dir"
    echo "  bash install.sh -a claude          # Claude Code only"
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
        sed '1,/^---$/d; 1,/^---$/d' "$src"
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
    sed '1,/^---$/d; 1,/^---$/d' "$1"
}

# --- Install: Claude Code ---
install_claude() {
    local cmd_dir="$TARGET/.claude/commands"
    mkdir -p "$cmd_dir"
    local count=0

    for skill_dir in "$SKILLS_DIR"/*/; do
        name="$(basename "$skill_dir")"
        src="$skill_dir/SKILL.md"
        [ -f "$src" ] || continue

        desc=$(get_desc "$src")
        body=$(strip_frontmatter "$src")

        # Claude Code format: first line = description, $ARGUMENTS, then content
        printf '%s\n\n$ARGUMENTS\n\n%s\n' "$desc" "$body" > "$cmd_dir/$name.md"
        count=$((count + 1))
    done

    # Install CLAUDE.md with syntax rules (always-loaded context)
    local claude_md="$TARGET/CLAUDE.md"
    if [ ! -f "$claude_md" ] || ! grep -q "BiSheng C" "$claude_md" 2>/dev/null; then
        cat >> "$claude_md" << 'CLAUDE_EOF'

# BiSheng C (BSC) — MUST READ before writing any .cbs code

## Pointer Qualifier Grammar (CRITICAL)

`_Owned` and `_Borrow` are **pointer qualifiers**, like `const`. They go AFTER `*`, NEVER before the type.

Grammar: `base_type *qualifier variable_name`

Think of it like `const`: you write `int *const p`, not `const int* p` for a const pointer.
Same rule: `int *_Owned p`, not `_Owned int* p`.

### Correct Examples

```c
char *_Owned msg = (char *_Owned)malloc(14);      // owned pointer to char
int *_Owned p = (int *_Owned)malloc(sizeof(int));  // owned pointer to int
const int *_Borrow r = &_Const x;                  // immutable borrow
int *_Borrow mr = &_Mut y;                         // mutable borrow
void *_Owned vp = (void *_Owned)malloc(n);         // owned void pointer
free((void *_Owned)p);                             // free requires cast
```

### Wrong — causes compilation error: "unknown type name '_Owned'"

```c
_Owned char* msg = malloc(14);     // WRONG — _Owned is not a type
_Borrow int* r = &_Const x;       // WRONG — _Borrow is not a type
_Owned int *p = malloc(4);        // WRONG — qualifier before type
```

## Self-Check (do this before returning BSC code)

Scan every pointer declaration in your output. If you wrote `_Owned T*` or `_Borrow T*`,
STOP and rewrite: move the qualifier to after `*`. The pattern is ALWAYS `T *_Owned`.

## Quick Reference

- Files: `.cbs` (source), `.hbs` (header)
- Compile: `clang file.cbs -o output`
- `#include "bishengc_safety.hbs"` for safe allocation APIs
- **Prefer `safe_malloc<T>(val)`** — returns `T *_Owned` directly, no cast needed
- **Prefer `safe_free((void *_Owned)p)`** — frees an owned pointer
- Raw `malloc`/`free` require `_Unsafe` context and `(T *_Owned)` cast

## C-to-BSC Translation

If you are translating/porting C code to BSC, you MUST load the `/c-to-bsc` skill BEFORE starting.
Changing file extensions alone is NOT a translation — every pointer must be analyzed and annotated with `_Owned`, `_Borrow`, or left raw where appropriate. Every `malloc` should become `safe_malloc` where possible.
CLAUDE_EOF
    fi

    echo "  Claude Code: installed $count commands to .claude/commands/"
    echo "  Claude Code: added BSC syntax rules to CLAUDE.md"
    echo "    Usage: /bsc-overview, /bsc-trait, /bsc-ownership, etc."
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

    echo "  OpenCode: installed $count skills to .opencode/skills/"
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
    if [ -d "$TARGET/.claude/commands" ]; then
        for skill_dir in "$SKILLS_DIR"/*/; do
            name="$(basename "$skill_dir")"
            rm -f "$TARGET/.claude/commands/$name.md"
        done
        echo "  Removed Claude Code commands"
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

    echo "Done."
    exit 0
fi

# --- Install ---
echo "Installing BiSheng C Skills to: $TARGET"
echo ""

case "$ADAPTER" in
    claude)    install_claude ;;
    cursor)    install_cursor ;;
    windsurf)  install_windsurf ;;
    opencode)  install_opencode ;;
    copilot)   install_copilot ;;
    codex)     install_codex ;;
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
        echo "Supported: claude, cursor, windsurf, opencode, copilot, codex, all" >&2
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
