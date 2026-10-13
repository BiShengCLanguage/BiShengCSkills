---
name: bsc-ownership
description: "BiSheng C ownership system. When you need to understand _Owned pointers, move semantics, _Owned structs, destructors, RAII, _Public/_Private access, _Nullable, safe_malloc/safe_free, ownership transfer rules, or _Owned with traits/unions/function pointers, use this Skill."
---

# BiSheng C Ownership Skill

## CRITICAL: `_Owned` Syntax

**`_Owned` goes AFTER the `*`, not before the type.** It is a pointer qualifier, like `const`.

```c
// CORRECT — _Owned after *
int *_Owned p = safe_malloc(42);

// WRONG — _Owned before type (DOES NOT COMPILE)
_Owned int* p = safe_malloc(42);
```

Same rule applies to `_Borrow`: write `int *_Borrow`, not `_Borrow int*`.

## 1. Overview

Move semantics for compile-time memory safety. Prevents use-after-free and double-free at compile time. Once ownership transfers, the original variable is dead.

Use `safe_malloc` / `safe_free` (from `bishengc_safety.hbs`) as the idiomatic allocation APIs. Raw `malloc`/`free` require `_Unsafe` context and explicit casts.

## 2. safe_malloc / safe_free

Signatures: `T *_Owned safe_malloc<T>(T t)` — allocates, initializes to `t`, returns `T *_Owned`.
`void safe_free(void *_Owned)` — frees an `_Owned` pointer. No cast needed for `safe_malloc`:
```c
#include "bishengc_safety.hbs"
_Safe void example(void) {
    int *_Owned p = safe_malloc(42);       // no cast needed
    safe_free((void *_Owned)p);            // must cast to void *_Owned
}
```

**malloc/free alternative** (requires `_Unsafe` context):
```c
_Unsafe {
    int *_Owned p = (int *_Owned)malloc(sizeof(int));  // raw->owned cast
    *p = 42;
    free((void *_Owned)p);
}
```

## 3. Owned Pointers

```c
#include "bishengc_safety.hbs"

int *_Owned create(int val) {
    return safe_malloc(val);  // ownership transfers to caller
}

void consume(int *_Owned p) {
    int val = *p;
    safe_free((void *_Owned)p);
}

_Safe int main(void) {
    int *_Owned p = create(21);
    int *_Owned p2 = p;        // ownership MOVES; p is now dead
    consume(p2);               // p2 is now dead
    int *_Owned _Nullable maybe = nullptr;  // nullable owned pointer
    return 0;
}
```

## 4. Multi-level Pointer Release (Inner to Outer)

For multi-level pointers, release from inner to outer. For structs with `_Owned` pointer members, free all `_Owned` members first, then the struct pointer.

```c
#include "bishengc_safety.hbs"
struct S { int *_Owned p; int *_Owned q; };

_Safe void foo(void) {
    // Multi-level pointer: free inner first, then outer
    int *_Owned inner = safe_malloc(1);
    int *_Owned *_Owned pp = safe_malloc(inner);
    safe_free((void *_Owned)*pp);
    safe_free((void *_Owned)pp);

    // Struct with _Owned members: free members first, then struct
    struct S s = {.p = safe_malloc(2), .q = safe_malloc(3)};
    struct S *_Owned sp = safe_malloc(s);
    safe_free((void *_Owned)sp->p);
    safe_free((void *_Owned)sp->q);
    safe_free((void *_Owned)sp);
}
```

## 5. Rules

- **`_Owned` goes after the `*`**: write `int *_Owned`, NOT `_Owned int*`
- `_Owned` can only modify **pointer types**, not non-pointer types
- `_Owned` types have **move semantics**: assignment, passing, returning **transfers** ownership
- After transfer, the original variable is **dead** — any use is a compile error
- Before scope ends, `_Owned` variables **must** have ownership released
- Release by: (a) passing to function taking `_Owned`, (b) `safe_free((void *_Owned)p)`, (c) returning, (d) assigning to another `_Owned` variable
- No pointer arithmetic on `_Owned` pointers (no `+`, `-`, `[]`, `++`, `--`). For an `_Owned` pointer that owns an array and needs `[]`, use `_Owned _ArrayElem` instead — see §8.
- Comparison operators (`==`, `!=`, `<`, etc.) are allowed
- No implicit conversion between `_Owned` and raw pointers in **either** direction — strict type matching
- Explicit cast between `_Owned` and raw pointers requires `_Unsafe` context
- Exception: `T *_Owned` -> `void *_Owned` is allowed in safe context

