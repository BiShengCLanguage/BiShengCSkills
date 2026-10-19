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

## 2. Diagnostic Suppression Flags

Suppress with `-Eno-<identifier>` on command line or `#pragma GCC diagnostic ignored "-E<identifier>"` in source:

```
bsc-safety-check              # All BSC safety checks
├── bsc-ownership             # All ownership checks
│   ├── use-moved-owned       #   Use after move
│   ├── use-uninit-owned      #   Use uninitialized
│   ├── assign-owned          #   Assign to owned
│   ├── cast-owned            #   Cast owned
│   └── check-memory-leak     #   Memory leaks
├── bsc-borrow                # All borrow checks
│   ├── assign-borrowed       #   Assign while borrowed
│   ├── move-borrowed         #   Move while borrowed
│   ├── use-mutably-borrowed  #   Use while mutably borrowed
│   ├── repeated-borrow       #   Multiple mutable borrows
│   ├── return-local-borrow   #   Return local reference
│   └── short-life-borrow     #   Lifetime too short
└── bsc-nullability           # All nullability checks
    ├── deref-nullable        #   Deref nullable
    ├── pass-nullable         #   Pass nullable
    └── return-nullable       #   Return nullable
```

> For full hierarchy and usage examples, see `bsc-compile` Skill.

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
| E0115 | Invalid cast of _Owned value | Don't cast an _Owned pointer that still holds ownership |
| E0118 | Memory leak (owned not freed) | Free, return, or transfer before scope ends |
| E0119 | Field memory leak | Free _Owned struct fields before scope ends |
| E0126 | Temporary variable memory leak | Capture return value of _Owned-returning function |
| *(OWN-050)* | __forget requires an _Owned pointer or a struct containing ownership | Pass an `_Owned` pointer or a struct with (nested) `_Owned` fields; `_Borrow`/raw/`_Nonnull`/non-pointer/plain struct are rejected |
| *(OWN-051)* | __forget requires a trackable expression as argument | Variable, field access, array element or deref chain only (parens/implicit casts ok); bind comma/ternary/explicit-cast values to a local first |

### Borrow (BSC-E02xx)

| Code | Message | Fix |
|------|---------|-----|
| E0201 | Cannot assign to borrowed variable | End borrow before modifying |
| E0202 | Cannot move out of borrowed variable | End borrow before moving |
| E0203 | Cannot use mutably borrowed variable | Read through the borrow pointer instead |
| E0204 | Cannot borrow as mutable more than once | Only one `&_Mut` at a time |
| E0207 | Cannot return reference to local variable | Return by value or use `_Owned` heap allocation |
| E0208 | Value does not live long enough | Ensure borrowed value outlives the borrow |
| *(BOR-014)* | cannot take ownership of a borrowed value | Since 2026-09 also fires for array **parameters** with owned elements (note: `array parameter 'a' is adjusted to a '_Borrow _ArrayElem' pointer; its elements are borrowed and cannot be moved out`) — `safe_swap` or pass `T *_Owned _ArrayElem` |
| *(BOR-022)* | expression is not assignable / cannot be mutably borrowed / cannot be mutably reborrowed because it is behind an immutable borrow | Anything reached through `&_Const` is read-only, even an inner `int *_Borrow`; take `&_Mut` of the outer object instead (`bsc-borrowing` §13) |
| *(BOR-023)* | '...' is not implemented yet | Currently `borrow checking of '_Await' expressions` — `int a = _Await f();` with owned/borrowed values in an `_Async` body; restructure or drop the borrow checking there |
| *(BOR-021)* | lifetime may not live long enough | Assignment between (derefs of) borrow parameters when one is multi-level (`T *_Borrow *_Borrow`) — copy through a local value or restructure; see `bsc-borrowing` §9 |
| *(out of scope)* | function return type cannot contain multiple borrow regions | Return types may not be multi-level borrows; return the inner `T *_Borrow` instead |

### Safe Zone (BSC-E03xx)

| Code | Message | Fix |
|------|---------|-----|
| E0301 | Unsafe action forbidden in safe zone | Wrap in `_Unsafe { }` block or use safe alternative |
| E0302 | Invalid _Safe/_Unsafe declaration position | Place qualifier on function decl or block statement |
| E0303 | Union member access in safe zone | Wrap union access in `_Unsafe { }` block |
| E0304 | Forbidden cast in safe zone | Wrap cast in `_Unsafe { }` or pass correct type |
| E0307 | Forbidden operation in _Safe function | Move operation to `_Unsafe` block |
| E0308 | Mutable global variable in safe zone | Make global `const` or define outside safe zone |

### Initialization (INIT-xxx, no BSC-Exxxx range)

