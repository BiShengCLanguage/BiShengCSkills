---
name: bsc-safe-zone
description: "BiSheng C safe zones. When you need to understand _Safe functions, _Safe blocks, _Unsafe escape blocks, safe zone restrictions (initialization, pointers, type casts, enum/float conversions, ++/-- semantics), trait/generic safety, member function safety, mixed safe/unsafe redeclarations, the unsafe-safe refinement relation, or BSC type compatibility (sticky vs non-sticky qualifiers), use this Skill."
---

# BiSheng C Safe Zones Skill

## A Function With `_Unsafe { ... }` Inside Is STILL `_Safe`

`_Safe` and `_Unsafe { ... }` are not in conflict; the whole point of an
`_Unsafe` block is to give the function a local escape. Do not demote a
function from `_Safe` to `_Unsafe` because its body needs one or two
escape lines. `_Unsafe` is contagious — making the function `_Unsafe`
forces every caller to also be `_Unsafe`.

## `_Unsafe` Blocks Must Be Minimal

Wrap only the statements that genuinely require the escape, and nothing
else. Re-check each line you put inside `_Unsafe { ... }`: if it would
compile fine in `_Safe`, move it out.

```c
// BAD — bloated _Unsafe block, only the assignment needs the escape
_Safe void f(uint8_t *buf, size_t i, uint8_t v) {
    _Unsafe {
        if (i >= cap) return;
        validate(v);
        buf[i] = v;
        log("wrote byte");
    }
}

// GOOD — only the raw subscript is _Unsafe
_Safe void f(uint8_t *buf, size_t i, uint8_t v) {
    if (i >= cap) return;
    validate(v);
    _Unsafe buf[i] = v;
    log("wrote byte");
}
```

`_Unsafe stmt;` (single statement, no braces) is often the right shape.

## 1. Overview

Designate code regions where the compiler enforces memory safety. Default context is `_Unsafe` (standard C compatibility). Use `_Safe` to opt in to strict checking.

## 2. Syntax

`_Safe` / `_Unsafe` can modify: function declarations, function definitions, function signatures, function pointers, statements, and parenthesized expressions.

```c
_Safe int add(int a, int b) { return a + b; }  // safe function

void example(void) {
    _Safe { int x = 10; }         // safe block
    _Safe int y = 1;              // safe statement
}

_Safe void process(const int *_Borrow v) {
    _Unsafe { printf("%d\n", *v); }  // unsafe escape (printf is variadic)
    _Unsafe int c = 1;               // unsafe statement
    char d = _Unsafe((char)c);       // unsafe expression
}
```

Cannot use `_Safe`/`_Unsafe` on: global variables, type declarations outside functions, or `typedef` (except function pointer typedefs).

## 3. Restrictions (compiler-enforced)

In `_Safe` zones:

### Pointer operations
- **No `&` address-of** — use `&_Const` or `&_Mut` to take borrows. Exception: taking the address of a function is allowed.
- **No raw pointer dereference** (`*rawptr`, `rawptr->field`) — `_Owned` and `_Borrow` pointer dereference is OK
- **No pointer category casts** — no casting between `_Owned`/`_Borrow`/raw pointers, no pointer-to-integer or integer-to-pointer casts. Exception: `T *_Owned` can be explicitly cast to `void *_Owned`.
- **No casts between pointers of different pointed-to types** — with these same-category exceptions (all in the matrix below): owned/borrow pointers to `void`-pointee targets, and (since 2026-08) raw `T *` to `void *`, `const T *`, or `const void *` (the `void` targets require `T` `is_trivial_data`; implicit and explicit behave the same). The reverse raw casts (`void *`→`T *`, dropping `const`) stay forbidden in safe zones
- **`nullptr` required** — `NULL` is forbidden in safe zones; use `nullptr` to initialize or compare pointers

#### Pointer conversion matrix

