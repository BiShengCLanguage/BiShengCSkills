# BiSheng C Skills

AI Skills for BiSheng C (BSC) — a memory-safe superset of C with Rust-inspired ownership, borrowing, traits, generics, and async/await.

These Skills enable AI coding tools to generate syntactically and semantically correct BSC code, despite never having been trained on it.

> Inspired by [CangjieSkills](https://gitcode.com/Cangjie-SIG/CangjieSkills)

## Quick Install

**One-liner** — no manual clone needed:

```bash
# Install for all tools (Claude, Cursor, Windsurf, OpenCode, Copilot)
curl -fsSL https://gitee.com/bisheng_c_language_dep/BiShengCSkills/raw/master/install.sh | bash

# Install for a specific tool only
curl -fsSL https://gitee.com/bisheng_c_language_dep/BiShengCSkills/raw/master/install.sh | bash -s -- -a claude
curl -fsSL https://gitee.com/bisheng_c_language_dep/BiShengCSkills/raw/master/install.sh | bash -s -- -a cursor
curl -fsSL https://gitee.com/bisheng_c_language_dep/BiShengCSkills/raw/master/install.sh | bash -s -- -a opencode
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
bash install.sh -a all       # All of the above
```

### What gets installed

| Tool | Where | Format |
|------|-------|--------|
| **Claude Code** | `.claude/commands/<skill>.md` | One command per skill → `/bsc-trait`, `/bsc-ownership`, etc. |
| **Cursor** | `.cursorrules` | All skills concatenated into single rules file |
| **Windsurf** | `.windsurfrules` | All skills concatenated into single rules file |
| **OpenCode** | `.opencode/skills/<skill>/SKILL.md` | One skill per directory (native format) |
| **Copilot** | `.github/copilot-instructions.md` | All skills concatenated into instructions file |

### Uninstall

```bash
bash install.sh --uninstall /path/to/your/project
```

## Usage

### Claude Code (CLI or VSCode)

```
> /bsc-overview
> /bsc-trait Write a program with dynamic dispatch using _Trait
> /bsc-ownership Create a linked list with _Owned pointers
> /bsc-common-mistakes Fix my code that uses & in a _Safe zone
```

### Cursor / Windsurf / Copilot

Skills are automatically loaded as project context. Just write BSC code — the AI will reference the rules.

### OpenCode

Skills auto-trigger based on their description field. When you ask about ownership, the `bsc-ownership` Skill is automatically referenced.

## Available Skills (13)

| Skill | When triggered | Description |
|-------|---------------|-------------|
| `bsc-overview` | BSC basics, file types, features | Language overview and syntax summary |
| `bsc-member-function` | `TypeName::method`, `this`, `This` | Methods on structs, primitives, static methods |
| `bsc-generic` | `<T>`, generic struct, constant generic | Generic functions, structs, type aliases, deduction |
| `bsc-trait` | `_Trait`, `_Impl`, trait pointer | Trait definition, implementation, dynamic dispatch |
| `bsc-ownership` | `_Owned`, destructor, RAII | Move semantics, owned pointers, owned structs |
| `bsc-borrowing` | `_Borrow`, `&_Const`, `&_Mut` | Immutable/mutable borrows, lifetime rules |
| `bsc-safe-zone` | `_Safe`, `_Unsafe` | Safe zone restrictions, unsafe escape |
| `bsc-coroutine` | `_Async`, `_Await`, `Future` | Stackless coroutines, poll/free |
| `bsc-constexpr` | `constexpr`, `if constexpr`, type traits | Compile-time evaluation, type-specialized branches |
| `bsc-stdlib` | `Vec<T>`, `String`, `Option` | Standard library types and APIs |
| `bsc-compile` | compiler flags, `-fsyntax-only` | Compilation, include paths, diagnostic flags |
| `bsc-errors` | `BSC-Exxxx`, error codes | Error code reference, diagnostic hierarchy |
| `bsc-common-mistakes` | compilation errors, pitfalls | Common mistakes with wrong/right examples |

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
│   ├── member-function/SKILL.md
│   ├── generic/SKILL.md
│   ├── trait/SKILL.md
│   ├── ownership/SKILL.md
│   ├── borrowing/SKILL.md
│   ├── safe-zone/SKILL.md
│   ├── coroutine/SKILL.md
│   ├── constexpr/SKILL.md
│   ├── stdlib/SKILL.md
│   ├── compile/SKILL.md
│   ├── errors/SKILL.md
│   └── common-mistakes/SKILL.md
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

3. Submit a Pull Request
