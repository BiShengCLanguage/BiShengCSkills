# BSC Error Reference Guide

This directory contains comprehensive documentation for all BishengC (BSC) compiler diagnostics, organized by category. Each error includes its cause, example code, and fix strategies.

## Error Code Scheme

BSC errors use the format `BSC-Exxxx` (errors) and `BSC-Wxxxx` (warnings), grouped by category:

| Range | Category | Doc |
|-------|----------|-----|
| BSC-E01xx | [Ownership](ownership.md) | Use-after-move, uninitialized, assign, cast, memory leak |
| BSC-E02xx | [Borrow Checking](borrow.md) | Lifetime, multiple borrows, assign-while-borrowed |
| BSC-E03xx | [Safe Zone](safe-zone.md) | Forbidden operations in `_Safe` functions/blocks |
| BSC-E04xx | [Nullability](nullability.md) | Deref/pass/return/cast nullable pointers |
| BSC-E05xx | [Traits](traits.md) | Undefined traits, unimplemented functions, type conflicts |
| BSC-E06xx | [Owned Struct / Destructor](owned-struct.md) | Struct tags, destructors, member issues |
| BSC-E07xx | [Type System](type-system.md) | `_Owned`/`_Borrow` qualifier conflicts, incompatible casts |
| BSC-E08xx | [Async](async.md) | `_Async`/`_Await` usage |
| BSC-E09xx | [Generics / Constexpr](generics-constexpr.md) | Generic function issues, constexpr limitations |
| BSC-E10xx | Parse-level | BSC-specific syntax errors |
| BSC-E11xx | [Member Functions](member-functions.md) | Instance members, attributes |
| BSC-E12xx | [Operator Overload](operator-overload.md) | Overload restrictions |

## AI-Friendly Database

For LLM / IDE integration, see [`ai/bsc-errors.json`](ai/bsc-errors.json) — a structured JSON database of all errors with cause explanations, fix strategies, code examples, and semantic keywords.

- Schema: [`ai/bsc-errors.schema.json`](ai/bsc-errors.schema.json)
- Error code mapping: [`ai/error-code-mapping.json`](ai/error-code-mapping.json)

## Controlling BSC Diagnostics

BSC diagnostics can be controlled with standard Clang warning flags:

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

## See Also

- [BiShengC Language User Manual](../BiShengCLanguageUserManual.md)
