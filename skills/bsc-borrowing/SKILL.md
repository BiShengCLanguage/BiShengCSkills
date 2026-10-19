---
name: bsc-borrowing
description: "BiSheng C borrowing. When you need to understand _Borrow pointers, &_Const (immutable borrow), &_Mut (mutable borrow), borrow lifetime rules, freezing semantics, NLL (Non-Lexical Lifetimes), borrow type conversions, dereference/member access semantics, or borrow function signatures, use this Skill."
---

# BiSheng C Borrowing Skill

## Pick `_Borrow`, Not `_Owned`, By Default for Pointer Parameters

A function that **reads or mutates** a value through a pointer but does **not
take ownership** must use `_Borrow`, never `_Owned`.

- The function frees the pointer, transfers it onward, or stores it long-term → `T *_Owned`.
- The function only reads through the pointer → `const T *_Borrow`.
- The function mutates *through* the pointer but does not free it → `T *_Borrow`.
- The function does pointer arithmetic / iteration → raw `T *`.

`_Owned` parameters consume the caller's variable. Most C functions don't do
that. Defaulting to `_Owned` everywhere makes every call site a one-shot move
and forces ugly re-allocation patterns at the call sites — that's wrong.

For a translation context, see `/c-to-bsc` Step 2.5.

## CRITICAL: `_Borrow` Syntax

**`_Borrow` goes AFTER the `*`, not before the type.** It is a pointer qualifier.

```c
// CORRECT
const int *_Borrow r = &_Const x;
int *_Borrow mr = &_Mut x;

// WRONG (does not compile)
_Borrow int* r = &_Const x;
```

## 1. Overview

Temporary, non-owning references. The compiler enforces borrow rules at compile time — no dangling references, no aliased mutation.

## 2. Creating Borrows

```c
int x = 42;
const int *_Borrow cr = &_Const x;   // immutable borrow — read only
int *_Borrow mr = &_Mut x;           // mutable borrow — read/write
```

From `_Owned` pointer: `&_Const *owned_ptr` or `&_Mut *owned_ptr`.

`&_Mut *p` / `&_Const *p` **do not evaluate `*p`** — they just rebind to the
object `p` points at. So `p` being null does **not** cause a dereference, and if
`p` is an `_Owned` pointer its ownership is **not** moved. (`p` may be a raw,
`_Owned`, or `_Borrow` pointer — but **not a function pointer**: `&_Mut *fp` is
`error: '&_Mut' cannot be applied to a function pointer`.)

The resulting borrow **inherits `p`'s nullability**: its `_Nullable`/`_Nonnull`
attribute and its tracked null-state match `p`'s. Borrowing a maybe-null
`_Owned _Nullable` yields a `_Nullable` borrow — assigning it to a
`_Borrow _Nonnull` is `error: cannot assign possibly-null status pointer 'p'
to a '_Nonnull' pointer`; store it in a `T *_Borrow _Nullable` instead.

Parenthesized and `_Safe`/`_Unsafe`-wrapped spellings are the same operation:
`&_Mut (*p)`, `&_Mut *(p)`, `&_Mut ((*(p)))` and `&_Mut _Unsafe(*p)` are all
equivalent to `&_Mut *p` — none evaluates `*p`, and all inherit `p`'s
nullability (verified 2026-09).

`&_Mut p` / `&_Const p` where `p` is itself a borrow lvalue is allowed since
2026-09 and yields a **multi-level borrow** (`int *_Borrow *_Borrow`) — see §13.

## 3. Semantics

| Type | Access | Aliasing |
|------|--------|----------|
| `const T *_Borrow` | Read only | Multiple allowed simultaneously |
| `T *_Borrow` | Read + Write | Exactly one at a time |

Mutable borrows implicitly convert to immutable: `T *_Borrow` -> `const T *_Borrow` (an implicit reborrow, `&_Const *`). This works in declarations, assignments, function args, and returns.

## 4. Non-Lexical Lifetimes (NLL)

