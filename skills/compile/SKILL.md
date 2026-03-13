---
name: bsc-compile
description: "BiSheng C compilation. When you need to understand how to compile .cbs files, compiler path setup, include paths, diagnostic suppression flags, syntax checking, or source-to-source rewriting, use this Skill."
---

# BiSheng C Compilation Skill

## 1. Compiler Path Setup

The BSC compiler is a custom clang build — it is NOT the system `clang`. Before compiling, you need the path to the BSC clang binary.

**Where to find the path:** Check the project's `CLAUDE.md` (or `.cursorrules` / `AGENTS.md`) for a line like:

```
BSC compiler path: /path/to/bsc/bin/clang
```

If no path is configured, ask the user. Then use the full path in all compile commands:

```bash
/path/to/bsc/bin/clang file.cbs -o output
```

**Recommended project setup:** Add the compiler path to `CLAUDE.md` so the AI always knows where to find it:

```markdown
## BSC Compiler
- Path: /home/user/bsc/build/bin/clang
- libcbs include: /home/user/bsc/libcbs/src
```

## 2. Basic Usage

```bash
# Compile to executable
/path/to/bsc/bin/clang file.cbs -o output

# With optimization
/path/to/bsc/bin/clang file.cbs -O2 -o output

# Syntax check only (no binary output)
/path/to/bsc/bin/clang -fsyntax-only file.cbs

# With warnings
/path/to/bsc/bin/clang -Wall -Wextra file.cbs -o output

# With debug info
/path/to/bsc/bin/clang -g file.cbs -o output
/path/to/bsc/bin/clang -g -gdwarf-4 file.cbs -o output  # better gdb compat
```

## 3. Include Paths

BSC has two include directories that may need `-I` flags:

| Path | Contains |
|------|----------|
| `libcbs/src/` | Standard library headers (`vec.hbs`, `string.hbs`, etc.) |
| `clang/lib/Headers/bsc_include/` | Built-in headers (`bsc_type_traits.hbs`, `future.hbs`, etc.) |

```bash
/path/to/bsc/bin/clang -I/path/to/libcbs/src -I/path/to/bsc_include file.cbs -o output
```

## 4. Special Modes

```bash
# Source-to-source rewrite (BSC → C)
/path/to/bsc/bin/clang -rewrite-bsc file.cbs
# Produces file.c with BSC features lowered to plain C

# Rewrite with include path (needed for stdlib types)
/path/to/bsc/bin/clang -rewrite-bsc file.cbs -I/path/to/libcbs/src

# Rewrite with explicit output
/path/to/bsc/bin/clang -rewrite-bsc file.cbs -o output.c

# Rewrite multiple files
/path/to/bsc/bin/clang -rewrite-bsc foo.cbs bar.cbs

# Rewrite with line-number mapping (for debugging)
/path/to/bsc/bin/clang -rewrite-bsc -line file.cbs -o file.c

# AST dump
/path/to/bsc/bin/clang -Xclang -ast-dump -fsyntax-only file.cbs
```

## 5. Diagnostic Suppression

BSC safety checks are errors by default. To suppress specific diagnostics, use `-Eno-<identifier>` on the command line or `#pragma` in source.

### Command-line suppression: `-Eno-<identifier>`

```bash
# Suppress repeated-borrow errors
/path/to/bsc/bin/clang -Eno-repeated-borrow file.cbs

# Suppress all borrow checks
/path/to/bsc/bin/clang -Eno-bsc-borrow file.cbs

# Suppress all BSC safety checks
/path/to/bsc/bin/clang -Eno-bsc-safety-check file.cbs
```

### In-source suppression: `#pragma`

```c
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Eassign-borrowed"
*p1 = 2;  // this error is now suppressed
#pragma GCC diagnostic pop
```

### Diagnostic identifier hierarchy

```
bsc-safety-check                    # All BSC safety checks
├── bsc-nullability                 # All nullability checks
│   ├── deref-nullable              #   Dereference nullable pointer
│   ├── pass-nullable               #   Pass nullable as argument
│   ├── return-nullable             #   Return nullable pointer
│   ├── cast-nullable               #   Cast nullable to nonnull
│   ├── assign-nullable             #   Access member through nullable
│   └── assign-nonnull              #   Assign nullable to nonnull
├── bsc-ownership                   # All ownership checks
│   ├── use-owned                   #   Use-after-move/uninit group
│   │   ├── use-moved-owned         #     Use after move
│   │   └── use-uninit-owned        #     Use uninitialized
│   ├── assign-owned                #   Assign to owned group
│   │   ├── assign-moved-owned      #     Assign to moved value
│   │   └── assign-uninit-owned     #     Assign to part of uninit
│   ├── cast-owned                  #   Invalid cast to void *_Owned
│   │   └── cast-moved-owned        #     Cast moved value
│   ├── check-memory-leak           #   Memory leak detection
│   ├── init-nonnull                #   _Nonnull pointer not initialized
│   ├── destruct-owned-struct       #   Destructor incorrect
│   └── partially-moved-struct      #   Partially moved at scope end
└── bsc-borrow                      # All borrow checks
    ├── assign-borrowed             #   Assign to borrowed value
    ├── move-borrowed               #   Move borrowed value
    ├── use-mutably-borrowed        #   Use while mutably borrowed
    ├── repeated-borrow             #   Multiple mutable borrows
    ├── return-local-borrow         #   Return reference to local
    └── short-life-borrow           #   Lifetime too short
```

> For error messages and codes, see `bsc-errors` Skill
