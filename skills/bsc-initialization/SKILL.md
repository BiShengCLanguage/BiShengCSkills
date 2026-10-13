---
name: bsc-initialization
description: "BiSheng C initialization analysis. When you need to understand uninitialized variable detection, field-level init tracking, __attribute__((ensure_init)), __attribute__((ensure_init_if_ret)), __assume_initialized, array initialization rules, or -uninit-check compiler option, use this Skill."
---

# BiSheng C Initialization Analysis Skill

## 1. Overview

BSC performs compile-time data-flow analysis to ensure variables are initialized before use. Analysis tracks initialization at the **struct field level**. By default active in `_Safe` zones; configurable via `-uninit-check`.

## 2. Rules

### Rule 1: All locals must be initialized before use

```c
_Safe void example(void) {
    int x;
    int y = x;  // error: use of uninitialized value: 'x'
}
```

### Rule 2: Field-level tracking for structs

Partial field initialization is detected. When all fields are initialized, the struct auto-promotes to fully initialized.

```c
struct Pair { int a; int b; };

_Safe void partial(void) {
    struct Pair p;
    p.a = 1;
    struct Pair q = p;  // error: p.b uninitialized
}

_Safe void full(void) {
    struct Pair p;
    p.a = 1;
    p.b = 2;           // all fields done → p auto-promotes
    struct Pair q = p;  // ok
}
```

**Empty structs are vacuously initialized.** A struct with no initializable
storage — no fields at all, or recursively only fields of such empty structs —
is treated as already initialized: a local of such a type can be read whole
without any assignment, and such a member never blocks the enclosing struct's
auto-promotion. Unnamed bit-fields (`unsigned : 3;`) still occupy storage, so a
struct containing one is **not** vacuous and stays subject to normal tracking.

```c
struct Empty { };
struct Wrap { struct Empty inner; };   // recursively empty → vacuous
struct Outer { struct Empty e; struct Wrap w; int n; };

_Safe void empty_ok(void) {
    struct Outer o;
    o.n = 1;
    struct Empty x = o.e;   // ok: no storage to initialize
    struct Outer c = o;     // ok: e and w vacuous, n set → o promotes
}

struct Bits { unsigned : 3; };
_Safe void bits_err(void) {
    struct Bits b;
    struct Bits c = b;      // error: use of uninitialized value: 'b'
}
```

### Rule 3: All control-flow paths must initialize

```c
_Safe void example(int cond) {
    int x;
    if (cond) { x = 1; }
    // else path: x uninitialized
    int y = x;  // error: use of possibly uninitialized value: 'x'
}
```

### Rule 4: Address-of is a use

Taking `&`, `&_Mut`, or `&_Const` of an uninitialized variable is an error. Exception: `ensure_init` / `ensure_init_if_ret` arguments and `__assume_initialized` arguments.

```c
_Safe void example(void) {
    int x;
    int *_Borrow p = &_Mut x;  // error: use of uninitialized value: 'x'
}
```

### Rule 5: Functions must initialize return values on all paths

```c
_Safe int example(int cond) {
    if (cond) { return 1; }
}  // error: non-void function 'example' does not return a value in all control paths
```

(The error is anchored at the function's closing brace; a function that never
returns a value gets the same message without the "in all control paths" tail.)

### Rule 6: Array element assignment does NOT initialize

Element-by-element assignment does not mark an array as initialized. Arrays must use init lists or `__assume_initialized`.

```c
_Safe void bad(void) {
    int arr[3];
    arr[0] = 1; arr[1] = 2; arr[2] = 3;
    int x = arr[0];  // error: arr still uninitialized
}

_Safe void good(void) {
    int arr[3] = {1, 2, 3};  // ok: init list
    int x = arr[0];
}

_Safe void assume(void) {
    int arr[3];
    arr[0] = 1; arr[1] = 2; arr[2] = 3;
    _Unsafe { __assume_initialized(&arr); }
    int x = arr[0];  // ok
}
```

This also applies to array fields inside structs:

