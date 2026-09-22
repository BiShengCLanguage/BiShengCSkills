---
name: bsc-nullability
description: "BiSheng C non-null pointers and nullability. When you need to understand _Nullable, _Nonnull, nullptr, null-safety checking, pointer nullability tracking, null check patterns, or -nullability-check compiler option, use this Skill."
---

# BiSheng C Nullability Skill

## 1. Overview

BSC tracks pointer nullability at compile time. The compiler prevents dereferencing or accessing members through pointers that may be null. (Since 2026-08 these diagnostics call the tracked state "possibly-null status" and name the pointer, e.g. `cannot dereference possibly-null status pointer 'p'`, `cannot assign possibly-null status pointer 'p' to a '_Nonnull' pointer`.)

- `_Nonnull` — pointer guaranteed non-null (default for `_Owned` and `_Borrow`)
- `_Nullable` — pointer may be null (default for raw pointers)
- `nullptr` — BSC's null pointer literal
- `NULL` — since 2026-09 C's `NULL` (`((void *)0)`) and every other null pointer constant (`0`, `(void *)(1 - 1)`, …) are accepted **everywhere `nullptr` is**: safe zones, `_Owned`/`_Borrow` initializers and assignments, explicit casts such as `(int *_Borrow)NULL` / `(int *_Borrow)0` (unsafe zone), and comparisons `p == NULL` / `NULL != p`, which narrow exactly like `nullptr`. `nullptr` is still the idiomatic spelling. What stays rejected is unchanged: `int *_Nonnull p = NULL;` and `int *_Owned p = NULL;` are `error: cannot assign a possibly-null status pointer to a '_Nonnull' pointer` (verified)

## 2. Default Nullability

| Pointer kind | Default | Override |
|-------------|---------|----------|
| Raw pointer (`int *`) | Nullable | `int *_Nonnull` |
| `_Owned` pointer (`int *_Owned`) | Nonnull | `int *_Owned _Nullable` |
| `_Borrow` pointer (`int *_Borrow`) | Nonnull | `int *_Borrow _Nullable` |

```c
// Nullable pointers:
int *_Nullable p1 = nullptr;
int *_Borrow _Nullable p2 = nullptr;
int *_Owned _Nullable p3 = nullptr;
int *p4 = nullptr;                    // raw pointer is Nullable by default

// Nonnull pointers:
int *_Nonnull p5 = &a;
int *_Borrow p6 = &_Mut a;           // _Borrow is Nonnull by default
int *_Owned p7 = safe_malloc<int>(5); // _Owned is Nonnull by default
```

**Nullability in type compatibility**: `_Nullable`/`_Nonnull` are *sticky*
qualifiers and participate in type-compatibility checks, but the compiler
fills in the **default** first — so `int *` is compatible with
`int * _Nullable`, and `int *_Borrow` with `int *_Borrow _Nonnull`, while
`int *_Owned` is **not** compatible with `int *_Owned _Nullable`. In mixed
`_Safe`/`_Unsafe` redeclarations, an `_Unsafe` `_Nonnull` parameter cannot
pair with a `_Safe` `_Nullable` one (see `bsc-safe-zone` §5).

## 3. Trackable Pointers

The compiler can track nullability only for pointers that:
1. Are **lvalues** (have a memory address)
2. Are **not** `volatile`
3. Are **not** obtained through array subscript (`[]`)

```c
_Safe void test(int *_Borrow _Nullable p, int *_Borrow _Nullable volatile vp) {
    int *_Borrow _Nullable q = nullptr;
    int *_Borrow _Nullable arr[2] = {nullptr, &_Mut local};

    if ((q = p) != nullptr) {
        *q = 1;  // ok: q is trackable lvalue
    }
    if (identity(p) != nullptr) {
        *identity(p) = 3;  // error: function return is not lvalue
    }
    if (vp != nullptr) {
        *vp = 4;  // error: volatile pointer not tracked
    }
    if (arr[1] != nullptr) {
        *arr[1] = 5;  // error: array subscript not tracked
    }
}
```