| Conversion | In `_Safe` | In `_Unsafe` |
|---|---|---|
| `T *_Borrow` → `void *_Borrow` (T is trivial data: no pointers, not `_Owned struct`) | **OK** (implicit or explicit) | OK |
| `T *_Borrow` → `void *_Borrow` (T has pointer fields / is `_Owned struct`) | **Forbidden** (even with explicit cast) | OK (the trivial-data condition is safe-zone-only) |
| `T *_Borrow` (mutable) → `const T *_Borrow` / `const void *_Borrow` | OK (**implicit only** — compiler inserts `&_Const *`; `const void` target needs trivial T; C-style cast forbidden) | OK (implicit only; `const void` always) |
| `void *_Borrow` → `T *_Borrow` | **Forbidden** — explicit cast required, must be in `_Unsafe` | OK (explicit cast) |
| `T *_Borrow _ArrayElem` → `T *_Borrow` | OK (implicit) | OK |
| `T *_Borrow _ArrayElem` → `void *`/`const void *` `_Borrow [_ArrayElem]` | OK (implicit; trivial T; const targets not by explicit cast) | OK (implicit; always) |
| `T *_Borrow _ArrayElem` → differently-typed `U *_Borrow _ArrayElem` | Forbidden | Forbidden (removed 2026-08; was allowed explicitly) |
| `T *_Borrow` → `T *_Borrow _ArrayElem` | Forbidden | Forbidden |
| `T *_Borrow` → raw `T *` | **Forbidden everywhere** | Forbidden everywhere |
| raw `T *` → `void *` / `const void *` (trivial T) or `const T *` | **OK** (implicit or explicit; since 2026-08) | OK |
| raw `void *` → `T *`, or `const T *` → `T *` | Forbidden (dropping `const` / refining `void` needs `_Unsafe`) | OK (explicit cast) |
| `T *_Owned` → `void *_Owned` | OK (explicit cast) | OK |
| `void *_Owned` → `T *_Owned` | Forbidden in `_Safe`; in `_Unsafe`, allowed but the resulting struct's inner `_Owned` members do NOT own anything | OK (explicit cast, same caveat) |
| `T *_Owned` ↔ `T *_Owned _ArrayElem` (C cast) | Forbidden — these are distinct categories; use `safe_malloc_array`/`__take_array_from_raw` | Forbidden |
| `T *_Owned` → raw `T *` | Forbidden — use `__move_to_raw` | Forbidden — use `__move_to_raw` |
| `T *_Owned _ArrayElem` → raw `T *` | Forbidden — use `__move_array_to_raw` | Forbidden — use `__move_array_to_raw` |
| `fn(A *_Borrow)` → `fn(B *_Borrow)` (fn-ptr cast) | Forbidden in heterogeneous `_Safe`/`_Unsafe` declarations — use trampoline pattern | Forbidden in heterogeneous declarations — use trampoline pattern |

**The void-borrow two-step cast** is the canonical pattern for casting between unrelated struct pointer types inside a `_Safe` function (e.g. vtable trampolines — see `c-to-bsc` §5 "C OO patterns"):

```c
/* Goal: cast public_t *_Borrow → private_t *_Borrow */
private_t *_Borrow _Nonnull this = _Unsafe(
    (private_t *_Borrow _Nonnull)(void *_Borrow _Nonnull)self);
```

- Step 1: `public_t *_Borrow → void *_Borrow` — implicit, allowed in `_Safe`.
- Step 2: `void *_Borrow → private_t *_Borrow` — explicit cast, wrapped in `_Unsafe(expr)`.
- Direct `public_t *_Borrow → private_t *_Borrow` is **forbidden** (different pointed-to types).