```c
typedef struct { int a[2]; int b; } ArrStruct;

_Safe void bad(void) {
    ArrStruct s;
    s.a[0] = 1; s.a[1] = 2; s.b = 3;
    ArrStruct t = s;  // error: s.a uninitialized
}

_Safe void good(void) {
    ArrStruct s = {{1, 2}, 3};
    ArrStruct t = s;  // ok
}
```

### Rule 7: Union — only whole-variant initialization covers a union

(Reworked 2026-08; previously *any* member write covered the union.) A union
counts as initialized in exactly **two** ways:

- a **declaration initializer**, any form (`= { .a = 42 }`, `= {0}`, `= {}`);
- a **single assignment that wholly initializes one variant or the whole
  union**: a scalar variant (`u.f = 3.14f;`), an entire struct variant
  (`u.s = (struct Inner){1, 2};`), or the union itself (`u = other;`).

Once covered, reads through **any** variant at any depth are ok (C semantics:
writing one variant covers all bytes), and later partial writes don't revoke
coverage. But **writing a single field of a struct variant covers nothing —
not even that field** (`u.s.x = 1; int v = u.s.x;` is an error), and writing
every field one by one **never accumulates** into coverage. Only the outermost
union on a path can be covered; diagnostics for an uncovered union name the
union, not the leaf field. `__assume_initialized` and `ensure_init` delegation
follow the same rule: asserting/delegating one field of a variant does not
cover the union — target the whole variant or union.

```c
// Compile with -uninit-check=all (union access forbidden in safe zones)
struct Inner { int x; int y; };
union U { struct Inner s; float f; int a; };

void whole_variant(void) {
    union U u;
    u.f = 3.14f;        // whole scalar variant → union covered
    int v = u.s.x;      // ok: cross-variant read after coverage
}

void partial(void) {
    union U u;
    u.s.x = 1;          // one field of a variant → covers nothing
    int v = u.s.x;      // error: use of uninitialized value: 'u'
    u.s.y = 2;          // field-by-field never accumulates either
}
```

A union member inside a struct participates in the struct's auto-promotion
once covered (`w.uw.f = 3.14f; w.v = 1;` → `w` fully initialized).

Known limitation: coverage is per-variant with **no size check** — after
`u.c = 1;` (a `char` variant), reading a `long` variant compiles even though
its upper bytes were never written.

### Rule 8: Nested structs — arbitrary depth tracking

```c
struct Inner { int x; int y; };
struct Outer { struct Inner inner; int z; };

_Safe void example(void) {
    struct Outer o;
    o.inner.x = 1;
    o.inner.y = 2;  // inner auto-promotes
    o.z = 3;        // o auto-promotes
    struct Outer p = o;  // ok
}
```

### Rule 9: Global and static variables are implicitly initialized

```c
static int global_count;

_Safe void example(void) {
    int x = global_count;  // ok: guaranteed zero-initialized by C spec
}
```

### Rule 10: Parameters are initialized at entry, including all sub-objects

```c
struct Pair { int a; int b; };
_Safe int rule10(struct Pair s) { return s.a + s.b; }  // ok: caller passed an initialized value
```

### Rule 11: Compound assignment and `++`/`--` are uses, not initializations

They read the object before writing it back:

```c
_Safe void rule11(void) {
    int x;
    x += 1;   // error: use of uninitialized value: 'x'
    x++;      // same error
}
```

### Expression coverage (GNU extensions, `sizeof`)

Since 2026-08 the analysis descends into constructs it previously skipped —
reads of uninitialized variables there are now caught:

- **Statement expressions** `({ ...; v })` — the statements are analyzed in
  place (`int y = ({ int t = x; t; });` errors when `x` is uninitialized).
- **GNU binary conditional** `a ?: b` — analyzed like the full ternary; the
  common operand is evaluated once.
- **`sizeof` of a VLA type** — `sizeof(int[n])` evaluates `n` (C11 6.5.3.4p2),
  so an uninitialized `n` errors. Only the *type* form: `sizeof(expr)` reads
  the stored size without re-evaluating, and `_Alignof` never evaluates.

`_Generic` and `__builtin_choose_expr` operands are still **not** descended
into.

## 3. `__attribute__((ensure_init))`

