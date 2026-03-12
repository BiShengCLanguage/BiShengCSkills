---
name: bsc-common-mistakes
description: "BiSheng C common mistakes and fixes. When you encounter BSC compilation errors, need to debug code, or want to avoid common pitfalls with ownership, borrowing, safe zones, traits, or generics, use this Skill."
---

# BiSheng C Common Mistakes Skill

## 1. Safe Zone Mistakes

### 1.1 Using `&` instead of `&_Const`/`&_Mut`

```c
// ❌ Wrong
_Safe void f(void) {
    int x = 42;
    int* p = &x;           // error: '&' forbidden in safe zone
}

// ✅ Correct
_Safe void f(void) {
    int x = 42;
    const int *_Borrow p = &_Const x;
}
```

### 1.2 Using `++`/`--` in safe zones

```c
// ❌ Wrong
_Safe void f(void) { int i = 0; i++; }

// ✅ Correct
_Safe void f(void) { int i = 0; i += 1; }
```

### 1.3 Empty params without `void`

```c
// ❌ Wrong
_Safe int f() { return 42; }

// ✅ Correct
_Safe int f(void) { return 42; }
```

### 1.4 Raw pointers in safe function signatures

```c
// ❌ Wrong
_Safe void f(int* p) { *p = 1; }

// ✅ Correct
_Safe void f(int *_Borrow p) { *p = 1; }
```

## 2. Ownership Mistakes

### 2.1 Using variable after ownership transfer

```c
// ❌ Wrong
int *_Owned p = create(42);
int *_Owned q = p;        // p moved
printf("%d\n", *p);       // error: use of moved value

// ✅ Correct
int *_Owned p = create(42);
printf("%d\n", *p);       // use before transfer
int *_Owned q = p;
```

### 2.2 Forgetting to release `_Owned` before scope ends

```c
// ❌ Wrong
void f(void) {
    int *_Owned p = create(42);
    // error: owned variable not released
}

// ✅ Correct
void f(void) {
    int *_Owned p = create(42);
    free((void *_Owned)p);
}
```

### 2.3 Pointer arithmetic on `_Owned`

```c
// ❌ Wrong
int *_Owned p = create(42);
p++;                       // error: pointer arithmetic on _Owned

// ✅ Use raw pointer for arithmetic, _Owned for ownership tracking only
```

## 3. Borrowing Mistakes

### 3.1 Mutable borrow while immutable borrow active

```c
// ❌ Wrong
int x = 42;
const int *_Borrow r = &_Const x;
int *_Borrow mr = &_Mut x;  // error: cannot mutable-borrow while immutably borrowed
printf("%d\n", *r);

// ✅ Correct — end immutable borrow first
int x = 42;
{
    const int *_Borrow r = &_Const x;
    printf("%d\n", *r);
}
int *_Borrow mr = &_Mut x;  // OK: immutable borrow ended
```

### 3.2 Borrow outlives source

```c
// ❌ Wrong
const int *_Borrow dangling(void) {
    int x = 42;
    return &_Const x;  // error: borrow outlives local variable
}
```

## 4. Trait Mistakes

### 4.1 Non-pointer trait variable

```c
// ❌ Wrong
_Trait Printable obj;          // error: only pointer form allowed

// ✅ Correct
_Trait Printable* obj = &val;
```

### 4.2 Missing `struct` keyword

```c
// ❌ Wrong
void S::method(S* this) { ... }

// ✅ Correct (unless S is typedef-ed)
void struct S::method(struct S* this) { ... }
```

### 4.3 `_Impl` before methods defined

```c
// ❌ Wrong
_Impl _Trait Printable for struct Circle;  // error: method 'print' not defined
void struct Circle::print(struct Circle* this) { ... }

// ✅ Correct — define methods first
void struct Circle::print(struct Circle* this) { ... }
_Impl _Trait Printable for struct Circle;
```

## 5. Async Mistakes

### 5.1 `_Await` in binary expression

```c
// ❌ Wrong
int result = _Await compute(1) + _Await compute(2);

// ✅ Correct
int a = _Await compute(1);
int b = _Await compute(2);
int result = a + b;
```

### 5.2 Forgetting to poll and free

```c
// ❌ Wrong (leaks coroutine)
_Trait Future<int>* task = compute(42);
// forgot to poll and free

// ✅ Correct
_Trait Future<int>* task = compute(42);
task->poll();
task->free();
```

## 6. Quick Reference

| Mistake | Fix |
|---------|-----|
| `&` in `_Safe` | Use `&_Const` or `&_Mut` |
| `++i` in `_Safe` | Use `i += 1` |
| `_Safe int f()` | `_Safe int f(void)` |
| `_Trait T var` | `_Trait T* ptr` |
| Missing `struct` | `struct S` unless typedef-ed |
| Use after move | Use before transferring ownership |
| Owned not freed | Transfer, free, or return before scope ends |
| `_Await` in expr | Assign to variable first |
| `_Owned _Borrow` | Illegal — pick one |
| Borrow of borrow | `T *_Borrow *_Borrow` is illegal |
| Mutable global in safe | Not allowed (read-only OK) |
| Partial init in safe | All struct fields must be initialized |

> For detailed error codes, see `bsc-errors` Skill
> For safe zone rules, see `bsc-safe-zone` Skill
> For ownership rules, see `bsc-ownership` Skill
