---
name: bsc-nullability
description: "BiSheng C nullability. When you use _Nullable or _Nonnull, handle null pointers, or decide whether an API can accept/return null, use this Skill."
---

# BSC Nullability (Lite)

## 1. Critical Rule

`_Nullable` and `_Nonnull` are **pointer qualifiers**, like `const`. They go AFTER `*`, never before the type.

```c
int *_Owned _Nullable p = nullptr;     // CORRECT
_Nullable int *p = nullptr;             // WRONG
```

## 2. Defaults

| Pointer kind | Default |
|---|---|
| `T *_Owned` | `_Nonnull` |
| `T *_Borrow` | `_Nonnull` |
| Raw `T *` | `_Nullable` |

So `T *_Owned` cannot be null unless you explicitly add `_Nullable`:

```c
int *_Owned p = nullptr;                      // ERROR: _Owned is non-null
int *_Owned _Nullable p = nullptr;            // OK
```

## 3. When to Use `_Nullable`

Reach for `_Nullable` only when **absence is meaningful**:

- Allocation may fail: `T *_Owned _Nullable try_alloc(size_t n)`
- Lookup may miss: `T *_Borrow _Nullable find(Map *_Borrow m, Key k)`
- Cleanup paths where a pointer may not have been set
- Struct fields that are legitimately optional

Don't use `_Nullable` "just in case" — it forces every caller to null-check. Default to `_Nonnull`.

## 4. Null Literal

Use `nullptr`, not `NULL`, in BSC code. `NULL` is forbidden in `_Safe` zones.

```c
int *_Owned _Nullable p = nullptr;    // OK
int *_Owned _Nullable p = NULL;       // ERROR in _Safe
```

## 5. Null-Checking Pattern

You must null-check a `_Nullable` pointer before dereferencing:

```c
_Safe void process(const Node *_Borrow _Nullable n) {
    if (n == nullptr) return;
    // After this point, the compiler knows n is non-null
    int v = n->value;              // OK
}
```

Using `!=` / `==` with `nullptr` tells the compiler the pointer is definitely non-null after the check.

## 6. Common Patterns

**Allocation that may fail:**
```c
_Unsafe {
    char *_Owned _Nullable buf = (char *_Owned _Nullable)malloc(size);
    if (buf == nullptr) {
        return -1;
    }
    // buf is now known non-null
    use(buf);
    safe_free((void *_Nullable _Owned)buf);
}
```

**Optional struct field:**
```c
_Owned struct Cache {
_Public:
    size_t capacity;
    Entry *_Owned _Nullable active;    // may or may not be populated
};
```

**Lookup returning absent:**
```c
_Safe const Entry *_Borrow _Nullable lookup(
    const Map *_Borrow m, Key k);

const Entry *_Borrow _Nullable e = lookup(&_Const m, key);
if (e != nullptr) {
    use(*e);
}
```

## 7. Changing Nullability Is a Breaking Change

Adding or removing `_Nullable` on an existing API is a **breaking change** for every caller:
- Removing `_Nullable` means callers that passed null now fail to compile.
- Adding `_Nullable` means callers must now null-check before deref.

Decide nullability at design time, not later.

## 8. Free Accepts `_Nullable`

`safe_free` accepts `_Nullable _Owned` — safe to call on a possibly-null pointer:

```c
int *_Owned _Nullable p = maybe_alloc();
safe_free((void *_Nullable _Owned)p);    // OK even if p is null
```

Cast based on the source's type. If the source is `_Nullable`, the cast must preserve it — narrowing to `_Nonnull` is a type error.

## 9. Common Mistakes

**Assigning null to non-null `_Owned`:**
```c
int *_Owned p = nullptr;                 // ERROR
int *_Owned _Nullable p = nullptr;       // OK
```

**Using `NULL`:**
```c
int *_Owned _Nullable p = NULL;          // ERROR in _Safe
int *_Owned _Nullable p = nullptr;       // OK
```

**Dereferencing without checking:**
```c
_Safe void f(Node *_Borrow _Nullable n) {
    int v = n->value;                     // ERROR: n may be null
    if (n != nullptr) {
        int v = n->value;                 // OK after check
    }
}
```

**Defaulting to `_Nullable` without reason:**
```c
// BAD — caller has to null-check for no reason
_Safe void render(const Frame *_Borrow _Nullable f);

// GOOD — non-null default, caller doesn't null-check
_Safe void render(const Frame *_Borrow f);
```
