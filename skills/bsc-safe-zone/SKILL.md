---
name: bsc-safe-zone
description: "BiSheng C safe zones. When you need to understand _Safe functions, _Safe blocks, _Unsafe escape blocks, safe zone restrictions (initialization, pointers, type casts, enum/float conversions, ++/-- semantics), trait/generic safety, member function safety, or mixed safe/unsafe patterns, use this Skill."
---

# BiSheng C Safe Zones Skill

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
- **No casts between pointers of different pointed-to types**
- **`nullptr` required** — `NULL` is forbidden in safe zones; use `nullptr` to initialize or compare pointers

#### Pointer conversion matrix

| Conversion | In `_Safe` | In `_Unsafe` |
|---|---|---|
| `T *_Borrow` → `void *_Borrow` | **OK** (implicit) | OK |
| `void *_Borrow` → `T *_Borrow` | **Forbidden** — explicit cast required, must be in `_Unsafe` | OK (explicit cast) |
| `T *_Borrow` → raw `T *` | **Forbidden everywhere** | Forbidden everywhere |
| `T *_Owned` → `void *_Owned` | OK (explicit cast) | OK |
| `T *_Owned` → raw `T *` | Forbidden — use `__move_to_raw` | Forbidden — use `__move_to_raw` |
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
- **Compile-time constants** that fit the target type are exempt from narrowing restrictions
- **No float-to-integer casts** (even explicit)
- **Int-to-float** conversions are allowed explicitly in safe zones
- **Enum conversions**: implicit enum-to-enum is forbidden; explicit is allowed only if target enum contains all values of source. Implicit enum-to-underlying-integer is allowed
- **Comparison/logical operators** (`==`, `!=`, `>=`, `<=`, `>`, `<`, `&&`, `||`, `!`): results are `int` type (0 or 1) and may implicitly convert to other integer types
- **if/while conditions**: any arithmetic type allowed (follows C rules)

### Union rules
- **No union member access** (`.` read or write) — but unions can be declared, initialized, and passed as arguments

### Other restrictions
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

## 5. Mixed-Mode Declarations (_Safe/_Unsafe overloading)

The same function can have both `_Safe` and `_Unsafe` declarations:

```c
_Unsafe int* foo(int* p);              // unsafe version
_Safe int* _Owned foo(int* _Owned p);  // safe version: adds _Owned
```

- `_Safe` declaration may **add** `_Owned`/`_Borrow` to raw pointer params/returns
- Must **not remove** qualifiers present in the `_Unsafe` declaration, nor swap `_Owned` for `_Borrow`
- In safe context, only `_Safe` overload is callable. In unsafe context, `_Safe` version preferred when types match.
- **Generic functions do NOT support mixed mode**
- If a function has multiple declarations of the same safety level, they must be consistent

## 6. Function Pointer Rules

- `_Safe` function pointers can only be assigned from functions that have a `_Safe` declaration
- `_Unsafe` function pointers can be assigned from either `_Safe` or `_Unsafe` functions (if types are compatible)

```c
_Safe void safe_fn(void);
_Unsafe void unsafe_fn(void);

_Safe void (*sp)(void) = nullptr;
sp = safe_fn;    // ok
sp = unsafe_fn;  // error: no _Safe declaration available
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
