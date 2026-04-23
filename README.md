# BiSheng C Skills

AI Skills for BiSheng C (BSC) — a memory-safe superset of C with Rust-inspired ownership, borrowing, traits, generics, and async/await.

These Skills enable AI coding tools to generate syntactically and semantically correct BSC code, despite never having been trained on it.

## Quick Install

**One-liner** — no manual clone needed:

```bash
# Install for all tools (Claude, Cursor, Windsurf, OpenCode, Copilot, Codex)
curl -fsSL https://gitee.com/bisheng_c_language_dep/BiShengCSkills/raw/master/install.sh | bash

# Install for a specific tool only
curl -fsSL https://gitee.com/bisheng_c_language_dep/BiShengCSkills/raw/master/install.sh | bash -s -- -a claude
curl -fsSL https://gitee.com/bisheng_c_language_dep/BiShengCSkills/raw/master/install.sh | bash -s -- -a cursor
curl -fsSL https://gitee.com/bisheng_c_language_dep/BiShengCSkills/raw/master/install.sh | bash -s -- -a opencode
curl -fsSL https://gitee.com/bisheng_c_language_dep/BiShengCSkills/raw/master/install.sh | bash -s -- -a codex
```

### If you prefer to clone first

```bash
git clone git@gitee.com:bisheng_c_language_dep/BiShengCSkills.git
cd BiShengCSkills
bash install.sh -a claude    # Claude Code CLI / VSCode extension
bash install.sh -a cursor    # Cursor IDE
bash install.sh -a windsurf  # Windsurf IDE
bash install.sh -a opencode  # OpenCode
bash install.sh -a copilot   # GitHub Copilot
bash install.sh -a codex     # OpenAI Codex CLI
bash install.sh -a all       # All of the above
```

### What gets installed

| Tool | Where | How it works |
|------|-------|--------------|
| **Claude Code** | `.claude/skills/` + `.claude/agents/` + `CLAUDE.md` | Skills auto-invoke based on context; agents run on demand; CLAUDE.md loads BSC syntax rules on every session |
| **Cursor** | `.cursorrules` | All skills concatenated with critical rules header |
| **Windsurf** | `.windsurfrules` | All skills concatenated with critical rules header |
| **OpenCode** | `.opencode/skills/<skill>/SKILL.md` | One skill per directory (native format, auto-triggers) |
| **Copilot** | `.github/copilot-instructions.md` | All skills concatenated with critical rules header |
| **Codex** | `AGENTS.md` | All skills concatenated with critical rules header |

### Lite Mode (for less-capable models)

If you're using a weaker model (smaller local LLM, older model, or one that struggles with many skills at once), install the lite version: 5 condensed skills + a 28-line always-loaded rules file.

```bash
bash install.sh -a claude --lite              # Claude Code lite (5 skills, no agents)
bash install.sh -a opencode --lite            # OpenCode lite
```

**Lite includes only**: `bsc-ownership`, `bsc-borrowing`, `bsc-safe-zone`, `bsc-nullability`, and `c-to-bsc` (the `c-to-bsc` lite version always keeps `.c`/`.h` extensions and uses `-x bsc` — no renaming).

Lite mode skips: agents (bsc-planner, bsc-learn), advanced skills (traits, generics, coroutines, stdlib, LSP, etc.), and the Working Principles section.

### Uninstall

```bash
bash install.sh --uninstall /path/to/your/project
```

## Usage

### Claude Code (CLI or VSCode)

Skills auto-invoke when you're working on relevant BSC code — no explicit invocation needed in most cases. You can also load them explicitly:

```
/bsc-design          ← load BEFORE planning any non-trivial BSC change
/c-to-bsc            ← load BEFORE translating C code to BSC
/bsc-lsp             ← load to inspect ownership flow via clangd hover
/bsc-ownership       ← move semantics, _Owned structs, destructors
/bsc-borrowing       ← _Borrow, &_Const, &_Mut, lifetime rules
/bsc-safe-zone       ← _Safe/_Unsafe restrictions and patterns
```

Two planning agents are also available via the Agent tool (the main agent delegates to them automatically per `CLAUDE.md`):

- **`bsc-planner`** — researches ownership flow across `.cbs` files and returns a plan before non-trivial changes
- **`bsc-learn`** — reviews a completed session's git diff and proposes skill improvements for approval

### Cursor / Windsurf / Copilot / Codex

Skills are automatically loaded as project context. Just write BSC code — the AI will reference the rules.

### OpenCode

Skills auto-trigger based on their description field. When you ask about ownership, the `bsc-ownership` Skill is automatically referenced.

## Available Skills (20)