### Workaround: copy through a trackable local

When you need to dereference an untrackable nullable pointer, first bind it to
a **fresh local variable** (which is trackable by virtue of being a plain lvalue),
then null-check and dereference the local:

```c
_Safe void use_untrackable(int *_Borrow _Nullable p, int *_Borrow _Nullable arr[]) {
    int *_Borrow _Nullable t1 = identity(p);  // trackable temp
    if (t1 != nullptr) { *t1 = 3; }           // ok

    int *_Borrow _Nullable t3 = arr[1];       // trackable temp
    if (t3 != nullptr) { *t3 = 5; }           // ok
}
```

The temp must be a local variable — not a struct member, not another array
element. This is the recommended pattern whenever you face an untrackable
nullable pointer.

## 4. Nullability State Changes

For **Nonnull-marked** pointers: state is always Nonnull. If null-checked, the null branch treats it as null (useful for `_Owned` leak prevention):

```c
_Safe int test(void) {
    int *_Owned a = safe_malloc<int>(1);  // Nonnull
    if (a != nullptr) {
        safe_free((void *_Owned)a);
        return 1;
    }
    return 0;  // ok: no leak error (a treated as null in this branch)
}
```

For **Nullable-marked** pointers, state changes via:
1. **Assignment with non-null expression** → becomes Nonnull
2. **Null check in control flow** → Nonnull in the non-null branch

```c
_Safe void test(void) {
    int *_Borrow _Nullable p1 = nullptr;    // Nullable
    *p1 = 10;                                // error!

    int local = 10;
    p1 = &_Mut local;                        // → Nonnull (non-null assignment)
    *p1 = 20;                                // ok

    p1 = foo(&_Mut local);                   // → Nullable (foo returns _Nullable)
    *p1 = 20;                                // error!

    p1 = bar(&_Mut local);                   // → Nonnull (bar returns Nonnull)
    *p1 = 20;                                // ok

    int *_Borrow _Nullable p2 = foo(&_Mut local);
    if (p2 != nullptr)
        *p2 = 10;  // ok: Nonnull in true branch
    else
        *p2 = 20;  // error: Nullable in else branch
}
```

## 5. Null Check Patterns

In conditions of `if`/`while`/ternary, these patterns constitute null checks:

1. **Direct pointer**: `if (p)` / `while (s.p)`
2. **Logical operators**: `if (!p)` / `if (p && q)` / `if (p || q)`
3. **Explicit comparison**: `if (p != nullptr)` / `if (nullptr == p)` — `NULL` works the same way
4. **With assignment**: `if ((q = p) != nullptr)` — only checks `q`
5. **In comma expression**: `if ((x, p != nullptr))` — only checks last
6. **Parentheses**: any of above can be nested in parens

State updates:
- `if (e)` / `if (e != nullptr)`: `e` is Nonnull in true branch
- `if (!e)` / `if (e == nullptr)`: `e` is Nonnull in false/else branch
- `if (p && q)`: both Nonnull in true branch
- `if (!p || !q)`: both Nonnull in else branch

## 6. Assignment, Passing, and Return Rules

```c
// Cannot assign nullable value to Nonnull pointer:
int *_Borrow p1 = nullptr;          // error in safe zone
int *_Borrow p2 = foo(&_Mut local); // error if foo returns _Nullable

// Cannot pass nullable argument to Nonnull parameter:
_Safe void bar(int *_Borrow p) {}
bar(nullable_ptr);  // error

// Cannot return nullable from Nonnull return type:
_Safe int *_Borrow return_nonnull(int *_Borrow p) {
    int *_Borrow _Nullable q = nullptr;
    return q;  // error
}
```

For `_Owned _Nullable` pointers these rules combine with ownership tracking: a maybe-null `_Owned _Nullable` can only be moved into `_Nullable` receivers, a definitely-null one may be "moved" freely as a no-op and needs no free at scope exit. See `bsc-ownership` §5 for the full three-state rules.