### Prohibited uses of `_Owned`
- **Global and static variables**: a global or function-local `static` cannot be `_Owned`-qualified, a struct containing `_Owned` members, or an array of either
  ```c
  struct A { int *_Owned p; };
  int *_Owned g_p;        // ERROR
  struct A g_a;           // ERROR
  int *_Owned g_arr[2];   // ERROR (array of _Owned)
  struct A g_arr2[2];     // ERROR
  ```
- **Union members**: `_Owned` cannot modify union type members
  ```c
  union U { int *_Owned p; };  // ERROR
  ```

**Local** arrays and struct-member arrays of `_Owned` types **are allowed** (this was forbidden before 2026-08) — with special whole-array ownership rules, see §9.

### Nullable `_Owned` pointers
- `int *_Owned _Nullable p = nullptr;` allows null owned pointers
- `__take_from_raw` and `__move_to_raw` preserve Nullability

For an `_Owned _Nullable` pointer the binary owns/lost-ownership state is combined with the null-state the nullability analysis tracks (see `bsc-nullability`), giving three cases:

- **Definitely null** — never owns. Every transfer operation (init/assign to another `_Owned _Nullable`, pass to an `_Owned _Nullable` param, `return`, `__move_to_raw`/`__move_array_to_raw`) is allowed as a no-op; borrows `&_Mut *p`/`&_Const *p` are allowed and yield null; dereference is an error; **scope exit reports no memory leak** (`int *_Owned _Nullable p = nullptr;` needs no free).
- **Definitely non-null** — behaves like a `_Nonnull` `_Owned` pointer: transfer ops require and consume ownership, deref/borrow require ownership without consuming it, unfreed at scope exit is a leak error.
- **Maybe null** — same as definitely non-null, except: **dereference is an error** (`error: cannot dereference possibly-null status pointer 'p'` — null-check first), and transfer targets must themselves be `_Nullable` (`int *_Owned q = p;` is `error: cannot assign possibly-null status pointer 'p' to a '_Nonnull' pointer`; use `int *_Owned _Nullable q = p;`). Unfreed at scope exit is still a leak error (`memory leak because 'p' is not freed or moved before it goes out of scope`) — `safe_free((void *_Owned _Nullable)p)` accepts maybe-null pointers directly, no null check needed.

Assigning into an `_Owned _Nullable` that currently holds no ownership propagates the RHS state: null RHS → definitely null (RHS untouched); owning RHS → ownership and null-state move over, RHS loses ownership.

Note: the deref and nullable→nonnull restrictions are enforced by the **nullability** analysis — with `-nullability-check` off (or outside its scope), only the ownership half applies.

### `__forget` — explicitly drop ownership

`__forget(e)` is a builtin that makes the analyzer treat the `_Owned` pointer
`e` as **no longer owning** (Moved). Like `__assume_null`, it is a **pure
analyzer hint** — no verification, no generated code; you promise the value
will never be freed or moved again.

**`_Unsafe`-only**:

```c
_Safe void foo(int *_Owned p) {
    __forget(p);  // error: __forget is forbidden in the safe zone
}
```

After the call `p` needs no free and no transfer — **no leak at scope exit**:

```c
void forget_local(void) {
    int *_Owned p = safe_malloc(42);
    _Unsafe { __forget(p); }
}   // ok — without the __forget this is
    // error: memory leak because 'p' is not freed or moved before it goes out of scope
```

Using `p` afterwards is `error: use of moved value: 'p'`, but **reassigning**
it is fine (Moved variables may be reassigned), and the new value resumes
normal tracking:

```c
void reassign(void) {
    int *_Owned p = safe_malloc(1);
    _Unsafe { __forget(p); }
    p = safe_malloc(2);   // ok
    safe_free(p);
}
```

Works on `_Owned` struct fields (`s.p`, `s->p`, `(*s).p`) — that field is then
exempt from the field-leak check — and on `_Owned _Nullable` pointers.

**Argument rules** (extended 2026-09-21, all verified):
- Must be a **trackable expression**: a variable, a struct field access, an
  array element, a pointer dereference, or chains of those (`(*s).p`, `s->in.p`,
  `arr[i]`), optionally in parens / implicit casts. A comma expression, a
  ternary, or an **explicit cast** `(int *_Owned)p` is
  `error: __forget requires a trackable expression as argument` (OWN-051).