| Skill | Triggers on | Description |
|-------|-------------|-------------|
| `bsc-overview` | BSC basics, file types, features | Language overview and syntax summary |
| `bsc-design` | New APIs, structs, ownership flow design, `_Safe`/`_Unsafe` boundary | Design rules for BSC-first APIs — load at planning time |
| `bsc-ownership` | `_Owned`, destructor, RAII, move semantics | Owned pointers, owned structs, safe_malloc/safe_free |
| `bsc-borrowing` | `_Borrow`, `&_Const`, `&_Mut` | Immutable/mutable borrows, lifetime rules, NLL |
| `bsc-safe-zone` | `_Safe`, `_Unsafe`, safe zone errors | Safe zone restrictions, pointer conversion matrix, unsafe escape |
| `bsc-nullability` | `_Nullable`, `_Nonnull`, null checks | Compile-time nullability tracking, null-check patterns |
| `bsc-member-function` | `TypeName::method`, `this`, `This` | Methods on structs and primitives, static methods |
| `bsc-trait` | `_Trait`, `_Impl`, dynamic dispatch | Trait definition, implementation, trait pointers |
| `bsc-generic` | `<T>`, generic struct, constant generic | Generic functions, structs, type aliases, deduction |
| `bsc-operator-overloading` | `operator`, `[]`, `->`, `+`, `==` | Operator overloading via `__attribute__((operator OP))` |
| `bsc-coroutine` | `_Async`, `_Await`, `Future`, `Scheduler` | Stackless coroutines, poll/free, concurrent tasks |
| `bsc-constexpr` | `constexpr`, `if constexpr`, type traits | Compile-time evaluation, type-specialized branches |
| `bsc-initialization` | Uninitialized variables, `ensure_init` | Field-level init tracking, `-uninit-check` |
| `bsc-stdlib` | `Vec<T>`, `String`, `Option`, `Result` | Standard library core types and APIs |
| `bsc-stdlib-advanced` | `Rc<T>`, `Weak<T>`, `RefCell<T>`, `HashMap` | Advanced stdlib: shared ownership, interior mutability |
| `bsc-lsp` | Ownership flow, live ranges, clangd hover | BSC-aware clangd: hover events, known limitations, Grep fallback |
| `bsc-compile` | Compiler flags, `-fsyntax-only`, include paths | Compilation, diagnostics, source-to-source rewriting |
| `bsc-errors` | `BSC-Exxxx`, error codes | Error code reference and fix strategies |
| `bsc-common-mistakes` | Compilation errors, pitfalls | Common mistakes with wrong/right examples |
| `c-to-bsc` | Translating C to BSC, ownership annotations | Step-by-step C→BSC translation — load before starting |

## Agents (Claude Code only)

| Agent | When used | What it does |
|-------|-----------|--------------|
| `bsc-planner` | Before non-trivial BSC changes | Reads `.cbs` files, traces ownership flow, returns a plan. Read-only. |
| `bsc-learn` | After a BSC coding session | Reads the session's git diff and existing skills, proposes skill improvements for approval. Read-only. |

## Error Reference

The `errors/` directory contains comprehensive documentation for all BSC compiler diagnostics:

- Per-category markdown docs (ownership, borrow, safe-zone, traits, etc.)
- `errors/ai/bsc-errors.json` — Structured JSON for LLM/IDE integration
- `errors/ai/bsc-errors.schema.json` — JSON schema
- `errors/ai/error-code-mapping.json` — Diagnostic name to error code mapping

## Project Structure

```
BiShengCSkills/
├── install.sh                          ← one-command installer
├── README.md
├── skills/
│   ├── bsc-overview/SKILL.md
│   ├── bsc-design/SKILL.md
│   ├── bsc-ownership/SKILL.md
│   ├── bsc-borrowing/SKILL.md
│   ├── bsc-safe-zone/SKILL.md
│   ├── bsc-nullability/SKILL.md
│   ├── bsc-member-function/SKILL.md
│   ├── bsc-trait/SKILL.md
│   ├── bsc-generic/SKILL.md
│   ├── bsc-operator-overloading/SKILL.md
│   ├── bsc-coroutine/SKILL.md
│   ├── bsc-constexpr/SKILL.md
│   ├── bsc-initialization/SKILL.md
│   ├── bsc-stdlib/SKILL.md
│   ├── bsc-stdlib-advanced/SKILL.md
│   ├── bsc-lsp/SKILL.md
│   ├── bsc-compile/SKILL.md
│   ├── bsc-errors/SKILL.md
│   ├── bsc-common-mistakes/SKILL.md
│   └── c-to-bsc/SKILL.md
├── agents/
│   ├── bsc-planner.md                  ← planning agent (Claude Code)
│   └── bsc-learn.md                    ← session-learning agent (Claude Code)
└── errors/
    ├── README.md
    ├── ownership.md, borrow.md, ...
    └── ai/
        ├── bsc-errors.json
        ├── bsc-errors.schema.json
        └── error-code-mapping.json
```

## Contributing

1. Fork this repository
2. Add or update skills following the `SKILL.md` format:

```yaml
---
name: bsc-<feature>
description: "BiSheng C <feature>. When you need to understand <topics>, use this Skill."
---

# BiSheng C <Feature> Skill

## 1. Overview
...
## 2. Syntax
...
## 3. Rules
...
## 4. Complete Example
...
```

3. To add an agent, create `agents/<name>.md` with frontmatter: `name`, `description`, `tools`, `model`.
4. Submit a Pull Request
