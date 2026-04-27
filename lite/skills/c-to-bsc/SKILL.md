---
name: c-to-bsc
description: "BiSheng C translation from C. When you translate C code to BSC, add ownership annotations, or migrate a C project to BSC, you MUST use this Skill first. This lite version keeps .c/.h file extensions and uses -x bsc to compile."
---

# C to BSC Translation (Lite — Keep `.c`/`.h` Extensions)

## Core Approach — Change as Little as Possible

**Change the C codebase as little as you can.** Only ADD BSC ownership annotations. Change anything else only if the compiler genuinely requires it.

- Keep `.c`/`.h` extensions; compile with `clang -x bsc file.c` (or `-xbsc`, both work).
- The one new include you typically need: `#include "bishengc_safety.hbs"` where you use `safe_malloc`/`safe_free`.

## TOP RULE: Safe by Default — `_Unsafe` is Compiler-Driven

**Mark every function `_Safe`. Write every body as if it were `_Safe`. Add `_Unsafe` ONLY where the compiler reports an error you cannot fix any other way.**

Workflow:

1. Annotate the function `_Safe`; translate the body with no `_Unsafe`.
2. Compile. For each diagnostic, first try to fix it **without** `_Unsafe` — convert `&` to `&_Const`/`&_Mut`, swap raw `malloc`/`free` for `safe_malloc`/`safe_free`, fix `_Owned`/`_Borrow`/`_Nullable` annotations, restructure the line.
3. Only when no `_Safe`-zone form works (variadic `printf`, raw pointer arithmetic, FFI, raw subscripting), wrap the **single offending statement** in `_Unsafe stmt;` (no braces) or `_Unsafe { ... }` (smallest block).
4. Re-compile and repeat.

Forbidden: marking the whole function `_Unsafe` for one bad line; wrapping multiple lines when one triggered the error; adding `_Unsafe` pre-emptively before compiling; using `_Unsafe` to escape borrow-checker errors (fix the annotations instead).

## TOP RULE 2: Every Pointer in a Function Signature MUST Be Annotated

**No bare `T *` in any parameter or return type.** Every pointer in a function declaration / definition / parameter list must carry `_Owned` or `_Borrow`, OR fall into one of four narrow raw cases: output double-pointer (`T **out`), function pointer, opaque cast intermediary, or arithmetic cursor.

Decision tree:

1. Function frees / transfers / stores → `T *_Owned`.
2. Function only reads → `const T *_Borrow`.
3. Function mutates but does not free → `T *_Borrow`.
4. None of the above → re-read the body and the call sites; do NOT leave bare `T *` as a placeholder.

The annotation MUST match between the `.h` declaration and the `.c` definition. A bare-`T*` declaration with an annotated definition (or vice versa) is a bug.

```c
// WRONG — bare T*, ownership unspecified
Node *find(Container *c, int id);
void enqueue(Container *c, Node *item);

// CORRECT
const Node *_Borrow find(const Container *_Borrow c, int id);
void enqueue(Container *_Borrow c, Node *_Owned item);
```

## Step 1: Default to `_Safe`; Keep `_Unsafe` Minimal

This is the TOP RULE applied per function. Default the signature to `_Safe`. Compile. Wrap only the lines the compiler rejects in `_Unsafe { ... }` (or `_Unsafe stmt;`).

**`_Unsafe` is contagious**: an `_Unsafe` function forces every caller to also be in `_Unsafe` context. Don't mark a whole function `_Unsafe` to avoid wrapping one line. A function with an `_Unsafe { ... }` block inside is **still `_Safe`** — that is the whole point.

```c
// GOOD — interface _Safe, only the unsafe op is wrapped
_Safe void log_value(const int *_Borrow v) {
    _Unsafe { printf("%d\n", *v); }
}

// BAD — whole function _Unsafe for one line
_Unsafe void log_value(const int *_Borrow v) {
    printf("%d\n", *v);
}
```

## Step 2: Classify Every Pointer

For every pointer in the code, decide which category it belongs in:

**A — Owned** (`T *_Owned`): the code frees it, or it came from `malloc`/`calloc`/`strdup`.

**B — Borrowed** (`T *_Borrow`): it aliases someone else's allocation; the code does NOT free it.

**C — Raw** (plain `T *`): interior pointer, iterator, pointer arithmetic result.

**Rule of thumb**: if a pointer touches `malloc`/`free`, it is almost always Category A.

## Step 3: Replace `malloc`/`free`

```c
// BEFORE (C)
Node *n = (Node*)malloc(sizeof(Node));
free(n);

// AFTER (BSC, still in .c file, compiled with -x bsc)
#include "bishengc_safety.hbs"

Node *_Owned n = safe_malloc<Node>((Node){0});
safe_free((void *_Owned)n);
```

For variable-size allocations or `strdup`, use raw `malloc` inside `_Unsafe`, then convert to `_Owned` with `__take_from_raw`. **Direct `(T *_Owned)malloc(...)` C casts are forbidden everywhere** — even inside `_Unsafe` — per compiler rule. You MUST use the builtins:

```c
_Unsafe {
    char *raw = (char *)malloc(length + 1);
    if (raw == nullptr) { /* handle */ }
    char *_Owned buf = __take_from_raw(raw);    // raw → _Owned via builtin
    // ...use buf...
    safe_free((void *_Owned)buf);                // safe_free accepts _Owned directly
}
```

Going the other way — `_Owned` → raw — uses `__move_to_raw(p)` (transfers ownership out; `p` becomes unusable) or `(T *)&_Mut *p` (just borrows, `p` keeps ownership).