A parameter attribute that establishes an initialization contract:
- **Caller side**: after the call, `*param` is marked as initialized
- **Callee side**: compiler verifies `*param` is initialized on all return paths

```c
void init_int(int *__attribute__((ensure_init)) out);

_Safe void caller(void) {
    int x;
    _Unsafe { init_int(&x); }  // x marked initialized after call
    int y = x;                  // ok
}

// Compiler validates the contract:
void good_init(int *__attribute__((ensure_init)) out) {
    *out = 42;  // ok
}

void bad_init(int *__attribute__((ensure_init)) out) {
}  // error: ensure_init parameter 'out' not initialized at return
```

### Field-level partial initialization

```c
struct Pair { int a; int b; };
void init_field(int *__attribute__((ensure_init)) p);

_Safe void example(void) {
    struct Pair p;
    _Unsafe {
        init_field(&p.a);  // only p.a marked
        init_field(&p.b);  // p.b marked → p auto-promotes
    }
    struct Pair q = p;  // ok
}
```

### Safe zone usage

**Pointee must be concrete** (2026-09, INIT-033): the parameter cannot point to
`void` (`error: 'ensure_init' attribute only applies to pointer parameters to a
non-void type`), and in a function **definition** the pointee must be a
complete type — a declaration may still name a forward-declared struct:

```c
struct Handle;
void handle_init(struct Handle *__attribute__((ensure_init)) h);   // ok: declaration only
void wrap(struct Handle *__attribute__((ensure_init)) h) {         // error: __attribute__((ensure_init)) parameter 'h'
    handle_init(h);                                                //        points to incomplete type 'struct Handle' in a function definition
}
void fill(void *__attribute__((ensure_init)) buf);                 // error: pointer to void
```

```c
_Safe void init_safe(int *_Borrow __attribute__((ensure_init)) out);

_Safe void caller(void) {
    int x;
    init_safe(&_Mut x);  // ok in safe zone with &_Mut
    int y = x;            // ok
}
```

### Restrictions before `*param` is initialized

Cannot reassign or alias the `ensure_init` pointer before fulfilling the
contract. Aliasing covers any copy of the pointer value — a named local
(`int *p = out;`), the `&*out` spelling (which is `out` itself), and (since
2026-08) storing it into a **struct field or array element**:

```c
void bad(int *__attribute__((ensure_init)) out) {
    int local;
    out = &local;   // error: cannot reassign before *out initialized
}

void bad2(int *__attribute__((ensure_init)) out) {
    int *p = out;   // error: cannot alias before *out initialized
}

struct Holder { int *p; };
void bad3(int *__attribute__((ensure_init)) out) {
    struct Holder h;
    h.p = out;      // error: field store counts as aliasing too
    *out = 42;
}
```

Passing the pointer **by value to a function without the contract** is *not*
aliasing — it's allowed — but the compiler doesn't track writes the callee
makes through it, so the contract must still be fulfilled locally (or by
delegating to a contract-carrying callee). No warning fires on the call itself;
if the contract ends up unfulfilled, the error appears at return.

**Reading** through the pointer before `*param` is initialized is an error in
every zone, in every form that loads the pointee: `*out`, `out[0]`, passing
`*out` as a call argument, or reading through a temp alias. Taking an address
(`&out->f`) is not a load and is fine.

After initialization, free use is allowed:

```c
void ok(int *__attribute__((ensure_init)) out) {
    *out = 42;       // contract fulfilled
    int *p = out;    // ok: *out already initialized
    out = &local;    // ok
}
```

### Delegation

`ensure_init` can delegate to another `ensure_init` function — passing the
pointer to a contract-carrying callee is the contract being handed on, not a
read or an alias:

```c
void init_val(int *__attribute__((ensure_init)) out);

void init_delegated(int *__attribute__((ensure_init)) out) {
    init_val(out);  // ok: delegates to another ensure_init
}
```

Delegation credit is **field-precise**: handing `&out->a` to a contract callee
covers only that field, and reads of other fields still error until they're
initialized too:

```c
struct Pair { int a; int b; };
void init_int(int *__attribute__((ensure_init)) p);

void field_precise(struct Pair *__attribute__((ensure_init)) out) {
    init_int(&out->a);   // credits out->a only
    int x = out->b;      // error: out->b still uninitialized
    out->b = 2;          // now the whole *out is covered
}
```

### Redeclaration rules

Same safety-level redeclarations must be consistent (both have `ensure_init` or neither). Across safety levels the **unsafe-safe refinement relation** applies (see `bsc-safe-zone` §5): `ensure_init` / `ensure_init_if_ret` are *sticky* attributes — the `_Safe` declaration may carry one that the `_Unsafe` declaration omits, but an `_Unsafe` declaration may not carry one the `_Safe` declaration lacks, and if both carry it they must match.

### Function pointer compatibility

`ensure_init` is part of the function type. In a **safe zone** you cannot turn a non-`ensure_init` function into one that needs `ensure_init` — neither by assignment **nor by an explicit cast** (no contract laundering). In an `_Unsafe` zone the explicit cast is allowed (the user takes responsibility):

```c
typedef _Safe void (*InitFn)(int *__attribute__((ensure_init)) _Borrow out);

_Safe void has_attr(int *__attribute__((ensure_init)) _Borrow out) { *out = 1; }
_Safe void no_attr(int *_Borrow out) { *out = 1; }

_Safe void test(void) {
    InitFn fn = has_attr;             // ok
    // InitFn fn2 = no_attr;          // error: missing ensure_init
    // InitFn fn3 = (InitFn)no_attr;  // error: explicit cast can't launder it either
    _Unsafe {
        InitFn fn4 = (InitFn)no_attr; // ok: unsafe zone — user's responsibility
    }
}
```

Indirect calls through function pointers support `ensure_init` tracking:

```c
_Safe void indirect_call(InitFn fn) {
    int x;
    fn(&_Mut x);   // x marked initialized via ensure_init
    int y = x;     // ok
}
```

## 4. `__attribute__((ensure_init_if_ret(arg)))`

A **conditional** init contract: the pointed-to memory is only required to be
initialized when the function **returns `arg`**. This models the common C idiom
of an out-param that's filled only on success and left untouched on failure —
which plain `ensure_init` (which demands init on *all* return paths) cannot
express.

```c
// fills *info only when it returns 0
_Safe unsigned int Init(Info *_Borrow __attribute__((ensure_init_if_ret(0))) info);

_Safe unsigned int example(void) {
    Info info;                                  // no redundant init needed
    unsigned int ret = Init(&_Mut info);
    if (ret != 0) return ret;                   // failure path: info still uninit
    unsigned int size = GetSize(&_Const info);  // ok: on ret==0, info is initialized
    return 0;
}
```

Use this instead of pre-initializing the variable redundantly, or instead of an
unsafe `__assume_initialized` (which would skip verifying the callee actually
initializes it).

### Declaration rules

- **Parameters only** — not globals or locals.
- The parameter must be a **raw pointer or mutable borrow to a non-`const`,
  non-`void` type** (`int *`, `int *_Borrow`; not `const int *_Borrow`, not
  `void *`). In a function **definition** the pointee must be complete (same
  INIT-033 rule as `ensure_init`; a declaration may use a forward-declared struct).
- The function's **return type must be an integer type or `_Bool`**.
- `arg` must be an **integer literal** (may be negative; not a float or char)
  **representable in the return type** (INIT-034, 2026-09): `_Bool f(...
  ensure_init_if_ret(2))` is `error: __attribute__((ensure_init_if_ret))
  argument 2 is not representable in return type '_Bool', so no return can
  ever satisfy the contract; use a value of 0 or 1`; `char` with `128` likewise.
- **Mutually exclusive with `ensure_init`** on the same parameter.

### Redeclaration & function-pointer compatibility

- Same-safety-level redeclarations must agree on presence **and** `arg`. If an
  `_Unsafe` declaration carries it, the paired `_Safe` declaration's matching
  parameter must carry it with the same `arg`.
- Assigning a function **without** the contract to a function-pointer type that
  **has** it is an error; the reverse (strong→weak) is allowed. If both sides
  have it, the `arg` values must match.

