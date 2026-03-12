---
name: bsc-errors
description: "BiSheng C error codes and diagnostics. When you encounter a BSC compiler error (BSC-Exxxx), need to understand what an error means, or want to look up fix strategies for specific diagnostics, use this Skill."
---

# BiSheng C Error Codes Skill

## 1. Error Code Scheme

BSC errors use the format `BSC-Exxxx` (errors) and `BSC-Wxxxx` (warnings), grouped by category:

| Range | Category | Description |
|-------|----------|-------------|
| BSC-E01xx | Ownership | Use-after-move, uninitialized, assign, cast, memory leak |
| BSC-E02xx | Borrow Checking | Lifetime, multiple borrows, assign-while-borrowed |
| BSC-E03xx | Safe Zone | Forbidden operations in `_Safe` functions/blocks |
| BSC-E04xx | Nullability | Deref/pass/return/cast nullable pointers |
| BSC-E05xx | Traits | Undefined traits, unimplemented functions, type conflicts |
| BSC-E06xx | Owned Struct / Destructor | Struct tags, destructors, member issues |
| BSC-E07xx | Type System | `_Owned`/`_Borrow` qualifier conflicts, incompatible casts |
| BSC-E08xx | Async | `_Async`/`_Await` usage |
| BSC-E09xx | Generics / Constexpr | Generic function issues, constexpr limitations |
| BSC-E10xx | Parse-level | BSC-specific syntax errors |
| BSC-E11xx | Member Functions | Instance members, attributes |
| BSC-E12xx | Operator Overload | Overload restrictions |

## 2. Diagnostic Flags

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

## 3. AI-Friendly Database

For LLM/IDE integration, the `errors/ai/` directory contains:

- `bsc-errors.json` — Structured JSON database of all errors with cause, fix strategies, code examples, and keywords
- `bsc-errors.schema.json` — JSON schema
- `error-code-mapping.json` — Maps diagnostic names to error codes

## 4. Common Errors Quick Reference

### Ownership (BSC-E01xx)

| Code | Message | Fix |
|------|---------|-----|
| E0101 | Use of moved value | Use variable before transferring ownership |
| E0104 | Use of uninitialized value | Initialize before use |
| E0106 | Assign to _Owned value | Release old value first, or use a new variable |
| E0115 | Memory leak (owned not released) | Free, return, or transfer before scope ends |

### Borrow (BSC-E02xx)

| Code | Message | Fix |
|------|---------|-----|
| E0201 | Assign while immutably borrowed | End borrow before modifying |
| E0203 | Use while mutably borrowed | Don't read original while mutable borrow active |
| E0204 | Multiple mutable borrows | Only one `&_Mut` at a time |
| E0205 | Return local borrow | Return by value instead, or take borrow param |
| E0206 | Borrow lifetime too short | Ensure borrowed value outlives the borrow |

### Safe Zone (BSC-E03xx)

| Code | Message | Fix |
|------|---------|-----|
| E0301 | Raw `&` in safe zone | Use `&_Const` or `&_Mut` |
| E0302 | `++`/`--` in safe zone | Use `x += 1` |
| E0303 | `goto` in safe zone | Restructure control flow |
| E0304 | Calling unsafe function | Wrap in `_Unsafe { }` |

> For detailed per-category documentation, see the `errors/` directory
> For common fixes, see `bsc-common-mistakes` Skill
