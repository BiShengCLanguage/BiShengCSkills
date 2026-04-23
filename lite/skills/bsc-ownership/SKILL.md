---
name: bsc-ownership
description: "BiSheng C ownership. When you write _Owned pointers, manage heap memory, design destructors, or work with safe_malloc/safe_free, use this Skill."
---

# BSC Ownership (Lite)

## 1. Critical Rule

`_Owned` is a **pointer qualifier**, like `const`. It goes AFTER `*`, never before the type.

```c
int *_Owned p = safe_malloc<int>(0);   // CORRECT
_Owned int* p = ...;                    // WRONG — compile error
```

Pattern: `T *_Owned`. Never `_Owned T*`.

## 2. What `_Owned` Means

- `T *_Owned` means the pointer **owns** the heap memory it points to.
- Exactly one owner at a time. Passing an `_Owned` to a function transfers ownership (moves it); the original variable becomes unusable after the move.
- When an `_Owned` pointer goes out of scope without being moved, the compiler auto-frees it.

## 3. Allocation and Freeing

Always prefer `safe_malloc` and `safe_free`:

```c
#include "bishengc_safety.hbs"

int *_Owned p = safe_malloc<int>(42);    // allocates, initializes to 42
safe_free((void *_Owned)p);               // frees
```

For variable-size or string allocations, use raw `malloc`/`free` in `_Unsafe`:

```c
_Unsafe {
    char *_Owned buf = (char *_Owned)malloc(size);
    free((void *_Owned)buf);
}
```

## 4. Move Semantics

Passing `_Owned` to a function consumes it:

```c
void consume(int *_Owned p);   // takes ownership

int *_Owned p = safe_malloc<int>(10);
consume(p);                     // ownership moved
// p is now unusable — using it is a compile error
```

If you want to keep access, pass a `_Borrow` instead (see `bsc-borrowing`).

## 5. `_Owned struct` — Structs That Own Resources

Mark a struct `_Owned` when it holds heap pointers or needs cleanup:

```c
_Owned struct Buffer {
_Public:
    char *_Owned data;
    size_t len;

    ~Buffer(Buffer this) {
        safe_free((void *_Owned)this.data);
    }
};
```

The destructor fires automatically when the struct goes out of scope.

**If the struct holds only `_Owned` fields (no raw pointers), the destructor can be empty** — field destructors run on their own:

```c
_Owned struct Config {
    String name;        // ~String fires automatically
    Vec<int> values;    // ~Vec fires automatically

    ~Config(Config this) {}   // empty body is fine
};
```

## 6. Nullable `_Owned`

By default `T *_Owned` is **non-null**. If it may be null, add `_Nullable`:

```c
int *_Owned _Nullable p = nullptr;       // OK — nullable
if (condition) {
    p = safe_malloc<int>(5);             // assign later
}
safe_free((void *_Nullable _Owned)p);    // safe even if null
```

Use `nullptr`, not `NULL`, in BSC code.

## 7. Where `_Owned` Is NOT Allowed

- **Global variables** — cannot use `_Owned` on file-scope or `static` variables
- **Union members** — `_Owned` cannot qualify a union member
- **Array elements** — `int *_Owned arr[10]` is forbidden

Use `_Owned` only on local variables, function parameters, return types, and struct fields.

## 8. Common Mistakes

**Use after move:**
```c
int *_Owned p = safe_malloc<int>(1);
consume(p);           // moved
int x = *p;           // ERROR: p is moved
```

**Forgetting `_Nullable`:**
```c
int *_Owned p = nullptr;                    // ERROR: _Owned is non-null by default
int *_Owned _Nullable p = nullptr;          // OK
```

**Wrong qualifier placement:**
```c
_Owned int *p = ...;     // ERROR: "unknown type name '_Owned'"
int *_Owned p = ...;     // OK
```

**Partial move of struct:**
```c
_Owned struct S { String a; String b; };
S s = ...;
consume(s.a);        // ERROR: can't move one field while keeping the rest
// Fix: move the whole s, or leave it alone and let destructor run
```
