---
name: bsc-safe-zone
description: "BiSheng C safe zones. When you write _Safe functions, _Unsafe escape blocks, or decide where the safety boundary goes, use this Skill."
---

# BSC Safe Zones (Lite)

## 1. What `_Safe` and `_Unsafe` Mean

- `_Safe` = compiler enforces memory safety (ownership, borrow checking, nullability).
- `_Unsafe` = standard C behavior, no extra checking.
- **Default context is `_Unsafe`.** You opt in to safety with `_Safe`.

```c
_Safe int add(int a, int b) { return a + b; }       // safety-checked
void plain(void) { int x = 5; }                      // default _Unsafe
```

## 2. Rules Inside `_Safe` Code

**Plain `&` is forbidden — use `&_Const` or `&_Mut`:**
```c
_Safe void f(void) {
    int x = 1;
    int *p = &x;                 // ERROR
    int *_Borrow p = &_Mut x;    // OK
}
```

**Raw pointer dereference is forbidden:**
```c
_Safe void f(int *raw) {
    int v = *raw;                // ERROR: can't deref raw pointer
}
_Safe void g(const int *_Borrow b) {
    int v = *b;                  // OK: _Borrow deref is safe
}
```

**Use `nullptr`, not `NULL`:**
```c
_Safe void f(void) {
    int *_Owned _Nullable p = NULL;       // ERROR
    int *_Owned _Nullable p = nullptr;    // OK
}
```

**Pointer variables must be initialized:**
```c
_Safe {
    int *_Owned _Nullable p = nullptr;    // OK
    int *_Owned p;                         // ERROR: must initialize
}
```

**No casts between different pointer types:**
```c
_Safe {
    int *_Owned a = ...;
    char *_Owned b = (char *_Owned)a;    // ERROR: different pointed-to types
}
```

## 3. `_Unsafe` Escape Blocks

When you need a C operation inside a `_Safe` function, wrap it in `_Unsafe { ... }`:

```c
_Safe void f(const int *_Borrow v) {
    _Unsafe { printf("%d\n", *v); }      // printf is variadic, needs _Unsafe
}
```

Three forms:
```c
_Unsafe { ... }              // block
_Unsafe int x = 1;           // statement
char c = _Unsafe((char)n);   // expression
```

## 4. Design Principle — Keep `_Unsafe` Small

**Make the `_Safe` interface wide, the `_Unsafe` surface tiny.**

```c
// GOOD — function is _Safe, only the one unsafe line is wrapped
_Safe String from_cstr(const char *s) {
    _Unsafe { return String::from(s); }
}

// BAD — whole function is _Unsafe just for one line
_Unsafe String from_cstr(const char *s) {
    return String::from(s);
}
```

Once a function is `_Unsafe`, every caller must also be `_Unsafe` or wrap the call — the cost spreads. Keep the boundary shallow.

## 5. Pointer Conversion Rules

| Conversion | In `_Safe` |
|---|---|
| `T *_Borrow` → `void *_Borrow` | OK (implicit) |
| `void *_Borrow` → `T *_Borrow` | Requires `_Unsafe(expr)` cast |
| `T *_Owned` → `void *_Owned` | OK (explicit cast) |
| `T *_Owned` → raw `T *` | Forbidden (use `__move_to_raw` via `_Unsafe`) |
| `T *_Borrow` → raw `T *` | Forbidden |
| Cast between two different `T *_Borrow` types | Forbidden |

## 6. The Void-Borrow Two-Step Cast

To cast between two unrelated `_Borrow` pointer types (e.g. in a vtable trampoline), go through `void *_Borrow`:

```c
// Goal: cast public_t *_Borrow to private_t *_Borrow
private_t *_Borrow _Nonnull this = _Unsafe(
    (private_t *_Borrow _Nonnull)(void *_Borrow _Nonnull)self);
```

- `public_t *_Borrow → void *_Borrow` — implicit, allowed in `_Safe`
- `void *_Borrow → private_t *_Borrow` — explicit, requires `_Unsafe(expr)`

## 7. When You Legitimately Need `_Unsafe`

- Calling C library functions (e.g. `printf`, `memcpy`, `fopen`)
- Raw pointer arithmetic
- Casting between unrelated pointer types
- FFI boundaries (transferring ownership to/from C code)

Not legitimate uses:
- "Getting rid of an error you don't understand" — investigate first
- Skipping nullability checks out of convenience

## 8. Common Mistakes

**Forgetting `nullptr`:**
```c
_Safe void f(void) {
    int *_Owned _Nullable p = NULL;       // ERROR
    int *_Owned _Nullable p = nullptr;    // OK
}
```

**Plain `&` in `_Safe`:**
```c
_Safe void f(int x) {
    int *p = &x;                          // ERROR
    int *_Borrow p = &_Mut x;             // OK
}
```

**Whole function marked `_Unsafe` unnecessarily:**
```c
_Unsafe void process(const int *_Borrow v) {
    _Unsafe { printf("%d", *v); }         // Inner _Unsafe was needed — but
}                                          // the function didn't have to be _Unsafe.
                                          // Mark it _Safe instead.
```