## Step 4: Annotate Struct Fields

**Rule**: the struct's cleanup/delete function is the source of truth. If cleanup frees `field` → mark `_Owned`. If it doesn't → leave plain (raw pointer) or use a value type.

```c
// BEFORE (C)
typedef struct Token {
    char *name;
    char *value;
    int kind;
} Token;

// AFTER — cleanup frees name and value, kind is plain data
typedef struct Token {
    char *_Owned name;
    char *_Owned value;
    int kind;
} Token;
```

**`_Borrow` as a struct field is heavily restricted** in BSC — the `_Borrow` field can't borrow from the containing struct or its other members, and a struct containing a `_Borrow` can't itself be borrowed. For back-references (linked lists, trees, graphs with parent pointers), **do NOT** use `_Borrow` — use raw pointers and wrap access in `_Unsafe`. The stdlib `LinkedList<T>` uses raw pointers for this reason.

## Step 5: Annotate Function Signatures

**Function takes a value it will free** → `_Owned` parameter:
```c
void container_add(Container *_Borrow c, Node *_Owned item);
```

**Function just reads** → `const _Borrow` parameter **and** `const _Borrow` receiver:
```c
size_t count_items(const Node *_Borrow list);
// For getters on a container, both receiver and return must be const:
const Entry *_Borrow get(const Container *_Borrow this, size_t i);
```

**Function mutates but doesn't free** → mut `_Borrow` parameter:
```c
void container_clear(Container *_Borrow c);
```

**Function creates and returns heap memory** → `_Owned` return:
```c
Node *_Owned create_node(void);
```

**Const-correctness of getters matters.** If you write a read-only getter with a non-const `Container *_Borrow` receiver, it becomes unreachable from any caller that holds a `const Container *_Borrow`. For read-only accessors (names starting with `get_`/`find_`/`has_`/`count_`/`is_`/`peek_`), make BOTH the receiver and the returned pointer `const`.

## Step 6: Convert `&` to `&_Const` / `&_Mut` in `_Safe` Functions

In `_Safe` functions, plain `&` is forbidden:

```c
// BEFORE (C)
_Safe void init(int *out) { *out = 0; }
_Safe void caller(void) {
    int x = 42;
    init(&x);                              // ERROR in _Safe: plain &
}

// AFTER (BSC)
_Safe void init(int *_Borrow out) { *out = 0; }
_Safe void caller(void) {
    int x = 42;
    init(&_Mut x);                         // writes through → &_Mut
}
```

Use `&_Const x` when the target is read-only, `&_Mut x` when the target is written.

## Step 7: `_Owned` Pointers With Null

If an `_Owned` pointer can ever be null (init to `nullptr`, error path), add `_Nullable`:

```c
// WRONG
cJSON *_Owned item = NULL;                 // ERROR: _Owned is non-null

// CORRECT
cJSON *_Owned _Nullable item = nullptr;    // OK
if (cond) {
    item = create_item();
}
safe_free((void *_Nullable _Owned)item);   // safe for nullable
```

Use `nullptr` instead of `NULL` in BSC code.

## Step 8: Compile

```bash
clang -x bsc file.c -fsyntax-only
```

Fix errors iteratively. The most common errors:

- **"unknown type name '_Owned'"** — you wrote `_Owned T*`; rewrite as `T *_Owned`.
- **"_Owned pointer cannot be null"** — add `_Nullable`.
- **"use of moved value"** — you passed `_Owned` to a function, then used it again. Use `_Borrow` instead, or pass a clone.
- **"cannot borrow as mutable more than once"** — two mut borrows overlap. Scope them tighter.
- **"plain & forbidden in _Safe"** — use `&_Const` or `&_Mut`.

## Checklist

- [ ] Kept `.c`/`.h` extensions; compile with `clang -x bsc file.c`
- [ ] Platform-specific code (`#ifdef _WIN32`, `__declspec`, etc.) LEFT IN PLACE — BSC clang handles it
- [ ] `#include` paths unchanged (still reference `.h`)
- [ ] `#include "bishengc_safety.hbs"` added where safe_malloc/safe_free are used
- [ ] Functions default to `_Safe`; `_Unsafe` only wraps specific operations (not whole functions)
- [ ] Every `_Unsafe` corresponds to a real compiler diagnostic that no `_Safe`-zone fix could resolve. No pre-emptive `_Unsafe`; deleting it would re-introduce a compile error.
- [ ] Every pointer classified: `_Owned`, `_Borrow`, or raw
- [ ] Struct fields annotated based on whether the cleanup function frees them
- [ ] Every pointer in every function signature annotated — no bare `T *` in parameter or return type unless it is a documented raw case (output double-pointer, function pointer, opaque cast, arithmetic cursor); declarations and definitions agree
- [ ] Function parameters and returns annotated
- [ ] Read-only getters (`get_`/`find_`/`has_`/`count_`/`is_`/`peek_`) take `const T *_Borrow this` AND return `const ...*_Borrow`
- [ ] `malloc` → `safe_malloc<T>(val)` where size is a single `T`
- [ ] `free` → `safe_free((void *_Owned)p)` or `safe_free((void *_Nullable _Owned)p)`
- [ ] Plain `&` in `_Safe` converted to `&_Const` or `&_Mut`
- [ ] `NULL` → `nullptr`
- [ ] `_Owned` pointers that can be null marked `_Nullable`
- [ ] Code compiles with `clang -x bsc file.c -fsyntax-only`
