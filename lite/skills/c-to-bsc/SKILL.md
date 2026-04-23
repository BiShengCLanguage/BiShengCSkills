---
name: c-to-bsc
description: "BiSheng C translation from C. When you translate C code to BSC, add ownership annotations, or migrate a C project to BSC, you MUST use this Skill first. This lite version keeps .c/.h file extensions and uses -x bsc to compile."
---

# C to BSC Translation (Lite — Keep `.c`/`.h` Extensions)

## Core Approach — Keep the File Structure, Only Add Annotations

**Fundamental rule: change the C codebase as little as possible.** Only ADD BSC ownership annotations. Do NOT restructure, rename, or strip anything.

- **Keep `.c` and `.h` file extensions.** Do NOT rename. Compile with `clang -x bsc file.c -o output` (or `-xbsc`, both work).
- **Keep all platform-specific code in place** — `#ifdef _WIN32`, `__declspec(...)`, `__cdecl`, `__stdcall`, `extern "C"` guards. BSC is clang-based and handles all of these; removing them is churn that risks breaking cross-platform builds for no benefit.
- **Keep `#include` paths unchanged.** Headers still reference `.h`, not `.hbs`. The only new include is `#include "bishengc_safety.hbs"` wherever you use `safe_malloc`/`safe_free`.

Why: this lets your project build as plain C AND as BSC from the same sources during an incremental migration, and keeps review diffs focused on the ownership work.

## Step 1: Classify Every Pointer

For every pointer in the code, decide which category it belongs in:

**A — Owned** (`T *_Owned`): the code frees it, or it came from `malloc`/`calloc`/`strdup`.

**B — Borrowed** (`T *_Borrow`): it aliases someone else's allocation; the code does NOT free it.

**C — Raw** (plain `T *`): interior pointer, iterator, pointer arithmetic result.

**Rule of thumb**: if a pointer touches `malloc`/`free`, it is almost always Category A.

## Step 2: Replace `malloc`/`free`

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

## Step 3: Annotate Struct Fields

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

## Step 4: Annotate Function Signatures

**Function takes a value it will free** → `_Owned` parameter:
```c
void container_add(Container *_Borrow c, Node *_Owned item);
```

**Function just reads** → `const _Borrow` parameter:
```c
size_t count_items(const Node *_Borrow list);
```

**Function mutates but doesn't free** → mut `_Borrow` parameter:
```c
void container_clear(Container *_Borrow c);
```

**Function creates and returns heap memory** → `_Owned` return:
```c
Node *_Owned create_node(void);
```

## Step 5: Convert `&` to `&_Const` / `&_Mut` in `_Safe` Functions

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

## Step 6: `_Owned` Pointers With Null

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

## Step 7: Compile

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
- [ ] Every pointer classified: `_Owned`, `_Borrow`, or raw
- [ ] Struct fields annotated based on whether the cleanup function frees them
- [ ] Function parameters and returns annotated
- [ ] `malloc` → `safe_malloc<T>(val)` where size is a single `T`
- [ ] `free` → `safe_free((void *_Owned)p)` or `safe_free((void *_Nullable _Owned)p)`
- [ ] Plain `&` in `_Safe` converted to `&_Const` or `&_Mut`
- [ ] `NULL` → `nullptr`
- [ ] `_Owned` pointers that can be null marked `_Nullable`
- [ ] Code compiles with `clang -x bsc file.c -fsyntax-only`