### Caller side

You may take `&`/`&_Mut` of an uninitialized variable **only if** the resulting
expression is passed **directly** as the `ensure_init_if_ret` argument (binding
it to a borrow first is an error). After the call, the variable counts as
initialized **only on the branch where the return value equals `arg`**:

```c
_Safe int bar(int *_Borrow __attribute__((ensure_init_if_ret(0))));

_Safe void good(void) {
    int a;
    int res = bar(&_Mut a);
    if (res != 0) return;     // bail on the non-arg path
    int b = a;                // ok: here res==0, so a is initialized
}
_Safe void bad(void) {
    int a;
    (void)bar(&_Mut a);
    int b = a;                // error: no return-value check, a may be uninit
}
```

The return-value check may be written `e == v`, `e != v`, `v == e`, or `v != e`
(`v` an integer constant expression). `e` may be the call itself, or a variable
that was assigned the call's result directly and not address-taken / re-borrowed
/ reassigned in between. (Sub-comparisons buried inside `&&`/`||` are **not**
recognized as the check.) Rules tightened 2026-09-30 (all verified):

- **Truth tests are not checks**: `if (!res)`, `if (res)`, `if (!(res != 0))`
  only separate 0 from non-0, so `a` stays uninitialized inside them. Write
  the compared value out: `if (res == 0)`.
- **A guard stored in a variable is not a check**: `_Bool ok = r == 0; if (ok)`
  loses the association.
- **Integer conversions on the way into the variable** keep the association
  only if they don't lose values: widening or same-width sign change
  (`unsigned u = (unsigned)neg(&_Mut a); if (u == 4294967295u)` for
  `ensure_init_if_ret(-1)` is ok; `long l = ...; if (l == -1)` ok). A
  **narrowing** cast (`unsigned char c = ...; if (c == 255)`) or a cast to
  `_Bool` maps several return values onto one, so the association is dropped.
  `v` and `arg` are compared in the variable's type.
- **Joins**: after an `if`/`?:`/loop, `r` stays associated only if **every**
  incoming path assigned it from the call. `int r = c ? bar(&_Mut a) : -1;
  if (r == 0) { int b = a; }` is an error; so is `r = bar(...)` inside a
  `for` that may run 0 times. `if (c) r = bar(&_Mut a); else r = bar(&_Mut a);`
  is fine. Put the check on the same path as the call when in doubt.

### Callee side

`*p` starts uninitialized; on the "return `arg`" path it must be fully
initialized (all struct fields) or it's an error. Repointing `p`, or assigning
`p` to another pointer, is allowed but only **after** `*p` is initialized.

```c
typedef struct { int a; int b; } S;
_Safe unsigned int ok(int a, S *_Borrow __attribute__((ensure_init_if_ret(0))) p) {
    if (a == 2) return 1;       // return-1 path: no init required
    p->a = 1; p->b = 2;
    return 0;                   // return-0 path: fully initialized
}
```

**Returning a conditional** is checked per arm (2026-09): `return c ? x : y;`
behaves like `if (c) return x; else return y;`. **Forwarding** another contract
call's result is allowed when both `arg`s match — the callee's contract covers
that path. Storing the value in a non-constant local first drops both.

```c
_Safe int inner(int *_Borrow __attribute__((ensure_init_if_ret(0))) p);
_Safe int f1(int c, int *_Borrow __attribute__((ensure_init_if_ret(0))) p) {
    return c ? inner(p) : -1;   // ok: -1 arm never equals arg; inner arm is forwarded
}
_Safe int f2(int c, int *_Borrow __attribute__((ensure_init_if_ret(0))) p) {
    return c ? inner(p) : 0;    // error: '*p' not initialized at return in __attribute__((ensure_init_if_ret(0))) function
}
_Safe int f3(int c, int *_Borrow __attribute__((ensure_init_if_ret(0))) p) {
    int r = c ? inner(p) : -1;
    return r;                   // error: cannot verify ... contract for '*p': return value is not an integer constant
}
_Safe int g3(int *_Borrow __attribute__((ensure_init_if_ret(0))) p) { int r = inner(p); return r; }  // ok: r still associated
_Safe unsigned g1(int *_Borrow __attribute__((ensure_init_if_ret(0))) p) { return (unsigned)inner(p); }  // ok: no values lost
_Safe short g2(int *_Borrow __attribute__((ensure_init_if_ret(0))) p) { return (short)inner(p); }        // error: narrowing drops the association
```