### Array decay to borrow pointers
In assignment, argument passing, and return, an array `T[N]` can decay directly to a borrow pointer instead of a raw pointer when the target type is one of `T *_Borrow _ArrayElem`, `T *_Borrow`, `void *_Borrow`, or `void *_Borrow _ArrayElem`. The two `void *` forms require `T` to satisfy `is_trivial_data` **inside a safe zone** (else it's an error). Any other target makes the array decay to raw `T *` as in C. Decaying to a borrow counts as borrowing the first element, so the usual borrow-check rules apply. See `bsc-borrowing` §12.

### Raw pointer params/returns are allowed in signatures
A `_Safe` function **may** have raw pointer params/returns, and may have structs with pointer members or union types as params/returns. The restrictions apply to *operations on* pointers inside the safe zone, not their presence in signatures.

### Initialization rules
- **Pointer types** (raw, `_Owned`, `_Borrow`, function pointers) **must** be initialized (use `nullptr` if needed)
- **Structs/unions containing pointer fields** must be initialized with **complete** initializer lists (no partial init)
- **Basic types** (`int`, `float`, `char`, `_Bool`) and structs/unions **without** pointer fields **may** be left uninitialized or partially initialized

```c
_Safe {
    int a;                            // ok: basic type
    int *p;                           // error: pointer must be initialized
    int *p1 = nullptr;                // ok
    struct HasPtr hp = {nullptr, 0};  // ok: complete init
    struct HasPtr hp2 = {0};          // error: partial init (has pointer field)
}
```

### Increment/decrement (`++`/`--`)
`++` and `--` are **allowed**, but their result type is `void`. You can use them as standalone statements, but you cannot use the expression's value.

```c
_Safe void foo(void) {
    int a = 0;
    a++;                // ok: side-effect only
    int x = a++;        // error: result is void
    for (int i = 0; i < 10; i++) {}  // ok: iteration clause
}
```

### Type conversion rules
- **No narrowing implicit casts** (`long` to `int`, `double` to `float`, `int` to `float`) — explicit cast required
- **Compile-time-known values** are exempt from narrowing restrictions: a compile-time constant, or an integer-typed expression whose value range the compiler can determine, may convert implicitly as long as the target type can represent every value in that range. BSC guarantees the range of bitwise `&`, `|`, `^` is tracked at compile time; tracking of other operators is implementation-defined. It does **not** track a plain integer variable's runtime range — that falls back to the full type range (e.g. `unsigned short = some_uint | 0x10;` is an error even though the value fits)
- **No float-to-integer casts** (even explicit)
- **Int-to-float** conversions are allowed explicitly in safe zones
- **Enum conversions**: implicit enum-to-enum is forbidden; explicit enum-to-enum is allowed only if the target enum contains all values of the source. **Enum-to-integer follows the same sign/width rules as int-to-int** (above): converting to the enum's own underlying type is always fine, but for a **fixed-underlying-type** enum (`enum E : T {…}`) an *implicit* conversion to a different integer type needs matching signedness and not-smaller range (or a compile-time-provable value fit) — a same-width opposite-sign conversion (e.g. `enum E : unsigned` → `int`) needs an explicit cast. Enums **without** a fixed underlying type keep C's loose conversion
- **Comparison/logical operators** (`==`, `!=`, `>=`, `<=`, `>`, `<`, `&&`, `||`, `!`): results are `int` type (0 or 1) and may implicitly convert to other integer types
- **`if`/`while`/`do-while`/`for` conditions**: any arithmetic **or pointer** type is allowed (as in C). Using a value as a condition is **not** counted as an implicit conversion to `_Bool`, so a condition never triggers a narrowing-conversion error

### Union rules
- **No union member access of any kind** in a safe zone — not via `.`, and not via `->` through a raw, `_Owned`, or `_Borrow` pointer — for either read or write. **Taking a borrow of a union member** (`&_Mut u.x` / `&_Const u.x`) is also forbidden.
- What **is** allowed: declaring/defining union variables, and holding raw or safe (`_Owned`/`_Borrow`) pointers *to* a union — you just can't reach through to a member. Member access works inside an `_Unsafe {}` escape.

### Other restrictions
- **`static` locals are allowed** in a safe zone (previously rejected as "mutable globals"). Constraints: the variable **cannot** be `_Owned`, `_Borrow`, or an `_Owned struct` type (compile error), and — like a global — it can only be `&_Const`-borrowed, never `&_Mut`
- **String-literal array init**: a `char` array initialized from a string literal must be at least as long as the literal **including** the trailing `\0` — `char a[3] = "abc";` is an error (needs 4), `char a[4] = "abc";` is ok
- **Array subscript/deref is allowed**: although raw-pointer deref is forbidden, indexing or dereferencing an **array** lvalue (`arr[i]`, `*arr`) is fine — the compiler treats it as a direct array operation, not as deref of the decayed raw pointer
- **No inline assembly**
- **No calling unsafe functions** — must wrap in `_Unsafe {}`
- **Empty params require `void`**: `_Safe void f(void)` — not `_Safe void f()`
- **No variadic params** — unless the function has `__attribute__((format(...)))`:
  ```c
  _Safe int foo(int a, ...);  // error
  __attribute__((format(printf, 1, 2)))
  _Safe int bar(const char *fmt, ...);  // ok (but va_start/va_arg/va_end still forbidden inside the body)
  ```
- **Switch**: `case`/`default` only in first-level block after `switch`; no variable declarations in that first-level block

## 4. Trait and Generic Safety Rules

- `_Trait` functions declared `_Safe` require implementation functions to also be `_Safe`; if trait function is not `_Safe`, implementation can be `_Safe` (compiler warns)
- `_Safe` generic functions: all instantiations are checked for safety
- Member functions can also be `_Safe`/`_Unsafe` modified with same rules as global functions

## 5. Redeclaration & Mixed Mode (_Safe/_Unsafe overloading)

The same function name can have multiple declarations, mixing `_Safe` and
`_Unsafe`, **in any order** (unsafe-first or safe-first both work):

```c
void f1(int *p, int a, int *q);                       // unsafe version first
_Safe void f1(int *_Owned p, int a, int *_Borrow q);  // ok: safe version added

_Safe void f2(int *_Borrow p);  // safe version first
void f2(int *p);                // ok: unsafe version added
```

Declaration-checking rules:

- **Same safety level** → the declarations' types must be *compatible* (see §5.2)
  and the compiler **merges** them into one type.
- **Across safety levels** → the `_Unsafe` declaration's type must satisfy the
  **unsafe-safe refinement relation** toward the `_Safe` declaration's type
  (see §5.1). The two declarations are kept **separate**, not merged.
- The **definition** may be written as either the `_Safe` or the `_Unsafe`
  version, regardless of which declarations exist.
- **Generic functions do NOT support mixed mode** — a generic cannot have both
  `_Safe` and `_Unsafe` declarations/definitions.

### 5.1 The unsafe-safe refinement relation

Guiding idea: the `_Safe` declaration carries the *most precise* qualifiers;
the `_Unsafe` declaration may be a "stripped" view of it. Formally, the
`_Unsafe` type must equal the `_Safe` type after removing BSC safety
qualifiers/attributes. Per pointer position:

- **Sticky safety qualifiers** `_Owned`, `_Borrow`, `_Owned _ArrayElem`,
  `_Borrow _ArrayElem` (each `_ArrayElem` pair is judged as a **whole unit**)
  and the init-analysis attributes `ensure_init` / `ensure_init_if_ret`:
  the `_Unsafe` declaration may **omit** one the `_Safe` declaration has, but
  may not carry one the `_Safe` declaration lacks, and if both carry one they
  must **match exactly** (no `_Owned` ↔ `_Borrow` swap, no `_Owned` →
  `_Owned _ArrayElem` upgrade).
- **Nullability**: an `_Unsafe` `_Nonnull` pointer cannot pair with a `_Safe`
  `_Nullable` one (the safe side must not weaken the contract).
- **Non-sticky qualifiers** (`const`, `volatile`, `restrict`, `_Atomic`) on a
  pointer must be **identical** on both declarations.
- Parameter count and ellipsis use must match; each parameter (after the usual
  array→pointer / function→pointer adjustment) and the return type must
  themselves satisfy the relation.

```c
      void f4(int *p);
_Safe void f4(int *_Owned p);   // ok: safe side adds _Owned
      void f6(int *_Owned p);
_Safe void f6(int *_Borrow p);  // error: _Owned vs _Borrow mismatch
      void f8(struct S *_Borrow p);
_Safe void f8(struct S *_Borrow _ArrayElem p);  // error: cannot upgrade to _ArrayElem
      void f12(int * _Nonnull p);
_Safe void f12(int *_Borrow _Nullable p);       // error: _Nonnull → _Nullable
```

### 5.2 Type compatibility (BSC extensions) & sticky qualifiers

BSC extends C's type-compatibility rules (used for merging declarations,
assignment checking, ternary/pointer comparison operands, cross-TU tag types):