- Its type must be an **`_Owned` pointer or a struct that (recursively)
  contains an `_Owned` pointer field**. A `_Borrow`, raw or `_Nonnull` pointer,
  a non-pointer, or a struct without owned fields is
  `error: __forget requires an _Owned pointer or a struct containing ownership` (OWN-050).
- **Struct form**: `__forget(t)` forgets *every* `_Owned` field of `t`,
  recursively through embedded structs (`t.in.p` and `t.q` together); no leak
  at scope exit, and a later `sink(t.q)` is `use of moved value: 't.q'`.
- **Array elements** follow the array-transfer rule (§9): `__forget(arr[i])`
  is allowed only inside a qualifying full-range `for` loop. Outside one,
  `__forget(arr[0])` is `error: cannot transfer ownership of array element
  `arr` outside a qualifying for-loop; use a full-range for-loop or safe_swap`
  (and the array then leaks).
- **Not through a borrow**: with `int *_Owned *_Borrow q = &_Mut p`,
  `__forget(*q)` (or `__forget(w->p)` for `struct W *_Borrow w`) is
  `error: cannot take ownership of a borrowed value` (BOR-014). Dereferencing
  an **`_Owned` pointer** is fine (`__forget(*s)`, `__forget((*s).p)` for
  `struct S *_Owned s`). Through a **raw** pointer (`__forget(r->p)`, `struct
  S *r`) the call compiles with no diagnostic.

> **`__forget(p)` vs `forget<T>(t)`**: different tools with similar names.
> `forget<T>` is a `_Safe` **library function** (`bishengc_safety.hbs`) that
> *consumes a value* by taking ownership of it and dropping it. `__forget` is
> an `_Unsafe`-only **builtin** that takes an `_Owned` pointer **lvalue** and
> rewrites the analyzer's state for that variable in place.

> For `__assume_null` (the nullability counterpart, which also drops ownership
> of an `_Owned _Nullable`), see `bsc-nullability` §9.

### Logical and conditional operators
- Logical operators (`!`, `&&`, `||`) work on `_Owned` pointers (null checks, no ownership consumed)
- `_Owned` pointers can be conditions in `if`/`while`/`do-while`/`for`/ternary, but **NOT** `switch`
- A condition is a **read**: after `sink(p)`, `if (p)` or `while (p)` is `error: use of moved value: 'p'` (diagnosed since 2026-09; statement conditions were previously skipped)
- Implicit `_Owned` -> `_Bool` conversion is allowed (does not consume ownership)
- An `_Owned` pointer may appear in a **comma expression** (`(a, p)`). Whether the comma expression consumes ownership depends on where the result is used: as an `if`/`while` condition it does **not** consume; as an initializer, assignment RHS, or call argument it **does** move ownership (e.g. `int *_Owned q = (++a, p);` moves `p` into `q`)

### `_Owned` with `_Trait` types
- Implicit conversion: `S *_Owned` to `_Trait T *_Owned` if `S` implements `T`
- Can call trait methods through `_Trait T *_Owned` pointers

### Function pointer matching
- Function pointer types must match `_Owned` annotations exactly — cannot assign an `_Owned`-parameter function to a non-`_Owned`-parameter pointer or vice versa

### Explicit ownership transfer interfaces
- `__move_to_raw(p)` — moves ownership out, returns raw pointer
- `__take_from_raw(p)` — takes ownership from raw pointer, returns `_Owned` pointer
- Both preserve Nullability

### Conversion order matters
When converting between `T *_Owned` and `void *`:
- **Order 1**: `T *_Owned` → `void *_Owned` → `void *` (internal `_Owned` pointers must NOT have ownership)
- **Order 2**: `T *_Owned` → `T *` → `void *` (internal `_Owned` pointers KEEP ownership)

The reverse cast `void *_Owned` → `T *_Owned` is allowed (in `_Unsafe`) when the variable still owns memory, **but the resulting struct's inner `_Owned` members do NOT own their pointees** after the cast. You must either reassign them before reading or treat them as raw. Example: after `struct S *_Owned sp = _Unsafe((struct S *_Owned)memAlloc(...));`, reading `sp->p` as `int *_Owned` is a compile error until `sp->p` is reassigned.

