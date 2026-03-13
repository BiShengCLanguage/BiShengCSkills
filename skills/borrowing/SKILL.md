---
name: bsc-borrowing
description: "BiSheng C borrowing. When you need to understand _Borrow pointers, &_Const (immutable borrow), &_Mut (mutable borrow), borrow lifetime rules, freezing semantics, NLL (Non-Lexical Lifetimes), or borrow function signatures, use this Skill."
---

# BiSheng C Borrowing Skill

## CRITICAL: `_Borrow` Syntax

**`_Borrow` goes AFTER the `*`, not before the type.** It is a pointer qualifier.

```c
// CORRECT
const int *_Borrow r = &_Const x;
int *_Borrow mr = &_Mut x;

// WRONG (does not compile)
_Borrow int* r = &_Const x;
```

## 1. Overview

Temporary, non-owning references. The compiler enforces borrow rules at compile time — no dangling references, no aliased mutation.

## 2. Creating Borrows

```c
int x = 42;
const int *_Borrow cr = &_Const x;   // immutable borrow — read only
int *_Borrow mr = &_Mut x;           // mutable borrow — read/write
```

From `_Owned` pointer: `&_Const *owned_ptr` or `&_Mut *owned_ptr`.

## 3. Semantics

| Type | Access | Aliasing |
|------|--------|----------|
| `const T *_Borrow` | Read only | Multiple allowed simultaneously |
| `T *_Borrow` | Read + Write | Exactly one at a time |

Mutable borrows implicitly convert to immutable: `T *_Borrow` -> `const T *_Borrow` (compiler inserts `&_Const *`). This works in declarations, assignments, function args, and returns.

## 4. Non-Lexical Lifetimes (NLL)

Borrow lifetimes use **NLL**: a borrow is active from its creation point to its **last use**, NOT to the end of the lexical scope. This allows code like:

```c
void use(int *_Borrow p) {}

void foo() {
    int local1 = 1, local2 = 2;
    int *_Borrow p = &_Mut local1;  // NLL segment 1 starts
    use(p);                          // NLL segment 1 ends (last use)
    // local1 is unfrozen here — p's borrow has ended
    local1 = 10;                     // OK: p is no longer active
    p = &_Mut local2;                // NLL segment 2 starts (and ends — no further use)
}
```

Uses that extend NLL: function calls `use(p)`, `return p`, dereference `*p`, member access `p->field`.

## 5. Rules

- **`_Borrow` goes after the `*`**: write `int *_Borrow`, NOT `_Borrow int*`
- While **immutable borrow** active: original is read-only, no mutable borrows allowed
- While **mutable borrow** active: original is **frozen** — no reads, writes, moves, or borrows
- **Struct field borrows**: `&_Const e.field` or `&_Mut e.field` freezes only **that field** (and blocks whole-struct modification), but other fields remain accessible
- Borrow lifetime <= borrowed value's lifetime (compiler enforced)
- Cannot create borrow of a borrow: `int *_Borrow *_Borrow` is illegal
- Borrow variables must be initialized at declaration
- Cannot be global variables or union members
- `_Owned` and `_Borrow` cannot coexist on same pointer: `int *_Owned _Borrow` is illegal
- No indexing (`p[i]`) and no pointer arithmetic (`p + n`, `p++`) on borrow pointers
- Cannot use `_Borrow` pointer type as a generic type argument
- No `_Trait` impl for borrow types; no member functions for borrow types
- Converting between `_Borrow` and raw pointer: allowed outside `_Safe` zones (explicit cast required); **forbidden inside `_Safe` zones**
- String literals auto-borrow to `const char *_Borrow` when passed to a `const char *_Borrow` parameter (compiler inserts `&_Const *`)

## 6. Function Signatures

```c
// Read-only access
_Safe int len(const Vec<int> *_Borrow this) {
    return this->len;
}

// Mutable access
_Safe void push(Vec<int> *_Borrow this, int value) { ... }

// Return borrow — lifetime tied to input borrow
_Safe int *_Borrow first(Vec<int> *_Borrow this) { ... }
```

- If return is `_Borrow` and one param is `_Borrow`: return lifetime = param lifetime
- If multiple `_Borrow` params: return lifetime = union of all param lifetimes
- If no `_Borrow` params but return is `_Borrow`: compile error

## 7. Complete Example

```c
#include <stdio.h>

void printValue(const int *_Borrow ref) {
    printf("value = %d\n", *ref);
}

void doubleValue(int *_Borrow ref) {
    *ref = *ref * 2;
}

const int *_Borrow getFirst(const int *_Borrow arr, int len) {
    return arr;
}

int main() {
    int x = 21;

    // Immutable borrow
    const int *_Borrow cr = &_Const x;
    printValue(cr);
    printValue(&_Const x);   // inline borrow

    // Mutable borrow
    int *_Borrow mr = &_Mut x;
    doubleValue(mr);
    // NLL: mr's lifetime ended at last use (doubleValue call)
    printf("x = %d\n", x);  // OK: x is no longer frozen

    // Multiple immutable borrows are OK
    const int *_Borrow r1 = &_Const x;
    const int *_Borrow r2 = &_Const x;
    printf("r1=%d, r2=%d\n", *r1, *r2);

    // Struct field borrows — only the borrowed field is frozen
    struct Point { int x; int y; };
    struct Point p = {.x = 10, .y = 20};
    int *_Borrow px = &_Mut p.x;  // only p.x is frozen
    p.y = 30;                      // OK: p.y is a different field
    *px = 50;
    // px NLL ends here (last use above)

    // Mutable-to-immutable implicit conversion
    int val = 5;
    int *_Borrow mp = &_Mut val;
    const int *_Borrow ip = mp;  // OK: implicit conversion

    // String literal auto-borrow
    void print_str(const char *_Borrow s);
    print_str("hello");  // compiler auto-inserts &_Const *

    return 0;
}
```

> For ownership (owning pointers), see `bsc-ownership` Skill
> For safe zones that require borrows, see `bsc-safe-zone` Skill
> For borrow errors (BSC-E02xx), see `bsc-errors` Skill