Borrow lifetimes use **NLL**: a borrow is active from its creation (or re-assignment) to its **last use**, NOT to the end of the lexical scope. NLL can be segmented — if a borrow variable is reassigned, it creates disjoint active ranges.

```c
void use(int *_Borrow p) {}

void foo() {
    int local1 = 1, local2 = 2;
    int *_Borrow p = &_Mut local1;  // NLL segment 1 starts
    use(p);                          // NLL segment 1 ends (last use)
    // local1 is unfrozen here — p's borrow has ended
    local1 = 10;                     // OK: p is no longer active
    p = &_Mut local2;                // NLL segment 2 starts (and ends — no further use)
}
```

Uses that extend NLL: function calls `use(p)`, `return p`, dereference `*p`, member access `p->field`, assignment `q = p`, re-borrow `&_Mut *p` / `&_Const *p`, borrowing the borrow itself `&_Mut p` / `&_Const p`, and type conversions of `p`. For a `_Borrow _ArrayElem` pointer, subscript `p[i]`, pointer arithmetic (`p + n`, `p += n`, `++p`, …), and pointer subtraction `p - q` are uses too.

**NLL is extended by an outer borrow** (since 2026-09): if a borrow lvalue `e`
is itself borrowed (`e1 = &_Mut e` / `&_Const e`), `e`'s NLL lasts until the
end of `e1`'s NLL, even if `e` is never used again directly. So the objects `e`
borrows stay frozen for as long as `e1` is live:

```c
void usepp(int *_Borrow *_Borrow p) {}
void f(void) {
    int a = 1;
    int *_Borrow p = &_Mut a;
    int *_Borrow *_Borrow q = &_Mut p;
    a = 5;      // error: cannot assign to 'a' because it is borrowed (p kept alive by q)
    usepp(q);   // last use of q — p's NLL ends here too
}
```

Terminology: the manual now says *borrow lvalue expression* (借用左值表达式)
rather than *borrow variable*, because `*q`, `s.p` and the like are borrows too.

## 5. Rules