### `_Owned` with generics
In generic functions, when `_Owned` modifies generic type parameter T (as `T _Owned` or `_Owned T`), `_Owned` applies to the complete type T. When T instantiates as `int*`, the result is `int* _Owned`.

## 6. _Safe / _Unsafe Context

- `_Safe` functions use `safe_malloc`/`safe_free`; raw `malloc`/`free` require `_Unsafe` blocks
- Functions without `_Safe` or `_Unsafe` are non-safe by default

## 7. Owned Structs (RAII)

> ⚠️ **Experimental feature** — `_Owned struct` (unlike plain `_Owned` **pointers**, which are stable) is a low-priority BSC feature and requires `-fbsc-experimental` (otherwise `error: _Owned struct is an experimental BSC feature; enable with -fbsc-experimental`). libcbs containers (`Vec<T>`, `String`, …) are `_Owned struct`s internally, so including their headers forces the flag too. The example below also needs the flag for its member functions and destructor.

```c
#include "bishengc_safety.hbs"
#include <stdio.h>

_Owned struct Buffer {
_Private:                    // _Private is the DEFAULT access modifier
    char *_Owned data;
    int len;
_Public:
    int cap;
    ~Buffer(Buffer this) {   // destructor — auto-called at scope end
        safe_free((void *_Owned)this.data);  // _Owned members MUST be freed here
    }
};

Buffer Buffer::new(int capacity, char init) {
    return (Buffer){ .data = safe_malloc(init), .len = 0, .cap = capacity };
}

_Safe int main(void) {
    {
        Buffer buf = Buffer::new(256, '\0');
    }   // ~Buffer auto-called here
    {
        Buffer buf1 = Buffer::new(128, '\0');
        Buffer buf2 = buf1;  // MOVE: buf1 is dead, only ~Buffer(buf2) called
    }
    return 0;
}
```

### 7.1 Owned Struct Rules

- `_Owned struct` has move semantics as a whole
- Destructor syntax: `~TypeName(TypeName this) { ... }` inside the struct body
- Destructor is called automatically when variable goes out of scope (if not moved)
- **Destructor cannot be explicitly called by the user** — only the compiler invokes it
- If no destructor is defined, the compiler provides a default one
- `_Owned` pointer members inside the struct **must** be manually freed in the destructor
- **Access modifiers**: `_Private` (default) and `_Public` — only members/functions inside the struct body can access `_Private` members; extension functions and external code can only access `_Public` members
- **Partial move is prohibited**: at scope end, an `_Owned struct` must be either fully owned (nothing moved out) or entirely moved as a whole. Moving individual `_Owned` members while keeping the struct causes a compile error
- Global `_Owned struct` variables do not have their destructors called. A function-local `static` variable **cannot** be `_Owned`, `_Borrow`, or an `_Owned struct` type at all — that's a compile error (so the question of running its destructor never arises)

### 7.2 Pitfall: Tagged-struct as union-replacement carries hidden cost

When you replace a C union with an `_Owned struct` containing all variant
fields (a common pattern because BSC has no safe `_Owned` union), **every
instance carries the destructor cost of every variant**, not just the active one.

```c
// Replaces a C union { Object*; Array*; double; ... }
_Owned struct ValueValue {
_Public:
    String         string;
    double         number;
    Object* _Owned object;   // heap-allocated for EVERY instance
    Array*  _Owned array;    // heap-allocated for EVERY instance
    int            boolean;

    ~ValueValue(ValueValue this) {
        free_Object(this.object);   // ALWAYS runs, even for non-Object values
        free_Array(this.array);
    }
};
```

Consequences to be aware of:

- Construction allocates **all** heap pointers via `safe_malloc` (one per
  variant pointer field), even for primitive variants like `JSONNull` or
  `JSONBoolean`.
- Destruction calls `safe_free` on **all** of them — so any aliasing across
  instances (especially through `clone` paths or `safe_swap` patterns)
  doubles the free.
- Memory cost is constant per value but **multiplies across containers**
  (a `Vec<ValueValue>` of 1000 nulls still allocates 1000 Objects + 1000 Arrays).

**Mitigations to consider at design time** (cross-ref `/bsc-design` Rule 7
and §2 "Replacing C unions"):

- Trait-based sum type for genuinely heterogeneous variants
- Lazy initialization (allocate inner heap only when the variant is set)
- Accept the cost and document it explicitly with a FIXME