Borrows created via `&_Mut *p` / `&_Const *p` **inherit `p`'s nullability** (attribute and tracked state) — borrowing a nullable pointer yields a `_Nullable` borrow. Parenthesized and wrapped spellings (`&_Mut (*p)`, `&_Mut *(p)`, `&_Mut _Unsafe(*p)`) behave identically. For subscripts, `&_Mut a[0]` / `&_Const a[0]` (constant index 0) is allowed on a maybe-null pointer `a` and inherits its nullability; any other index requires `a` to be definitely non-null (`error: cannot dereference possibly-null status pointer 'a'`), and the result is `_Nonnull`. When `a` is an array the result is always `_Nonnull` (since 2026-09; see `bsc-borrowing` §12). The trait `is_nullable<T>()` (see `bsc-constexpr`) tests effective nullability at compile time, counting defaults: raw pointers default `_Nullable`, `_Owned`/`_Borrow` default `_Nonnull`.

## 7. Type Casting

Null pointer constants may be cast to any pointer category: `(int *_Owned _Nullable)NULL`, `(int *_Borrow)NULL`, `(int *_Borrow)0` all compile in an unsafe zone (2026-09).

With `-nullability-check=all`, casting Nullable to Nonnull in non-safe zones is also checked:

```c
void foo() {
    int *p1 = nullptr;
    int *p2 = (int *_Nonnull)p1;   // error: nullable to nonnull cast
    int *_Owned p3 = (int *_Owned)p1; // error
}
```

After a null check, casting is allowed:

```c
void foo() {
    int *p1 = nullptr;
    if (p1 != nullptr) {
        int *_Nonnull p2 = (int *_Nonnull)p1;  // ok
        int *_Owned p3 = (int *_Owned)p1;       // ok
    }
}
```

## 8. Struct Members

```c
struct Data { int *_Borrow _Nullable value; };

_Safe void test(void) {
    int local = 10;
    // Init list: nullability inferred from initializer
    struct Data data1 = {.value = bar(&_Mut local)};  // Nonnull
    *data1.value = 10;  // ok

    // Non-init-list: defaults to Nullable
    struct Data data2 = init_data(&_Mut local);  // Nullable
    *data2.value = 10;  // error

    // Fix: reassign or null-check
    data2.value = bar(&_Mut local);  // → Nonnull
    *data2.value = 10;               // ok

    if (data3.value != nullptr)
        *data3.value = 10;           // ok
}
```

## 9. `__assume_null`

`__assume_null(p)` is a builtin that asserts a `_Nullable` pointer is null at
this program point. It is a **pure analyzer hint** — the compiler verifies
nothing and emits no code; you are promising the assertion holds.

**`_Unsafe`-only** — it bypasses the nullability checker:

```c
_Safe void foo(int *_Owned _Nullable p) {
    __assume_null(p);  // error: __assume_null is forbidden in the safe zone
}
```

**On `_Owned _Nullable`** — the pointer becomes definitely null *and holds no
ownership*, so no leak is reported. This is the point of the builtin: after an
opaque callee frees through a borrow, the analyzer cannot see that `p` was
freed and nulled.

```c
_Safe void MemFree(void *_Owned _Nullable *_Borrow ptr);

_Safe void foo(void *_Owned _Nullable p) {
    MemFree(&_Mut p);
    _Unsafe { __assume_null(p); }
    // no forget(p), no p = nullptr, no leak
}
```

Without the `__assume_null`, that function is
`error: memory leak because 'p' is not freed or moved before it goes out of scope`.

**On any other `_Nullable`** — the pointer is treated as definitely null.
A later dereference without a fresh null check is an error, and **any earlier
null-check narrowing is invalidated**:

```c
void bar(int *_Nullable p) {
    if (p != nullptr) {
        _Unsafe { __assume_null(p); }
        *p = 2;  // error: cannot dereference possibly-null status pointer 'p'
    }
}
```

A *new* null check after the assumption narrows it again as usual.