- Function types are compatible only if they have the **same `_Safe`/`_Unsafe`**
  safety — a `_Safe` function type and an `_Unsafe` one are never compatible.
- Type **attributes** (e.g. `ensure_init`) participate in compatibility, not
  just qualifiers.
- Pointer types are compared after **filling in default nullability**: raw
  pointers default `_Nullable`; `_Owned`/`_Borrow` default `_Nonnull`. So
  `int *` ≡ `int * _Nullable`, `int *_Borrow` ≡ `int *_Borrow _Nonnull`, but
  `int *_Owned` ≢ `int *_Owned _Nullable`.
- Qualifier/attribute classification: **sticky** = `_Owned`, `_Borrow`,
  `_ArrayElem`, `_Nullable`, `_Nonnull`, `ensure_init`, `ensure_init_if_ret`
  (cannot be added or dropped in a value assignment `T x = e`); **non-sticky**
  = `const`, `volatile`, `restrict`, `_Atomic` (freely added/dropped at the
  top level on value passing). Simple assignment, ternary operands, pointer
  subtraction/comparison compare pointee types *after stripping non-sticky*
  qualifiers, and every non-sticky qualifier on the source pointee must also
  appear on the destination pointee.
- Function **parameters** are adjusted before comparison: arrays → pointers,
  function types → function pointers, top-level non-sticky qualifiers dropped,
  default nullability filled in. So `void f(int a[10])` ≡ `void f(int *a)` and
  `void f(const int a)` ≡ `void f(int a)`.