When debugging double-frees in code that uses this pattern, the most likely
cause is field-level aliasing introduced by `clone` or `safe_swap` on the
all-fields struct — see `/bsc-common-mistakes` §8.

### 7.3 Raw pointer as heap buffer field (RawVec idiom)

A plain `T *_Owned` **forbids array subscript** (`ptr[i]`). For a heap-allocated
array that needs indexing you have two safe options:

1. **`T *_Owned _ArrayElem`** (preferred when the buffer really is a uniform
   array of `T`) — supports `[]` and pointer arithmetic, stays in `_Safe`. See §8.
2. **Raw `T *` field** (the RawVec idiom, below) — needed when the buffer is
   reinterpreted (byte buffer of mixed records), is allocated by a non-BSC
   API (`malloc` from a C library), or otherwise doesn't fit `_ArrayElem`'s
   uniform-element model.

The `_Owned struct` destructor handles freeing in both cases.

```c
// WRONG — _Owned ptr forbids subscript; this->data[i] = v is a compile error
struct BadBuf {
    uint8_t *_Owned data;
    size_t   used;
};

// CORRECT — raw T* field; struct destructor owns the allocation
_Owned struct GoodBuf {
_Public:
    uint8_t *data;   // raw pointer — indexing works
    size_t   used;
    size_t   cap;

    ~GoodBuf(GoodBuf this) {
        _Unsafe { free(this.data); }   // manual free; struct is the owner
    }
};
```

All reads and writes through the raw field must be wrapped in `_Unsafe`:

```c
_Safe void buf_write(GoodBuf *_Borrow _Nonnull this, uint8_t v) {
    _Unsafe this->data[this->used] = v;   // raw subscript — _Unsafe statement
    this->used += 1;
}
```

For plain `struct` (non-`_Owned`) wrappers, the pattern is identical: raw `T *`
field, `_Unsafe` around all dereferences, explicit `free` in a paired destroy
function rather than a destructor. The distinction from `T *_Owned` is intentional
and load-bearing: with raw `T *` the struct itself is the logical owner; the field
is just a cursor.

### 7.4 `_Owned struct` must be defined at file scope

`_Owned struct S { ... };` definitions can only appear at translation-unit (file)
scope — alongside `_Trait` definitions and function definitions. They **cannot**
be defined inside a function body or block (this differs from standard C where
plain `struct` may be defined locally).

```c
// CORRECT — file scope
_Owned struct Person { _Public: int age; ~Person(Person this) {} };

_Safe int main(void) {
    Person p = {.age = 18};
    // _Owned struct S { };  // error: cannot be defined in function scope
    return 0;
}
```

Compiler error: `_Owned struct cannot be defined in function scope; move the
definition to file scope`.

## 8. `_ArrayElem`: Owned Pointers That Index Into Arrays

A second qualifier, `_ArrayElem`, can be combined with `_Owned` (or `_Borrow` —
see `bsc-borrowing`) to form a pointer **into a heap-allocated array of T**.

```
T *_Owned _ArrayElem p;   // owns a heap array of T, supports p[i], p == q
```

`_Owned _ArrayElem` follows all the rules of plain `_Owned` (move semantics,
must be released, no implicit cast to/from raw, etc.) with these differences:

- **`[]` subscript is allowed** (`p[i] = ...`, `int x = p[i];`)
- Pointer **arithmetic is still forbidden** (`p += 1` is an error — even on
  `_Owned _ArrayElem`)
- Comparison (`==`, `!=`) is allowed
- Allocate / free with **array-specific** APIs (from `bishengc_safety.hbs`):

  ```c
  _Safe T *_Owned _ArrayElem safe_malloc_array<T>(size_t n, T initial);
  _Safe void safe_free_array(void *_Owned _ArrayElem);
  ```

- Raw-pointer conversion uses dedicated builtins (not `__move_to_raw` /
  `__take_from_raw`):
  - `__move_array_to_raw(p)` — moves an `_Owned _ArrayElem` out to a raw pointer
  - `__take_array_from_raw(p)` — takes a raw pointer as `_Owned _ArrayElem`
- **C-style casts between `T *`, `T *_Owned`, and `T *_Owned _ArrayElem` are
  forbidden** — these three are distinct categories. Use the array builtins.
