---
name: bsc-common-mistakes
description: "BiSheng C common mistakes and fixes. When you encounter BSC compilation errors, need to debug code, or want to avoid common pitfalls with ownership, borrowing, safe zones, traits, or generics, use this Skill."
---

# BiSheng C Common Mistakes Skill

## 1. Safe Zone Mistakes

### 1.1 Using `&` instead of `&_Const`/`&_Mut`
```c
_Safe void f(void) {
    int x = 42;
    // int* p = &x;                    // error: '&' forbidden in safe zone
    const int *_Borrow p = &_Const x;  // correct
}
```

### 1.2 Using `++`/`--` result as expression
`++`/`--` are allowed as statements but return `void` — cannot use the result.
```c
_Safe void f(void) {
    int i = 0;
    i++;                               // ok: side-effect only
    for (int j = 0; j < 10; j++) {}    // ok: iteration clause
    // int x = i++;                    // error: result type is void
}
```

### 1.3 Empty params without `void`
```c
// _Safe int f() { return 42; }     // error
_Safe int f(void) { return 42; }    // correct
```

### 1.4 Partial init of structs with pointer fields
Only structs with pointer fields require complete initializers. Basic-type-only structs may be partially initialized.
```c
_Safe {
    struct HasPtr hp = {nullptr, 0};  // ok: complete init (has pointer field)
    // struct HasPtr hp2 = {0};       // error: partial init
    struct NoPtr { int a; int b; };
    struct NoPtr np = {0};            // ok: no pointer fields
}
```

### 1.5 Union member access in safe zone
Unions can be declared/initialized/passed, but member access is forbidden.
```c
_Safe {
    union U { int i; float f; } u = {.i = 1};
    // int x = u.i;                   // error
    _Unsafe { int x = u.i; }          // ok: unsafe escape
}
```

### 1.6 Forbidden casts in safe zone
No cross-category pointer casts (`_Owned`/`_Borrow`/raw), no pointer-integer casts, no float-to-integer casts. Exception: `T *_Owned` to `void *_Owned` is allowed.

### 1.7 Mutable borrow of global in safe zone
Only `&_Const` of globals allowed; `&_Mut` of globals is forbidden.
```c
int g = 10;
_Safe void f(void) {
    // int *_Borrow p = &_Mut g;          // error
    const int *_Borrow p = &_Const g;     // ok
}
```

## 2. Ownership Mistakes

### 2.1 Wrong `_Owned`/`_Borrow` qualifier placement
**#1 LLM mistake.** `_Owned`/`_Borrow` go **after the `*`**, not before the type.
```c
// WRONG                              // CORRECT
// _Owned char* msg                   char *_Owned msg = safe_malloc('\0');
// _Borrow int* r                     const int *_Borrow r = &_Const x;
```
Pattern: always `T *_Owned` and `T *_Borrow`, never `_Owned T*` or `_Borrow T*`.

### 2.2 Using variable after ownership transfer
```c
int *_Owned p = safe_malloc(42);
int *_Owned q = p;        // p moved
// printf("%d\n", *p);    // error: use of moved value
```

### 2.3 Forgetting to release `_Owned` before scope ends
```c
void f(void) {
    int *_Owned p = safe_malloc(42);
    safe_free((void *_Owned)p);   // must release: free, pass, or return
}
```

### 2.4 Pointer arithmetic on `_Owned`
```c
int *_Owned p = safe_malloc(42);
// p++;                    // error: no arithmetic on _Owned
```

## 3. Borrowing Mistakes

### 3.1 Mutable borrow while immutable borrow active
```c
int x = 42;
{
    const int *_Borrow r = &_Const x;
    printf("%d\n", *r);
}
int *_Borrow mr = &_Mut x;  // ok: immutable borrow ended
```

### 3.2 Borrow outlives source
```c
// const int *_Borrow dangling(void) {
//     int x = 42;
//     return &_Const x;  // error: borrow outlives local
// }
```

## 4. Trait Mistakes

### 4.1 Non-pointer trait variable
```c
// _Trait Printable obj;       // error: only pointer form
_Trait Printable* obj = &val;  // correct
```

### 4.2 Missing `struct` keyword
```c
// void S::method(S* this) { ... }               // error (unless typedef-ed)
void struct S::method(struct S* this) { ... }     // correct
```

### 4.3 `_Impl` before methods defined
```c
// Define methods FIRST, then _Impl
void struct Circle::print(struct Circle* this) { ... }
_Impl _Trait Printable for struct Circle;
```

## 5. Async Mistakes

### 5.1 `_Await` in binary expression
```c
// int result = _Await compute(1) + _Await compute(2);  // error
int a = _Await compute(1);
int b = _Await compute(2);
int result = a + b;
```

## 6. Quick Reference

| Mistake | Fix |
|---------|-----|
| `_Owned char*` | `char *_Owned` — qualifier after `*` |
| `_Borrow int*` | `int *_Borrow` — qualifier after `*` |
| `&` in `_Safe` | Use `&_Const` or `&_Mut` |
| `int x = i++` in `_Safe` | `i++` ok as statement; result is `void` |
| `_Safe int f()` | `_Safe int f(void)` |
| Partial init in safe | Required only for structs **with pointer fields** |
| Union `.member` in safe | Forbidden — use `_Unsafe {}` escape |
| Cast categories in safe | No cross-casts (except `T *_Owned` to `void *_Owned`) |
| `&_Mut` global in safe | Forbidden — only `&_Const` of globals |
| `_Trait T var` | `_Trait T* ptr` |
| Missing `struct` | `struct S` unless typedef-ed |
| Use after move | Use before transferring ownership |
| Owned not freed | `safe_free`, pass, or return before scope ends |
| `_Await` in expr | Assign to variable first |
| `_Owned _Borrow` | Illegal — pick one |
| Borrow of borrow | `T *_Borrow *_Borrow` — restriction (pick single level) |

> For detailed error codes, see `bsc-errors` Skill
> For safe zone rules, see `bsc-safe-zone` Skill
> For ownership rules, see `bsc-ownership` Skill