### Known limitations (conservative false errors)

The check is a flow-sensitive reaching-definition analysis — no loop trip-count
reasoning, no path correlation:
- A loop body is treated as possibly executing 0 times, even with a constant
  bound — initialize before the loop or use `do-while`.
- Two separate `if`s testing the same variable are treated as independent —
  merge the checks into one `if`.
- Copying the return value into a local that is later reassigned / address-taken
  drops the association with the call.

## 5. `__assume_initialized`

Built-in function to mark a variable as initialized at a program point. No contract verification — user guarantees correctness.

```c
_Safe void example(void) {
    int x;
    _Unsafe { __assume_initialized(&x); }
    int y = x;  // ok
}
```

- Must use `&` prefix: `__assume_initialized(&x)` (not `__assume_initialized(x)`)
- Only in `_Unsafe` blocks
- Path-sensitive: only effective on the CFG path where it executes
- One variable per call
- For arrays: `__assume_initialized(&arr)` (required due to array decay)
- For structs: marks all fields as initialized

### Supported argument forms

The address-of operand must be one of:

| Form | Meaning |
|------|---------|
| `&x` | local variable; if `x` is an `ensure_init` pointer parameter, also marks `*x` initialized |
| `&x.f.g...` | local struct field, any nesting (pure field path) |
| `&*p` | the object pointed-to by an `ensure_init` parameter `p` |
| `&p->f.g...` | field of the object pointed-to by an `ensure_init` parameter (pure field path) |

When all fields of `*p` are marked through `&p->...`, `*p` is automatically
promoted to fully initialized.

A **written cast** anywhere in the path is rejected (2026-09):
`__assume_initialized(&*(struct S *)out)` is `error: unsupported
__assume_initialized argument` + `note: the argument must be '&' applied to a
variable, struct field access, or pointer dereference`. Only implicit casts are
looked through.

```c
struct Pair { int a; int b; };
void assume_through_ptr(struct Pair *__attribute__((ensure_init)) out) {
    out->a = 1;
    _Unsafe { __assume_initialized(&out->b); }   // all fields covered → *out initialized
}
```

### **Array subscripts (`[i]`) are NOT allowed in the path**

Init analysis treats arrays as **single units** — individual elements are not
tracked, so you can only assume the whole array, never an element.

```c
struct WithArr { int arr[3]; };
struct Outer   { struct WithArr s[2]; };

_Safe void example(void) {
    struct WithArr w;
    _Unsafe { __assume_initialized(&w.arr); }       // ok: whole array field

    // _Unsafe { __assume_initialized(&w.arr[0]); }     // error: subscript in path
    // _Unsafe { __assume_initialized(&o.s[0].arr); }   // error: subscript in middle
    // _Unsafe { __assume_initialized(&o.s[0].arr[0]); }// error: subscript at end
}
```

```c
// Path-sensitive:
_Safe void example(int cond) {
    int x;
    if (cond) { _Unsafe { __assume_initialized(&x); } }
    int y = x;  // error: possibly uninitialized (not all paths)
}
```

## 6. Compiler Options

`-uninit-check=<mode>`:

| Mode | Behavior |
|------|----------|
| `none` | Disable initialization analysis |
| `safeonly` (default) | Check ordinary variables in `_Safe` zones only; init contracts (`ensure_init` / `ensure_init_if_ret`) are checked regardless of zone |
| `all` | Check in all code (including non-safe) |

Note: `ensure_init` contract verification is active whenever mode is not `none`, even outside safe zones.

> For safe zone rules, see `bsc-safe-zone` Skill
> For ownership initialization patterns, see `bsc-ownership` Skill
> For common initialization mistakes, see `bsc-common-mistakes` Skill
