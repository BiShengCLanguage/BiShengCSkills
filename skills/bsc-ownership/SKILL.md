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
- No pointer arithmetic on `_Owned` pointers (no `+`, `-`, `[]`, `++`, `--`)
- Comparison operators (`==`, `!=`, `<`, etc.) are allowed
- No implicit conversion between `_Owned` and raw pointers in **either** direction — strict type matching
- Explicit cast between `_Owned` and raw pointers requires `_Unsafe` context
- Exception: `T *_Owned` -> `void *_Owned` is allowed in safe context

### Prohibited uses of `_Owned`
- **Global variables** (including function-local `static`)
- **Union members**: `_Owned` cannot modify union type members
  ```c
  union U { int *_Owned p; };  // ERROR
  ```
- **Array elements**: cannot store `_Owned` pointers in arrays, including structs with `_Owned` members as array elements

### Nullable `_Owned` pointers
- `int *_Owned _Nullable p = nullptr;` allows null owned pointers
- `__take_from_raw` and `__move_to_raw` preserve Nullability

### Logical and conditional operators
- Logical operators (`!`, `&&`, `||`) work on `_Owned` pointers (null checks, no ownership consumed)
- `_Owned` pointers can be conditions in `if`/`while`/`do-while`/`for`/ternary, but **NOT** `switch`
- Implicit `_Owned` -> `_Bool` conversion is allowed (does not consume ownership)

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

### `_Owned` with generics
In generic functions, when `_Owned` modifies generic type parameter T (as `T _Owned` or `_Owned T`), `_Owned` applies to the complete type T. When T instantiates as `int*`, the result is `int* _Owned`.

## 6. _Safe / _Unsafe Context

- `_Safe` functions use `safe_malloc`/`safe_free`; raw `malloc`/`free` require `_Unsafe` blocks
- Functions without `_Safe` or `_Unsafe` are non-safe by default

## 7. Owned Structs (RAII)

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
- Global `_Owned struct` variables do not have their destructors called (including function-local `static`)

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

> See also: `bsc-borrowing`, `bsc-safe-zone`, `bsc-nullability`, `bsc-design`, `bsc-errors` Skills