- The pointee type `T` may be anything, including `_Borrow` pointers and
  structs containing them (the 2026-08 "cannot be or contain `_Borrow`"
  restriction was dropped in 2026-09 together with the multi-level-borrow ban).
  Pointees that are `_Owned` pointers or structs **containing `_Owned` members
  are allowed** (relaxed 2026-08) — such heap arrays follow the whole-array
  ownership rules of §9, and `safe_malloc_array` cannot allocate them (its
  per-element copy of the initializer would move it repeatedly); use
  `safe_calloc_array<T>` or `__take_array_from_raw` instead.
- **No bounds checking**: `_ArrayElem` records "points into an array", not the
  length. `p[i]` past the end compiles even in `_Safe` code — safe zones give no
  spatial memory-safety guarantee for `_ArrayElem` pointers.
- `_ArrayElem` cannot modify a **raw** pointer; it only attaches to `_Owned` or
  `_Borrow`.

```c
#include "bishengc_safety.hbs"

_Safe int main(void) {
    int *_Owned _ArrayElem p = safe_malloc_array(10, 0);  // [0]..[9] = 0
    p[3] = 3;                                             // ok: subscript
    // p += 1;                                            // error: no arithmetic
    int *_Owned _ArrayElem q = safe_malloc_array(10, 1);
    if (p == q) { /* ... */ }                             // ok: comparison
    safe_free_array((void *_Owned _ArrayElem)p);
    safe_free_array((void *_Owned _ArrayElem)q);
    return 0;
}
```

**`_Safe` / `_Unsafe` interop**: the compatibility rules treat `_Owned _ArrayElem`
and `_Borrow _ArrayElem` as **whole qualifiers** — a `_Safe` redeclaration may
add `_Owned _ArrayElem` to an unannotated `_Unsafe` parameter, but you cannot
"upgrade" `_Owned` to `_Owned _ArrayElem` or move between `_Owned` and
`_Owned _ArrayElem` across declarations.

### When to prefer `_Owned _ArrayElem` over the RawVec idiom (§7.3)

- Buffer is a uniform array of one element type `T` and you index it as such
  → `_Owned _ArrayElem`.
- Buffer is treated as raw bytes, reinterpreted, or comes from a non-BSC
  allocator → keep raw `T *` field + `_Unsafe` (RawVec).

## 9. Arrays of `_Owned` Elements (qualified for-loops)

Since 2026-08, **local arrays and struct-member arrays may hold `_Owned` types
or structs containing `_Owned` members** (globals/statics still cannot — §5).
The compiler cannot track per-index ownership, so it treats the whole array as
one unit: all indices of the same `_Owned` member share **one ownership state**.
Ownership may therefore only change in ways that provably affect every element
the same way:

1. Inside a **qualified for-loop** (below), elements follow the normal
   single-variable `_Owned` rules; the state of `a[i]` at loop end becomes the
   state of the whole array.
2. Outside a qualified loop, `safe_swap(&_Mut a[0], &_Mut tmp)` reads/writes an
   element **without** an ownership transfer.
3. Any other ownership transfer of an element (assign, init, pass, return) is
   an error: ``cannot transfer ownership of array element `a` outside a
   qualifying for-loop; use a full-range for-loop or safe_swap``
   (`err_ownership_array_elem_transfer_forbidden`; a note explains which loop
   condition failed, e.g. "loop bound must equal the array length", "loop body
   must not return or goto early"). Non-transferring uses (dereference,
   comparison, borrowing) stay legal anywhere.

If elements still own memory when the array leaves scope, that's the usual
memory-leak error.

```c
#include "bishengc_safety.hbs"

_Safe void test(void) {
    int *_Owned a[3] = {safe_malloc(1), safe_malloc(2), safe_malloc(3)};
    for (int i = 0; i < 3; i++) {
        safe_free((void *_Owned)a[i]);   // ok: qualified for-loop
    }
}
```

### 9.1 What makes a for-loop "qualified"

For an array `a` **whose type carries its length** (fixed-size arrays and
VLAs), all of the following:

1. Init: `for (T i = 0; ...)` — `T` an integer type, start at 0, step exactly
   +1 (`i++`, `++i`, `i += 1`).
2. Condition: `i < N` where `N` is the array length (for a variable bound, `N`
   must not be modified, address-taken, or borrowed in the function), and `T`'s
   range must cover `N`.
3. Body doesn't modify `i`, take its address, or mutably borrow it.
4. No early exit from the loop: no `break`, `return`, or `goto` out of it
   (`continue` and inner-loop `break`/local `goto` are fine).