**Argument rules** (extended 2026-09, all verified):
- Must be a **trackable expression**: a variable, a struct field access
  (`s.p`, `s->p`), a pointer dereference chain (`*q`, `**q`), or those wrapped
  in parens / implicit casts. A comma expression, a ternary, an explicit cast
  (`(int *_Nullable)p`), a call, or an array subscript `arr[0]` is
  `error: __assume_null requires a trackable expression as argument`. Bind such
  a value to a local first.
- Its type must be a **`_Nullable` pointer or a struct**. A `_Nonnull` pointer
  or a plain `_Owned`/`_Borrow` pointer (`_Nonnull` by default) is
  `error: __assume_null requires a _Nullable pointer argument`; a non-pointer,
  non-struct such as `int x` is
  `error: __assume_null requires an argument of pointer or struct type`.

**Struct form** — `__assume_null(*s)` / `__assume_null(s)` asserts, for every
`_Nullable` pointer field of the struct (recursively through embedded structs),
that it is null, and for every `_Owned _Nullable` field that it holds no
ownership. Nothing else changes: a later `*(s->p1) = 1` is
`error: cannot dereference possibly-null status pointer 'p1'`, and a by-value
`struct S s` parameter with two `_Owned _Nullable` fields reports no leak at
scope exit (without the builtin the same function is `error: memory leak
because s.p1, s.p2 are not freed or moved before 's' goes out of scope`).

```c
struct S { int *_Owned _Nullable p1; int *_Owned _Nullable p2; };
_Safe void consumeS(struct S *_Owned s);
_Safe void foo(struct S *_Owned s) {
    _Unsafe { __assume_null(*s); }   // s->p1, s->p2 assumed null and unowned
    consumeS(s);                     // moves s → no leak
}
```

Struct-form restrictions:
- The struct must not contain a `_Nonnull` field, directly or in an embedded
  struct: `error: __assume_null is invalid because the struct contains a
  _Nonnull field` + `note: a _Nonnull field cannot be assumed null; assume
  each _Nullable field individually if needed` — i.e. write
  `__assume_null(s->p)` per `_Nullable` field instead.
- Array fields are **not covered** (no per-element null state):
  `warning: __assume_null has no effect on array field 'ya' containing a
  _Nullable pointer [-Wbsc-assume-null]`, and such a field still leaks if it
  held ownership.
- A struct with no `_Nullable` pointer field at all is a no-op:
  `warning: __assume_null has no effect: the struct does not contain any
  _Nullable pointer field [-Wbsc-assume-null]`. Note a bare `int *p` field
  counts as `_Nullable` (the raw-pointer default), so it does not warn.

> Compare `__forget(p)` (`bsc-ownership` §5), which drops ownership of a
> **non-nullable** `_Owned` pointer without asserting anything about null.

## 10. Compiler Options

`-nullability-check=<mode>`:

| Mode | Behavior |
|------|----------|
| `safeonly` (default) | Only check in `_Safe` zones |
| `all` | Check in all code (safe and non-safe) |

Without the option, behavior is equivalent to `-nullability-check=safeonly`.
The full BSC option list is in `bsc-compile` §2.

## 11. Limitation: Pointer Aliasing Is Not Tracked

The checker does not model aliases between raw pointers (or between a raw
pointer and a safe pointer). Aliases created among *safe* pointers by borrowing
and reborrowing are handled by the borrow rules, so a `_Safe` zone still has no
null dereference — but in an unsafe zone, writing null through one alias and
dereferencing through the other is **not reported**, even with
`-nullability-check=all` (verified):

```c
void f(int **p) {
    int **p2 = p;               // alias of p
    if (p && *p && p2) {
        *p2 = nullptr;          // nulls *p through the alias
        **p = 10;               // real null dereference, no diagnostic
    }
}
```

If you want null safety in unsafe code, avoid introducing pointer aliases.

> For ownership and `_Owned _Nullable`, see `bsc-ownership` Skill
> For borrowing and `_Borrow _Nullable`, see `bsc-borrowing` Skill
> For safe zones, see `bsc-safe-zone` Skill
> For nullability errors (BSC-E04xx), see `bsc-errors` Skill