| Code | Message | Fix |
|------|---------|-----|
| *(INIT-033)* | __attribute__((ensure_init)) parameter 'h' points to incomplete type 'struct Handle' in a function definition | Define the struct before the function definition (declarations may stay forward) |
| *(INIT-034)* | __attribute__((ensure_init_if_ret)) argument 2 is not representable in return type '_Bool', so no return can ever satisfy the contract | Pick an `arg` the return type can hold (0/1 for `_Bool`, in range for `char`) |
| *(attr)* | 'ensure_init' attribute only applies to pointer parameters to a non-void type | Contracts can't target `void *`; use a concrete pointee |

### Nullability (BSC-E04xx)

| Code | Message | Fix |
|------|---------|-----|
| E0401 | Cannot dereference possibly-null status pointer 'p' | Add null check before dereference |
| E0402 | Cannot pass possibly-null status pointer 'p' to a '_Nonnull' parameter | Guard with null check before call |
| E0403 | Cannot return possibly-null status pointer 'p' as a '_Nonnull' pointer | Add null check or change return type to `_Nullable` |
| E0406 | Cannot assign possibly-null status pointer 'p' to a '_Nonnull' pointer | Guard with null check before assignment |
| E0407 | _Nonnull pointer must be initialized | Initialize at declaration |
| *(NULLABLE-006)* | __assume_null requires a _Nullable pointer argument | Pass a `_Nullable` pointer; `_Nonnull`/plain `_Owned`/`_Borrow` are rejected |
| *(NULLABLE-007)* | __assume_null requires a trackable expression as argument | Variable, field access, or deref chain only (parens/implicit casts ok); bind comma/ternary/explicit-cast/`arr[0]` values to a local first |
| *(NULLABLE-008)* | __assume_null requires an argument of pointer or struct type | Non-pointer, non-struct argument (e.g. `int x`) |
| *(NULLABLE-009)* | __assume_null is invalid because the struct contains a _Nonnull field | Struct form can't assume a `_Nonnull` field null — call `__assume_null(s->field)` per `_Nullable` field (note attached) |
| *(NULLABLE-W001)* | warning: __assume_null has no effect on array field 'f' containing a _Nullable pointer | Array fields aren't covered by the struct form; handle them separately (`-Wbsc-assume-null`) |
| *(NULLABLE-W002)* | warning: __assume_null has no effect: the struct does not contain any _Nullable pointer field | The call is a no-op; remove it (`-Wbsc-assume-null`) |

> **2026-08 diagnostic rework**: BSC error messages were reworded to state the
> violated rule and name the operands, quoting names LLVM-style (`'x'`, not
> `` `x` ``). Older docs (and the `errors/` catalog) may still show the previous
> phrasings; the diagnostic *identifiers* (e.g. `err_nullable_pointer_dereference`)
> are unchanged. New in 2026-08: array-element ownership errors
> (`err_ownership_array_elem_transfer_forbidden`, `..._path_inconsistent`,
> `..._assign_owned`) — see `bsc-ownership` §9.

> **New in 2026-08**: two analyzer-hint builtins, both `_Unsafe`-only —
> `__assume_null` and `__forget`. Since 2026-09 both take any *trackable*
> expression (deref chains and whole structs; `__forget` also array elements
> inside a qualifying loop), and both reject a path through a `_Borrow`
> deref when ownership is involved (`cannot take ownership of a borrowed value`). These have no `BSC-Exxxx` code
> assigned yet; the rows above cite the upstream catalog ids. Calling either
> in a safe zone reports `<name> is forbidden in the safe zone` (E0301). See
> `bsc-nullability` §9 and `bsc-ownership` §5.

> **Upstream catalog is now generated** (2026-09). The compiler repo no longer
> keeps `clang/docs/BSC/bsc-errors.md` in the source tree; it is produced from
> the `BSCDiag<"FEATURE", N>` metadata on each diagnostic in
> `clang/include/clang/Basic/BSC/*.td` by `ninja bsc-errors-md`, landing at
> `<build>/tools/clang/docs/BSC/bsc-errors.md` (134 errors, 3 warnings at the
> 2026-10-13 tip, unchanged since 2026-09-30: OWN 47, BOR 22, INIT 33, MISC 8, SZONE 12, NONNULL 3,
> NULLABLE 9). The generator rejects duplicate codes, so the
> earlier OWN-047 double assignment is gone: `err_ownership_array_elem_transfer_forbidden`
> is now **OWN-052** (OWN-047 stays `err_owned_member_access_in_return`).
> Diagnostics marked `BSCOutOfScope` (traits, async, generics, constexpr,
> operator overload, member functions, and a few others such as the multi-level
> return-type error) carry no code.

> For detailed per-category documentation, see the `errors/` directory.
> For common fixes, see `bsc-common-mistakes` Skill.