- **`_Borrow` goes after the `*`**: write `int *_Borrow`, NOT `_Borrow int*`
- While **immutable borrow** active: original is read-only, no mutable borrows allowed. If the borrowed expression is itself a `_Borrow` pointer, `*e` becomes read-only too; if it is a struct, all its members; if an array, all elements
- While **mutable borrow** active: original is **frozen** — no reads, writes, moves, or borrows. Same propagation: `&_Mut p` on a borrow `p` also freezes `*p` (`*p = 3` is `error: cannot assign to '*p' because it is borrowed`), a struct freezes all members, an array all elements
- **Struct field borrows**: `&_Mut e.field` freezes only **that field** (blocks whole-struct modification); other fields remain accessible. `&_Const e.field` puts the field into read-only state
- Borrow lifetime <= borrowed value's lifetime (compiler enforced)
- Borrow of a borrow (`int *_Borrow *_Borrow`) is **allowed since 2026-09** — see §13 for the extra rules that come with multi-level borrows
- Borrow variables must be initialized at declaration
- Cannot be global **or `static`** variables, nor union members
- `_Owned` and `_Borrow` cannot coexist on same pointer: `int *_Owned _Borrow` is illegal
- No indexing (`p[i]`) and no pointer arithmetic (`p + n`, `p++`) on **plain** borrow pointers. For an array-element borrow, use `_Borrow _ArrayElem` (see §12) — that variant supports `[]`, `+`, `-`, `+=`, `-=`, `++`, `--`
- A `_Borrow` pointer type **may** be a generic type argument (`struct Box<int *_Borrow>`, `id<int *_Borrow>(p)`; the old ban was dropped from the manual in 2026-09 and the compiler accepts it)
- No `_Trait` impl for borrow types; no member functions for borrow types
- A struct that contains `_Borrow` members **may** be borrowed (since 2026-09; used to be an error)
- Globals **and `static` variables**: in safe zones, only immutable borrows (`&_Const`) allowed; no mutable borrows (we can't track reads/writes of global/static storage across function signatures)
- String literals: `&_Mut "hello"` is forbidden; `&_Mut * "hello"` is forbidden. A string literal's lifetime is the **whole program** (since 2026-09; was block-scoped), so a `const char *_Borrow` assigned from a literal inside an inner block is still valid after the block — unlike a compound literal `(int){5}`, which still dies at the end of its block (`'_borrowck_tmp_N' does not live long enough`)

### Reassignment rules
- Reassignment of a borrow variable requires the same type and the new source must have a lifetime >= the borrow variable's remaining lifetime

## 6. Dereference and Member Access

### Dereference (`*p`)
| Operation | Immutable borrow | Mutable borrow (T is Copy) | Mutable borrow (T is Move) |
|-----------|-----------------|---------------------------|---------------------------|
| Read `*p` | OK | OK | OK |
| Assign to `*p` | Error | OK | Error (cannot move-assign) |

### Member access (`p->field`)
- Immutable borrow: can read fields, cannot modify
- Mutable borrow: can read and modify fields (for Copy types)
- Immutable borrow cannot call mutable methods (`T *_Borrow this` methods)

## 7. Type Conversions

- **Trait upcasting**: explicit cast required; no implicit downcasting from trait to concrete
- **`T *_Borrow` → `void *_Borrow`**: **implicit or explicit** (explicit allowed since 2026-08) when `T` is a trivial data type in a safe zone (no pointer fields, not an `_Owned struct`; outside safe zones always allowed); otherwise the conversion is **forbidden**, even with an explicit cast
  ```c
  struct S { int *ptr; };
  int a = 0; struct S s = {.ptr = nullptr};
  _Safe {
      int *_Borrow p1 = &_Mut a;
      void *_Borrow p2 = p1;                       // ok: int is trivial
      void *_Borrow p2e = (void *_Borrow)p1;       // ok: explicit form
      struct S *_Borrow p3 = &_Mut s;
      void *_Borrow p4 = (void *_Borrow)p3;        // error: S has pointer field
  }
  ```
- **`void *_Borrow` → `T *_Borrow`** or **`T *_Borrow _ArrayElem`**: implicit conversion **forbidden**; explicit cast must be in `_Unsafe` (in a safe zone: `conversion from type 'void *_Borrow' to 'int *_Borrow _ArrayElem' is forbidden in the safe zone`). This is the only way any pointer type other than `_Borrow _ArrayElem` itself becomes a `_Borrow _ArrayElem` — plain `T *_Borrow` never does
- **Between `_Borrow` and raw pointer**: forbidden in `_Safe` zones; outside `_Safe`, casts go through the raw `T *` intermediate, never directly
- **Between `_Owned` and `_Borrow`**: C-style casts in either direction are **forbidden**
- **Between mutable and immutable borrows**: explicit cast is forbidden. Mutable→immutable is an implicit reborrow (`&_Const *`); the reverse is never allowed. The implicit conversion also targets `const void *_Borrow` directly (since 2026-08): `T *_Borrow` → `const void *_Borrow` in one step, combining both rules' conditions (safe zone requires `T` `is_trivial_data`). The explicit C-style spelling of a mut→const conversion stays forbidden — including `(const void *_Borrow)p` on a mutable `p`
- **`T *_Borrow _ArrayElem` → `T *_Borrow`**: allowed as an implicit conversion (equivalent to "re-borrow at the current element, dropping array-iteration semantics"). The reverse `T *_Borrow` → `T *_Borrow _ArrayElem` is forbidden
- **Implicit `_Bool` conversion**: `_Borrow _Nullable` pointers can be used in conditions

## 8. Additional Rules

- Borrow pointers can be used in `if`/`while`/`do-while`/`for`/ternary conditions, but **NOT** in `switch`
- Forbidden operators on **plain** borrow pointers: `-`, `~`, `[]`, `++`, `--`, `*`(arithmetic), `/`, `%`, `&`(bitwise), `|`, `<<`, `>>`, binary `+`, binary `-`. `_Borrow _ArrayElem` re-enables `[]`, binary `+`/`-`, `+=`/`-=`, `++`/`--` (see §12). The rest stay forbidden
- Unary `&` (raw address), `&_Const`, `&_Mut` (multi-level borrow, §13), `!`, and binary `&&`/`||` are allowed on borrow pointers
- Comparison (`==`, `!=`, `<`, `<=`, `>`, `>=`) is allowed between same-typed borrows. Top-level `const`/`volatile`/`restrict` on the pointee are ignored when comparing — `int *_Borrow` and `const int *_Borrow` are comparable
- `sizeof(T *_Borrow) == sizeof(T *)` and the same for `_Alignof`. `_Borrow _ArrayElem` has the same size/alignment as `T *`
- String literals auto-borrow to `const char *_Borrow` when passed to a `const char *_Borrow` parameter (compiler inserts `&_Const *`)
- **Static members of an `_Owned struct`** (`static int st;`, `-fbsc-experimental`) are one place regardless of the spelling: `&_Mut a->st`, `&_Mut b->st` and `&_Mut W::st` all borrow the same `st`, so holding two of them is `cannot borrow 'st' as mutable more than once at a time` (since 2026-10; previously crashed). Enumerators (`w->K`) and method designators (`w->f`) reached through a member expression have no place and are fine
- **Assignment evaluation order** (since 2026-10): the RHS is evaluated, and its temporary borrows end, *before* the destination is borrowed — `(&_Mut s)->x += (&_Mut s)->x;` and `p->x = p->x + 1` with `p` spelled `(&_Mut s)` on both sides compile. A borrow that is **still live after** the assignment conflicts as usual: `struct S *_Borrow p = &_Mut s; (&_Mut s)->x = p->x; use(p);` is `cannot borrow 's' as mutable more than once at a time`

## 9. Function Signatures

```c
// Read-only access
_Safe int len(const Vec<int> *_Borrow this) {
    return this->len;
}

// Mutable access
_Safe void push(Vec<int> *_Borrow this, int value) { ... }

// Return borrow — lifetime tied to input borrow
_Safe int *_Borrow first(Vec<int> *_Borrow this) { ... }
```

- If return is `_Borrow` and one param is `_Borrow`: return lifetime = param lifetime
- If multiple `_Borrow` params: return lifetime = union of all param lifetimes
- If no `_Borrow` params but return is `_Borrow`: **compile error** — borrow return requires at least one borrow parameter
- The return type **cannot be a multi-level borrow**: `int *_Borrow *_Borrow f(int *_Borrow *_Borrow p);` is `error: function return type cannot contain multiple borrow regions`
- If **any** borrow parameter is multi-level (`T *_Borrow *_Borrow pa1`), no assignment is allowed between `pa1`/`*pa1` and another borrow parameter `pa2`/`*pa2` (or locals aliasing them): `p = q;`, `*p = *q;` and `*p = q;` are each `error: lifetime may not live long enough`. Single-level parameters may still be assigned to each other

## 10. Design Patterns

These idioms come up repeatedly when the borrow checker rejects "obvious" C-style code.

### 10.1 Iterative traversal → convert to recursion

**Problem:** You want to walk a linked structure via a while-loop, reassigning a cursor
at each step. The borrow checker forbids this because step N+1's borrow is derived from
step N's borrow, and reassignment invalidates the chain.

```c
// WRONG — cannot reassign `current` while borrows live through it
_Safe T* _Borrow walk(Root* _Borrow root, const Path* _Borrow p) {
    T* _Borrow current = root;
    for (size_t i = 0; i < p->length(); i++) {
        current = current->child(i);   // reassignment conflicts with derived borrow
    }
    return current;
}
```

**Fix:** convert to tail-recursion. Each recursive call has its own fresh stack frame,
so the borrow chain stays linear.

```c
_Safe static T* _Borrow walk_rec(T* _Borrow current, const Path* _Borrow p, size_t i) {
    if (i >= p->length()) { return current; }
    return walk_rec(current->child(i), p, i + 1);
}
_Safe T* _Borrow walk(Root* _Borrow root, const Path* _Borrow p) {
    return walk_rec(root, p, 0);
}
```

The compiler typically optimizes tail-recursion back into a loop at `-O1` and above, so
there's no runtime cost. This pattern was necessary for BSC's `path_get_value` in parson.

### 10.2 Chain calls, don't name intermediate borrows

**Problem:** Extracting an intermediate value into a named variable can extend its
borrow past where you want.

```c
// Potentially awkward — `obj` borrows from `val` through the whole block
JSON_Object* _Borrow obj = val.get_object();
obj->set_string(name, value);
// ... lots of code ...
// any other borrow of `val` conflicts with `obj`
```

**Fix:** when a borrow is used in only one call, chain it:

```c
val.get_object()->set_string(name, value);
// no named borrow — no lifetime extension
```

Name a borrow only when you use it multiple times; otherwise let it be a transient.

### 10.3 Scope the borrow tightly

If you must name a borrow but don't need it for the whole function, wrap it in a
block so its lifetime ends explicitly:

```c
{
    JSON_Object* _Borrow obj = val.get_object();
    obj->set_string(name, value);
}   // <-- `obj` released here
val.validate(&_Mut schema);   // now free to mut-borrow `val` again
```

### 10.4 Extract the work, not the borrow

**Problem:** you need data from the borrow but also need the borrowee freely afterwards.

```c
// WRONG — `key` transitively extends `parent`'s borrow
const String* _Borrow key = parent->get_name(0);
parent->set_value(key, ...);   // mut-borrow conflicts with key
```

**Fix:** clone the data you need, drop the borrow, then do the mutation.

```c
String key_owned;
{
    const String* _Borrow key = parent->get_name(0);
    key_owned = clone_string(key);
}
parent->set_value(&_Const key_owned, ...);   // parent is free again
```

## 11. Complete Example

```c
#include <stdio.h>

void printValue(const int *_Borrow ref) {
    printf("value = %d\n", *ref);
}

void doubleValue(int *_Borrow ref) {
    *ref = *ref * 2;
}

const int *_Borrow getFirst(const int *_Borrow arr, int len) {
    return arr;
}

int main() {
    int x = 21;

    // Immutable borrow
    const int *_Borrow cr = &_Const x;
    printValue(cr);
    printValue(&_Const x);   // inline borrow

    // Mutable borrow
    int *_Borrow mr = &_Mut x;
    doubleValue(mr);
    // NLL: mr's lifetime ended at last use (doubleValue call)
    printf("x = %d\n", x);  // OK: x is no longer frozen

    // Multiple immutable borrows are OK
    const int *_Borrow r1 = &_Const x;
    const int *_Borrow r2 = &_Const x;
    printf("r1=%d, r2=%d\n", *r1, *r2);

    // Struct field borrows — only the borrowed field is frozen
    struct Point { int x; int y; };
    struct Point p = {.x = 10, .y = 20};
    int *_Borrow px = &_Mut p.x;  // only p.x is frozen
    p.y = 30;                      // OK: p.y is a different field
    *px = 50;
    // px NLL ends here (last use above)

    // Mutable-to-immutable implicit conversion
    int val = 5;
    int *_Borrow mp = &_Mut val;
    const int *_Borrow ip = mp;  // OK: implicit conversion

    // String literal auto-borrow
    void print_str(const char *_Borrow s);
    print_str("hello");  // compiler auto-inserts &_Const *

    return 0;
}
```

## 12. `_Borrow _ArrayElem`: Borrowing Into Arrays

Taking the address of an array element with `&_Mut arr[i]` or `&_Const arr[i]`
yields a `_Borrow _ArrayElem` pointer. This is a borrow that **remembers it
points into an array**, so subscript and arithmetic are allowed on it (unlike
plain `_Borrow`).

```c
_Safe int foo(void) {
    int arr[4] = {1, 2, 3, 4};
    int *_Borrow _ArrayElem p = &_Mut arr[0];
    p = p + 1;            // ok: _Borrow _ArrayElem supports +
    p += 1;               // ok: +=
    ++p;                  // ok: ++
    int x = p[0];         // ok: subscript

    int *_Borrow q = p;   // ok: implicit downgrade to plain borrow
    // q + 1;             // error: plain borrow forbids arithmetic
    // q[0];              // error: plain borrow forbids subscript
    return x;
}
```

Rules specific to `_Borrow _ArrayElem`:

- Allowed operators: `[]`, binary `+`, `-`, `+=`, `-=`, `++`, `--`. All other
  plain-`_Borrow` restrictions still apply (no `*` arithmetic, no bitwise, etc.).
- **Arithmetic produces a reborrow.** `p2 = p1 + 5` is treated as `&_Mut p1[5]`:
  `p2` borrows the same array, so `p1` is **frozen** until `p2`'s lifetime ends.
- **Pointer subtraction** between two same-type `_Borrow _ArrayElem` pointers is
  allowed and yields the element distance: `int n = p2 - p1;`. (Comparison
  carries over from plain `_Borrow` — see §8 — so `while (p <= end)` works.)
- Multiple `[]`/`*` accesses through the **same** `_Borrow _ArrayElem` in one
  statement (e.g. `p[0] = p[1] + p[2];`) are all counted as uses of `p` itself —
  no temporary borrow is created, so this does not trip the borrow checker.
- **Implicit downgrade** `T *_Borrow _ArrayElem` → `T *_Borrow` is allowed
  (equivalent to "take a fresh plain borrow at the current element"). The
  reverse explicit cast is **forbidden**.
- **Void-target implicit conversions** (since 2026-08): `T *_Borrow _ArrayElem`
  implicitly converts to `void *_Borrow _ArrayElem`, `const void *_Borrow
  _ArrayElem`, `void *_Borrow`, and `const void *_Borrow` (safe zone requires
  `T` `is_trivial_data` — `note: source pointee type 'struct S' is not a
  trivial data type` otherwise; outside always allowed). The const targets are
  implicit reborrows: a mutable `T *_Borrow _ArrayElem` also reborrows to
  `const T *_Borrow _ArrayElem` and `const T *_Borrow`. Explicitly
  C-style-casting to the const forms is forbidden. The **only** other
  pointee-changing conversion is `void *_Borrow` → `T *_Borrow _ArrayElem` by
  explicit cast in `_Unsafe` (§7); the old rule that `_Unsafe` code could cast
  between arbitrary `_ArrayElem` pointee types was removed in 2026-08.
- **Borrowing an element of a nullable pointer** (since 2026-09): for
  `&_Mut a[i]` / `&_Const a[i]` where `a` is a pointer, index `0` (a constant)
  is allowed on a maybe-null `a` and the result inherits `a`'s nullability;
  any other index needs `a` definitely non-null
  (`error: cannot dereference possibly-null status pointer 'p1'`). When `a` is
  an array the result is always `_Nonnull`.
  ```c
  _Safe void foo(int *_Owned _ArrayElem _Nullable p1) {
      int *_Borrow _ArrayElem _Nullable p2 = &_Mut p1[0]; // ok
      int *_Borrow _ArrayElem _Nullable p3 = &_Mut p1[1]; // error: p1 may be null
      if (p1) { int *_Borrow _ArrayElem p4 = &_Mut p1[1]; }  // ok
  }
  ```
- The pointee `T` **may be or contain a `_Borrow` pointer** since 2026-09
  (`int *_Borrow *_Borrow _ArrayElem` is legal; the old pointee-type
  restriction was dropped along with the multi-level-borrow ban).
- **No bounds checking.** `_ArrayElem` only records "points into an array",
  not the length: `p[5]` on a borrow of `int arr[2]` compiles, even in a
  `_Safe` zone. Safe zones give **no spatial memory-safety guarantee** for
  `_ArrayElem` arithmetic/indexing — staying in bounds is on you.
- For mixed `_Safe`/`_Unsafe` declarations, `_Borrow _ArrayElem` is a single
  qualifier unit — a `_Safe` redeclaration may add `_Borrow _ArrayElem` to a
  bare-pointer `_Unsafe` parameter, but cannot swap between `_Borrow` and
  `_Borrow _ArrayElem` once one is declared.
- `sizeof(T *_Borrow _ArrayElem) == sizeof(T *)`.

### 12.1 Array decay to borrow pointers

Besides `&_Mut arr[i]`, a `_Borrow _ArrayElem` (or plain `_Borrow`) can also be
produced by **array decay**. In assignment, argument passing, and return, an
array with element type `T` decays to whichever of these the target type asks
for, instead of decaying to a raw pointer:

- `T *_Borrow _ArrayElem` / `const T *_Borrow _ArrayElem`
- `T *_Borrow` / `const T *_Borrow`
- `void *_Borrow` / `const void *_Borrow` — in a safe zone requires `T` to be `is_trivial_data`
- `void *_Borrow _ArrayElem` / `const void *_Borrow _ArrayElem` — same `is_trivial_data` requirement

Any other target type makes the array decay to raw `T *`, exactly as in C.
Decaying to a borrow is treated as `&_Mut arr[0]` / `&_Const arr[0]`, so normal
borrow-check rules apply.

```c
void take_elem(int *_Borrow _ArrayElem p);
void take_borrow(int *_Borrow p);

_Safe void foo(void) {
    int arr[4] = {1, 2, 3, 4};
    take_elem(arr);              // ok: decays to int *_Borrow _ArrayElem
    take_borrow(arr);           // ok: decays to int *_Borrow
    void *_Borrow vp = arr;     // ok: int is is_trivial_data
}
```

Except for the operators above and these conversion rules, **everything else
that applies to plain `_Borrow` (lifetime, freezing, NLL, nullability,
type-compatibility, multi-level rules, etc.) applies identically to
`_Borrow _ArrayElem`**. Most of the time you only see this type implicitly via
`&_Mut arr[i]` and immediately bind it to a plain `_Borrow`; name it explicitly
only when you need to subscript or step.

### 12.2 Array parameters become `_Borrow _ArrayElem` when elements own or borrow

C adjusts an array parameter `T a[N]` to a raw pointer `T *a`. BSC keeps that
**unless `T` is, or is a struct containing, an `_Owned` or `_Borrow` pointer** —
then the parameter is adjusted to `T *_Borrow _ArrayElem a` (since 2026-09):

```c
void f1(int a[10]);          // int *a                              (as in C)
void f2(int *_Owned a[10]);  // int *_Owned *_Borrow _ArrayElem a
struct S { int *_Owned ptr; };
void f3(struct S a[20]);     // struct S *_Borrow _ArrayElem a
```

Consequences (all verified 2026-09):

- The redeclarations `void f2(int *_Owned a[10]);` and
  `void f2(int *_Owned *_Borrow _ArrayElem a);` are compatible.
- Inside `f2`, the elements are **borrowed**: reading `*a[0]` is fine, but any
  ownership transfer out of `a[i]` (`safe_free((void *_Owned)a[0])`, moving it
  to a local, …) is `error: cannot take ownership of a borrowed value` with
  `note: array parameter 'a' is adjusted to a '_Borrow _ArrayElem' pointer;
  its elements are borrowed and cannot be moved out`.
- At the call site, passing an `int *_Owned arr[2]` decays to the borrow
  (§12.1) — the caller keeps ownership and must still free the elements.

If the callee must consume the elements, take a `_Borrow` to the array and
`safe_swap` them out, or pass a `T *_Owned _ArrayElem` heap array instead.

## 13. Multi-Level Borrows (since 2026-09)

Borrowing a borrow — `int *_Borrow *_Borrow` — is now legal, as is borrowing a
struct that has `_Borrow` members. The types follow from the operator:
`&_Mut p` on `int *_Borrow p` is `int *_Borrow *_Borrow`; `&_Const p` is
`int *_Borrow const *_Borrow` (the `const` lands on the *outer* pointee).

```c
void baz(void) {
    int a = 1, b = 2;
    int *_Borrow p = &_Mut a;           // p borrows a
    int *_Borrow *_Borrow q = &_Mut p;  // q borrows p (p and *p are frozen while q lives)
    *q = &_Mut b;                       // p and *q now borrow {a, b}
    b = 7;                              // error: cannot assign to 'b' because it is borrowed
    use(*q); use(p);
}
```

Rules on top of the usual ones (all verified against the 2026-09 compiler):

- **Borrowed-object sets merge through assignment.** Assigning `*q = r`
  (where `q` borrows `p`, so `p` and `*q` alias) adds `r`'s borrowed objects to
  `p`'s — `b` above is frozen through `p` afterwards.
- **Freezing propagates one level down.** `&_Mut p` freezes `p` *and* `*p`;
  `&_Const p` makes `*p` read-only (`*p = 3` → `cannot assign to '*p' because
  it is borrowed`; reading `*p` is fine). Structs freeze all members, arrays
  all elements.
- **NLL extension.** `p`'s NLL runs at least until the last use of any borrow
  of `p` (§4), so the objects `p` borrows stay frozen that long.
- **Exclusivity applies to the borrow itself**: two `&_Mut p` are `cannot
  borrow 'p' as mutable more than once at a time`; `&_Mut p` then `&_Const p`
  is `cannot borrow 'p' as immutable because it is also borrowed as mutable`.
- **Functions**: the return type cannot be multi-level, and with any
  multi-level borrow parameter the parameters (and their derefs) cannot be
  assigned to each other (§9).
- `_Borrow _ArrayElem` may point at borrows (`int *_Borrow *_Borrow _ArrayElem`), §12.
- **Struct field borrowing a sibling field** (`s.p = &_Mut s.m`) compiles, but
  a struct-member borrow lives as long as the struct (§3.2.6 of the manual), so
  `s.m` stays frozen until `s` goes out of scope — `s.m = 2` after the last use
  of `s.p` is still `cannot assign to 's.m' because it is borrowed`. Not a
  useful pattern; keep back-references raw (see `c-to-bsc`).
- **Enforced since 2026-09-23** (BOR-022): anything reached *through* an
  immutable borrow is read-only, even if the inner pointer is itself a mutable
  borrow. With `int *_Borrow p = &_Mut x; int *_Borrow const *_Borrow q =
  &_Const p;`:
  - `**q = 2` / `(**q)++` → `error: expression is not assignable because it is behind an immutable borrow`
  - `&_Mut **q` → `error: expression cannot be mutably borrowed because it is behind an immutable borrow`
  - `int *_Borrow m = *q;` → `error: expression cannot be mutably reborrowed because it is behind an immutable borrow`
  Same through a struct: `const struct W *_Borrow cw = &_Const w; *cw->p = 3`
  errors even though `w.p` is `int *_Borrow`. Reads (`int y = **q`) and
  `&_Const **q` are fine. The propagation stops at a **raw pointer** boundary:
  `*cw->raw = 7` with `int *raw` compiles. Applies in every zone (sema check,
  not the borrow checker).

> For ownership (owning pointers), see `bsc-ownership` Skill
> For safe zones that require borrows, see `bsc-safe-zone` Skill
> For nullability with borrows, see `bsc-nullability` Skill
> For borrow errors (BSC-E02xx), see `bsc-errors` Skill