- struct/union/enum compatibility follows C11 tag rules (same tag; if both
  complete: same members/order/bit-field widths/alignment/enum values).
  Different or anonymous tags are incompatible even with identical bodies.

### 5.3 Call resolution

- **Safe context**: a call by function name uses **only** the `_Safe`
  declaration(s). If the function has no `_Safe` declaration, the call is an
  error.
- **Unsafe context**: the `_Safe` declaration is tried **first**; if the
  arguments don't match it, the call falls back to the `_Unsafe` declaration;
  if neither matches, error.

```c
      void f1(int *p);
_Safe void f1(int *_Borrow p);
void f2(int *p);   // unsafe-only

_Safe void foo(void) {
    int a = 0;
    int *_Borrow p = &_Mut a;
    f1(p);    // ok: matches the _Safe declaration
    f2(&a);   // error: f2 has no _Safe declaration
}
void bar(int *p1, int *_Owned p2) {
    f1(p1);   // ok: raw arg falls back to the _Unsafe declaration
    f1(p2);   // error: int *_Owned matches neither declaration
}
```

## 6. Function Pointer Rules

Assigning a function **name** (or `&name`) to a function pointer:

- A **`_Safe` function pointer** requires the function to have a `_Safe`
  declaration whose type is *compatible* with the pointee type.
- An **`_Unsafe` function pointer** requires the function to have an
  `_Unsafe` declaration whose type is compatible. A safe-only function cannot
  be assigned to an unsafe function pointer — add an `_Unsafe` redeclaration
  if you need that.

(Assigning any other expression follows the normal assignment-compatibility
rules of §5.2.)

```c
      void f1(int *p);           // _Unsafe declaration
_Safe void f1(int *_Borrow p);   // _Safe declaration

typedef _Safe void (*SafeFP)(int *_Borrow);
SafeFP sp = f1;                  // ok: compatible _Safe declaration exists

typedef void (*UnsafeFP)(int *);
UnsafeFP up = f1;                // ok: compatible _Unsafe declaration exists

typedef _Safe void (*SafeFP2)(int *_Owned);
SafeFP2 sp2 = f1;                // error: _Safe declaration is _Borrow, not _Owned
```

## 7. Complete Example

```c
#include <stdio.h>
#include "bishengc_safety.hbs"

_Safe int add(int a, int b) { return a + b; }

_Safe int readBorrow(const int *_Borrow ref) {
    return *ref;  // ok: _Borrow dereference is safe
}

void mixedFunction(void) {
    int *raw = (int *)malloc(sizeof(int));
    *raw = 100;
    _Safe {
        int x = 42;
        int y;  // ok: basic type, no init needed
        const int *_Borrow ref = &_Const x;
        y = readBorrow(ref);
        _Unsafe {
            printf("from safe zone: %d\n", y);
            free(raw);
        }
    }
}

_Safe int main(void) {
    int sum = add(10, 20);
    const int *_Borrow r = &_Const sum;
    _Unsafe { printf("sum = %d\n", *r); }
    return 0;
}
```

> For initialization analysis (field-level tracking), see `bsc-initialization` Skill
> For borrowing (required in safe zones), see `bsc-borrowing` Skill
> For ownership in safe contexts, see `bsc-ownership` Skill
> For nullability checking, see `bsc-nullability` Skill
> For safe zone errors (BSC-E03xx), see `bsc-errors` Skill
> For common safe zone mistakes, see `bsc-common-mistakes` Skill
