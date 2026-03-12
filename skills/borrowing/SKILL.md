---
name: bsc-borrowing
description: "BiSheng C borrowing. When you need to understand _Borrow pointers, &_Const (immutable borrow), &_Mut (mutable borrow), borrow lifetime rules, freezing semantics, or borrow function signatures, use this Skill."
---

# BiSheng C Borrowing Skill

## 1. Overview

Temporary, non-owning references. The compiler enforces borrow rules at compile time — no dangling references, no aliased mutation.

## 2. Creating Borrows

```c
int x = 42;
const int *_Borrow cr = &_Const x;   // immutable borrow — read only
int *_Borrow mr = &_Mut x;           // mutable borrow — read/write
```

## 3. Semantics

| Type | Semantics | Access | Copy? |
|------|-----------|--------|-------|
| `const T *_Borrow` | Immutable borrow | Read only | Copy (can have many) |
| `T *_Borrow` | Mutable borrow | Read + Write | Move (only one) |

## 4. Rules

- **`_Borrow` goes after the `*`**: write `int *_Borrow`, NOT `_Borrow int*`. It is a pointer qualifier, not a type prefix
- While **immutable borrow** active: original is read-only, no mutable borrows allowed
- While **mutable borrow** active: original is **frozen** — no reads, writes, or borrows
- Borrow lifetime < borrowed value's lifetime (compiler enforced)
- Cannot create borrow of a borrow: `int *_Borrow *_Borrow` is illegal
- Borrow variables must be initialized at declaration
- Cannot be global variables or union members
- `_Owned` and `_Borrow` cannot coexist on same pointer: `int *_Owned _Borrow` is illegal
- Converting between `_Borrow` and raw pointer: only in `_Unsafe`, explicit cast required
- From `_Owned` pointer: `&_Const *owned_ptr` creates immutable borrow; `&_Mut *owned_ptr` creates mutable borrow

## 5. Function Signatures

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

## 6. Complete Example

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
    printf("x = %d\n", x);  // 42

    // Multiple immutable borrows are OK
    const int *_Borrow r1 = &_Const x;
    const int *_Borrow r2 = &_Const x;
    printf("r1=%d, r2=%d\n", *r1, *r2);

    // Struct field borrows
    struct Point { int x; int y; };
    struct Point p = {.x = 10, .y = 20};
    const int *_Borrow px = &_Const p.x;
    const int *_Borrow py = &_Const p.y;
    printf("point = (%d, %d)\n", *px, *py);

    return 0;
}
```

> For ownership (owning pointers), see `bsc-ownership` Skill
> For safe zones that require borrows, see `bsc-safe-zone` Skill
> For borrow errors (BSC-E02xx), see `bsc-errors` Skill