5. The array is only accessed as `a[i]` (1-D), `a[i][j]` (multi-D — outer loop
   = first dimension, dimension order must match the declaration), or
   `a[i].field`.

Loop-end ownership must be **consistent across paths** — freeing only some
indices (`if (i != 1) safe_free(...)`) is an error
(``ownership state of array element `a` is inconsistent across paths in
for-loop body``). A null-check skip is fine: null elements count as not owning,
so `if (a[i] != nullptr) safe_free(...)` passes.

**Flexible array members never qualify** (since 2026-09). For
`struct S { int len; int *_Owned arr[]; };` the array type has no length, so
no loop bound can be checked against it — `for (int i = 0; i < s->len; i++)
safe_free((void *_Owned)s->arr[i]);` is ``cannot transfer ownership of array
element `s` outside a qualifying for-loop`` with `note: for-loop is not a
qualifying for-loop: condition must be `i < N` where N is the array length`
(verified; the same loop over a fixed-size member `int *_Owned arr[3]` passes).
Such members can only be moved via `safe_swap`, or handled in `_Unsafe`.

**Array parameters** (since 2026-09): a parameter `T a[N]` whose `T` is or
contains `_Owned`/`_Borrow` is adjusted to `T *_Borrow _ArrayElem a`, not to a
raw pointer — inside the callee the elements are *borrowed*, so no qualified
loop can move them out (`cannot take ownership of a borrowed value` + `note:
array parameter 'a' is adjusted to a '_Borrow _ArrayElem' pointer; its
elements are borrowed and cannot be moved out`). The caller keeps ownership.
See `bsc-borrowing` §12.2.

### 9.2 Assigning into elements

An element that still owns memory cannot be assigned over — not even with
`nullptr` (`cannot assign to 'a[]' because it still holds an _Owned value;
move or free it first`, `err_ownership_array_elem_assign_owned`). Only null /
moved / uninitialized elements may be (re)assigned, and assignment is itself a
transfer, so it must happen in a qualified loop (or via `safe_swap`).

### 9.3 Struct arrays: per-field tracking

For arrays of structs with several `_Owned` fields, each field has its own
whole-array state — a qualified loop may move `s[i].a` while `s[i].b` stays
owned, and scope exit reports leaks per field:

```c
struct S { int *_Owned a; int *_Owned b; };
_Safe void fields(void) {
    struct S s[2] = {{safe_malloc(1), safe_malloc(2)},
                     {safe_malloc(3), safe_malloc(4)}};
    for (int i = 0; i < 2; i++) {
        safe_free((void *_Owned)s[i].a);
        s[i].a = s[i].b;                 // b moves out, a moves in
    }
    for (int i = 0; i < 2; i++) {
        safe_free((void *_Owned)s[i].a);
    }
}   // ok: neither field owns anything here
```

### 9.4 Heap arrays (`_Owned _ArrayElem`) with `_Owned` elements

`T *_Owned _ArrayElem` pointers whose `T` contains `_Owned` members (§8) are
**stricter than true arrays**: the qualified-for-loop exemption does *not*
apply to them — `p[i].field = ...` / `safe_free(... p[i].field)` are rejected
with the same ``cannot transfer ownership of array element `p` outside a
qualifying for-loop`` error **even inside a full-range constant-bound loop**
(verified; the compiler has no length to check a heap loop against). What
works:

- **reads** (`*p[0].f` after a null check via a trackable temp), comparisons,
  borrows;
- **`safe_swap(&_Mut p[i].field, &_Mut tmp)`** to move values in or out;
- **`__move_array_to_raw(p)`** to move the whole array to a raw pointer and
  continue in `_Unsafe` (this is also the only way to free such an array —
  `safe_free_array((void *_Owned _ArrayElem)p)` is rejected with
  `cannot cast 'p' to 'void * _Owned': p.f is still _Owned` because the
  analysis conservatively treats the elements' fields as owning, null-filled
  or not).

Allocate with `safe_calloc_array<T>` (zero-init ⇒ null `_Nullable` fields) or
`__take_array_from_raw` — **not** `safe_malloc_array` (see `bsc-stdlib`).

> See also: `bsc-borrowing`, `bsc-safe-zone`, `bsc-nullability`, `bsc-design`, `bsc-errors` Skills
