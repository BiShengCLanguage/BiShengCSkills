---
name: bsc-compile
description: "BiSheng C compilation. When you need to understand how to compile .cbs files, compiler flags, include paths, syntax checking, source-to-source rewriting, or the bsc-validate.sh script, use this Skill."
---

# BiSheng C Compilation Skill

## 1. Basic Usage

```bash
# Compile to executable
clang file.cbs -o output

# With optimization
clang file.cbs -O2 -o output

# Syntax check only (no binary output)
clang -fsyntax-only file.cbs

# With warnings
clang -Wall -Wextra file.cbs -o output
```

## 2. Include Paths

BSC has two include directories that may need `-I` flags:

| Path | Contains |
|------|----------|
| `libcbs/src/` | Standard library headers (`vec.hbs`, `string.hbs`, etc.) |
| `clang/lib/Headers/bsc_include/` | Built-in headers (`bsc_type_traits.hbs`, `future.hbs`, etc.) |

```bash
clang -I/path/to/libcbs/src -I/path/to/bsc_include file.cbs -o output
```

## 3. Special Modes

```bash
# Source-to-source rewrite (BSC → C)
clang -rewrite-bsc file.cbs
# Produces file.c with BSC features lowered to plain C

# AST dump
clang -Xclang -ast-dump -fsyntax-only file.cbs
```

## 4. BSC Diagnostic Flags

```
-Wbsc-safety-check          # All BSC safety checks
  -Wbsc-ownership            # All ownership checks
    -Wuse-moved-owned         # Use after move
    -Wuse-uninit-owned        # Use uninitialized
    -Wassign-owned            # Assign to owned
    -Wcast-owned              # Cast owned
    -Wcheck-memory-leak       # Memory leaks
  -Wbsc-borrow               # All borrow checks
    -Wassign-borrowed         # Assign while borrowed
    -Wmove-borrowed           # Move while borrowed
    -Wuse-mutably-borrowed    # Use while mutably borrowed
    -Wrepeated-borrow         # Multiple mutable borrows
    -Wreturn-local-borrow     # Return local reference
    -Wshort-life-borrow       # Lifetime too short
  -Wbsc-nullability           # All nullability checks
    -Wderef-nullable          # Deref nullable
    -Wpass-nullable            # Pass nullable
    -Wreturn-nullable          # Return nullable
```

## 5. bsc-validate.sh Script

A wrapper script for compiler-in-the-loop workflows:

```bash
bsc-validate.sh file.cbs              # Syntax + semantic check
bsc-validate.sh --compile file.cbs    # Compile to binary
bsc-validate.sh --run file.cbs        # Compile and run
bsc-validate.sh --rewrite file.cbs    # BSC → C transform
bsc-validate.sh --fix file.cbs        # Structured JSON diagnostics for LLM repair
echo '<code>' | bsc-validate.sh --stdin
```

### Exit codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Compilation errors |
| 2 | Runtime error |
| 3 | Usage error |

### Environment variables

| Var | Purpose |
|-----|---------|
| `BSC_COMPILER` | Path to BSC clang (default: auto-detect) |
| `BSC_INCLUDE` | Path to libcbs include dir (default: auto-detect) |

> For error codes and diagnostics, see `bsc-errors` Skill
