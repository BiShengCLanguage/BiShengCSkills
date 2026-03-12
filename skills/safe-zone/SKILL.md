---
name: bsc-safe-zone
description: "BiSheng C safe zones. When you need to understand _Safe functions, _Safe blocks, _Unsafe escape blocks, safe zone restrictions (no raw pointers, no &, no goto, no ++/--), or mixed safe/unsafe patterns, use this Skill."
---

# BiSheng C Safe Zones Skill

## 1. Overview

Designate code regions where the compiler enforces memory safety. Default context is `_Unsafe` (standard C compatibility). Use `_Safe` to opt in to strict checking.

## 2. Syntax

```c
// Safe function
_Safe int add(int a, int b) {
    return a + b;
}

// Safe block
_Safe {
    int x = 10;
    int y = x + 1;
}

// Unsafe escape inside safe code
_Safe void process(const int *_Borrow v) {
    _Unsafe {
        printf("%d\n", *v);  // printf is unsafe (variadic)
    }
}
```

## 3. Restrictions (compiler-enforced)

In `_Safe` zones, the following are **forbidden**:

- **No raw pointers** — use `_Owned` or `_Borrow`
- **No `&`** — use `&_Const` or `&_Mut`
- **No `goto`**, no labels
- **No `++` or `--`** — use `x += 1`
- **No inline assembly**
- **No union member access**
- **No raw pointer dereference** (`*rawptr`, `rawptr->field`)
- **No calling unsafe functions** — must wrap in `_Unsafe {}`
- **Variables must be initialized** at declaration
- **Complete initializer lists** (no partial init)
- **No narrowing casts** (`long`→`int`, `double`→`float`), constants excepted
- **No pointer type casts** (except `T *_Owned`→`void *_Owned`)
- Empty params: `_Safe int f(void)` — `void` required, not `_Safe int f()`
- **No variadic params** in `_Safe` functions
- **No mutable globals** in safe zones (read-only globals OK)
- Switch: `case`/`default` only in first-level block, no variable declarations in switch block

## 4. Complete Example

```c
#include <stdio.h>
#include <stdlib.h>

_Safe int add(int a, int b) {
    int result = a + b;
    return result;
}

_Safe int readBorrow(const int *_Borrow ref) {
    return *ref;  // OK: dereferencing _Borrow is safe
}

_Safe void writeBorrow(int *_Borrow ref, int value) {
    *ref = value;
}

_Safe int safePrint(const int *_Borrow val) {
    _Unsafe {
        printf("value = %d\n", *val);
    }
    return *val;
}

void mixedFunction(void) {
    int* raw = (int*)malloc(sizeof(int));
    *raw = 100;

    _Safe {
        int x = 42;
        int y = 0;
        const int *_Borrow ref = &_Const x;
        y = readBorrow(ref);

        _Unsafe {
            printf("from safe zone: %d\n", y);
            free(raw);
        }
    }
}

int main() {
    int a = 10;
    int b = 20;

    _Safe {
        int sum = add(a, b);
        const int *_Borrow r = &_Const sum;
        safePrint(r);
    }

    mixedFunction();
    return 0;
}
```

> For borrowing (required in safe zones), see `bsc-borrowing` Skill
> For ownership in safe contexts, see `bsc-ownership` Skill
> For safe zone errors (BSC-E03xx), see `bsc-errors` Skill
> For common safe zone mistakes, see `bsc-common-mistakes` Skill
