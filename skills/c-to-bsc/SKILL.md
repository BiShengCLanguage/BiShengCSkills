---
name: c-to-bsc
description: "BiSheng C translation from C. When you need to translate/convert/port C code (.c/.h) to BiSheng C (.cbs/.hbs), add ownership annotations, or migrate a C project to BSC, you MUST use this Skill first."
---

# C to BiSheng C Translation Skill

## MANDATORY: Read This Before Any C-to-BSC Translation

If you are translating C code to BSC, you MUST follow this process. Changing file extensions and stripping platform code is NOT a translation — you must analyze every pointer and add BSC ownership annotations where applicable.

## CRITICAL RULE: `_Owned` Is Non-Nullable By Default

`_Owned` pointers CANNOT be `NULL` unless you add `_Nullable`:

```c
// WRONG — compiler error: _Owned pointer cannot be null
cJSON *_Owned item = NULL;

// CORRECT — add _Nullable when the pointer may be NULL
cJSON *_Owned _Nullable item = nullptr;

// CORRECT — initialized immediately, no _Nullable needed
cJSON *_Owned item = safe_malloc<cJSON>((cJSON){0});
```

**Rule**: If an `_Owned` variable is ever assigned `NULL`/`nullptr`, initialized to `NULL`, or checked against `NULL`, it MUST be declared `T *_Owned _Nullable`. Use `nullptr` instead of `NULL` in BSC code.

## Translation Process

### Step 1: Rename Files
- `.c` → `.cbs`
- `.h` → `.hbs`
- Update all `#include` directives accordingly

### Step 2: Strip Platform-Specific Code
- Remove `#ifdef _WIN32` / `__GNUC__` / `_MSC_VER` blocks
- Remove `__declspec(dllexport/dllimport)`
- Remove `__cdecl` / `__stdcall` calling conventions
- Remove `#ifdef __cplusplus extern "C"` guards
- Replace visibility macros (e.g. `MYLIB_PUBLIC(type)`) with plain `type`

### Step 3: Analyze Ownership (THE CRITICAL STEP)

For every pointer in the codebase, classify it into one of three categories:

#### Category A: Owned pointers → annotate `*_Owned`

A pointer OWNS data if:
- It was assigned from `malloc`/`calloc`/`realloc`/`strdup`
- The code calls `free()` on it (or is responsible for freeing)
- It is returned from a function that creates/allocates (caller must free)
- A struct field that gets freed in the struct's cleanup/delete function

#### Category B: Borrowed pointers → annotate `*_Borrow`

A pointer BORROWS data if:
- It points into someone else's allocation (e.g. back-pointers, parent pointers)
- It is a function parameter for read-only or mutate-without-freeing access
- It is used for traversal without taking ownership
- It aliases another owned pointer temporarily

#### Category C: Raw pointers → leave as plain `T *` (NO annotation)

Some pointers CANNOT or SHOULD NOT be annotated. Leave these as raw `T *`:

- **Pointer arithmetic / interior pointers**: pointers into the middle of a buffer
  ```c
  unsigned char *cursor = buffer + offset;  // points inside buffer, not an allocation
  char *end = str + len;                    // pointer arithmetic result
  ```
- **Output parameters / double pointers**: `T **out` used to return values
  ```c
  void get_result(int **out) { *out = &some_local; }
  ```
- **Iterators / scanning pointers**: temporary pointers that walk through data
  ```c
  const char *p = input;
  while (*p != '\0') { p++; }  // just scanning, no ownership
  ```
- **Conditional ownership**: when the same field is sometimes owned, sometimes not (flag-based)
  ```c
  // If ownership depends on a runtime flag, you may need to keep it raw
  // and handle it with _Unsafe blocks
  struct Item {
      int flags;
      void *data;  // owned if !(flags & IS_REFERENCE), borrowed otherwise
  };
  ```
- **Opaque / void* in generic contexts**: casting intermediaries
  ```c
  void *tmp = (void *)ptr;  // intermediate cast, not a real allocation
  ```
- **Stack pointers / address-of results**: `&local_var` is not heap-allocated
  ```c
  int x = 42;
  int *p = &x;  // points to stack, not owned, not a borrow in BSC sense
  ```
- **Function pointers**: not data pointers, leave as-is
- **Pointers inside `_Unsafe` blocks**: when you explicitly opt out of safety checks

### Step 3.5: Convert Allocations to safe_malloc / safe_free (PREFERRED)

BSC provides `safe_malloc<T>(val)` and `safe_free()` from `bishengc_safety.hbs`. **Prefer these over raw malloc/free** — they return `T *_Owned` directly with no cast needed and work in `_Safe` context.

```c
#include "bishengc_safety.hbs"
```

**Signatures (from BSC standard library):**
- `_Safe T *_Owned safe_malloc<T>(T t)` — allocates, initializes to `t`, returns `T *_Owned`
- `_Safe void safe_free(void *_Nullable _Owned p)` — frees a nullable owned pointer

| C (original) | BSC (preferred: safe_malloc) | BSC (fallback: raw malloc in _Unsafe) |
|---|---|---|
| `malloc(sizeof(int))` | `safe_malloc<int>(0)` | `(int *_Owned)malloc(sizeof(int))` |
| `free(p)` | `safe_free((void *_Owned)p)` | `_Unsafe { free((void *_Owned)p); }` |
| `p = NULL; free(p);` | `safe_free((void *_Nullable _Owned)p)` | N/A — use safe_free for nullable |

**When to use which:**
- `safe_malloc<T>(val)` — use when allocating a single value of known type. Returns `T *_Owned`, initializes to `val`. No cast needed. Works in `_Safe` context.
- `safe_free(p)` — **preferred for all frees**. Accepts `void *_Nullable _Owned`, so it works even when the pointer might be NULL. Cast argument: `safe_free((void *_Owned)p)` or `safe_free((void *_Nullable _Owned)p)` if nullable.
- Raw `malloc` with `_Owned` cast — use when `safe_malloc` doesn't fit: variable-size allocations (`malloc(n * sizeof(T))`), `calloc`, `realloc`, `strdup`, or buffer allocations. Requires `_Unsafe` context.
- Raw `free()` — takes `void *_Owned` (non-nullable). Use only in `_Unsafe` blocks. If the pointer might be NULL, use `safe_free` instead.

#### Converting malloc → safe_malloc
```c
// BEFORE (C)
Node *n = (Node*)malloc(sizeof(Node));
memset(n, 0, sizeof(Node));

// AFTER (BSC) — preferred
Node *_Owned n = safe_malloc<Node>((Node){0});

// AFTER (BSC) — fallback for when safe_malloc doesn't fit
_Unsafe {
    Node *_Owned n = (Node *_Owned)malloc(sizeof(Node));
    memset(n, 0, sizeof(Node));
}
```

#### Converting free → safe_free
```c
// BEFORE (C)
free(node->name);
free(node);

// AFTER (BSC) — safe_free accepts _Nullable _Owned, safe for possibly-NULL pointers
safe_free((void *_Owned)node->name);
safe_free((void *_Owned)node);

// If the pointer might be NULL (common in cleanup paths):
safe_free((void *_Nullable _Owned)node->name);  // safe even if name is NULL
```

#### Variable-size allocations — must use raw malloc
```c
// BEFORE (C)
char *buf = (char*)malloc(length + 1);
char *copy = strdup(original);
buf = (char*)realloc(buf, newsize);

// AFTER (BSC) — safe_malloc can't do this, use raw malloc in _Unsafe
_Unsafe {
    char *_Owned buf = (char *_Owned)malloc(length + 1);
    char *_Owned copy = (char *_Owned)strdup(original);
    buf = (char *_Owned)realloc((void *_Owned)buf, newsize);
}
```

#### Realloc ownership semantics
`realloc` is tricky — it consumes the old pointer and returns a new one:
```c
_Unsafe {
    // realloc takes ownership of old buffer, returns new owned buffer
    // On failure, realloc returns NULL but old buffer is NOT freed
    char *_Owned _Nullable new_buf = (char *_Owned _Nullable)realloc((void *_Owned)old_buf, newsize);
    if (new_buf == nullptr) {
        // old_buf is still valid and owned — handle error
        safe_free((void *_Owned)old_buf);
        return;
    }
    old_buf = new_buf;  // transfer ownership
}
```

### Step 4: Annotate Pointers (Categories A and B only)

Only annotate pointers that clearly fall into Category A or B. When in doubt, leave as raw and add a `/* TODO: ownership unclear */` comment.

#### Struct fields
```c
// BEFORE (C)
typedef struct Node {
    struct Node *next;
    struct Node *prev;
    char *name;
    const char *label;
} Node;

// AFTER (BSC) — analyze the delete/free function to determine ownership
typedef struct Node {
    struct Node *_Owned next;      // delete function walks and frees next → owned
    struct Node *_Borrow prev;     // delete function does NOT free prev → borrowed
    char *_Owned name;             // delete function frees name → owned
    const char *_Borrow label;     // never freed → borrowed
} Node;
```

#### Function parameters — borrowing (when not taking ownership)
```c
// BEFORE (C)
int count_items(const Node *list) { ... }  // just reads, doesn't free

// AFTER (BSC)
int count_items(const Node *_Borrow list) { ... }
```

#### Function parameters — taking ownership (caller gives up ownership)
```c
// BEFORE (C)
void container_add(Container *c, Node *item) { ... c takes ownership of item ... }

// AFTER (BSC)
void container_add(Container *_Borrow c, Node *_Owned item) { ... }
```

#### Function returns — transferring ownership
```c
// BEFORE (C)
Node* create_node(void) {
    Node *n = malloc(sizeof(Node));
    return n;  // caller must free
}

// AFTER (BSC)
Node *_Owned create_node(void) {
    Node *_Owned n = (Node *_Owned)malloc(sizeof(Node));
    return n;  // ownership transfers to caller
}
```

#### Function returns — borrowing (returning pointer into existing data)
```c
// BEFORE (C)
Node* find_node(Container *c, int id) { ... return pointer into c's data ... }

// AFTER (BSC) — caller does NOT free the result
Node *_Borrow find_node(Container *_Borrow c, int id) { ... }
```

#### Raw pointers — leave unannotated
```c
// These stay as plain pointers — no _Owned or _Borrow
unsigned char *cursor = buffer_at_offset(buf);      // interior pointer
const unsigned char *input_pointer = input + 1;     // pointer arithmetic
unsigned char *output_pointer = output;              // alias into owned buffer
char *after_end = nullptr;                           // used by strtod
```

### Step 5: Handle Special Patterns

#### Conditional ownership (flag-based)
Some C code uses flags to decide whether to free:
```c
if (!(item->type & IS_REFERENCE)) {
    free(item->child);  // only free if we own it
}
```
Options:
1. Keep the field as raw `T *` and use `_Unsafe` blocks for free
2. Restructure into two separate types (owned vs reference variant)
3. Keep as `*_Owned` and use `_Unsafe` to skip free when flag is set

#### String literals vs allocated strings
```c
const char *literal = "hello";                              // raw pointer — string literal, never freed
char *_Owned allocated = (char *_Owned)strdup("hello");     // heap copy — must free
```

#### Function pointers
If the C code uses function pointer hooks (e.g. custom allocators), either:
- Remove them and use `malloc`/`free` directly, OR
- Keep them but note that BSC may require `_Unsafe` context for function pointer calls

### Step 6: Handle goto + Ownership Cleanup

C code often uses `goto fail` for error handling. In BSC, `_Owned` variables must be properly consumed on all paths:

```c
// BEFORE (C)
Node *item = create_item();
if (!item) goto fail;
// ... more work ...
return item;
fail:
    free(item);
    return NULL;

// AFTER (BSC) — use _Nullable since item may be NULL at cleanup
Node *_Owned _Nullable item = create_item();
if (item == nullptr) goto fail;
// ... more work ...
return item;  // ownership transfers to caller
fail:
    safe_free((void *_Nullable _Owned)item);
    return nullptr;
```

### Step 7: Compile and Fix

```bash
clang file.cbs -o output
```

BSC compiler will report errors for ownership violations. Fix them iteratively.

## Common Translation Errors (From Real Projects)

These are the most frequent errors when translating C to BSC. Check your translation against each one.

### Error 1: `_Owned` pointer initialized to NULL without `_Nullable`
```c
// WRONG — _Owned is non-nullable by default
cJSON *_Owned root = NULL;

// FIX
cJSON *_Owned _Nullable root = nullptr;
```
**When this happens**: Any `_Owned` local variable that starts as NULL, or any error path that sets an `_Owned` to NULL.

### Error 2: Passing `_Owned` pointer to function expecting raw pointer
```c
// WRONG — internal_func expects raw T*, but item is _Owned
void internal_func(cJSON *item);
cJSON *_Owned item = create_item();
internal_func(item);  // ERROR: ownership mismatch

// FIX Option A: Make the function accept _Owned if it consumes
void internal_func(cJSON *_Owned item);

// FIX Option B: Cast in _Unsafe if function borrows temporarily
_Unsafe { internal_func((cJSON *)item); }

// FIX Option C: Make function accept _Borrow
void internal_func(cJSON *_Borrow item);
```

### Error 3: Assigning `_Owned` return value to raw variable
```c
// WRONG — create returns _Owned, but result is raw
cJSON *result = cJSON_CreateObject();  // ownership leaked

// FIX
cJSON *_Owned result = cJSON_CreateObject();
```

### Error 4: Returning raw pointer from function declared `_Owned` return
```c
// WRONG — returning raw pointer as _Owned
cJSON *_Owned detach_item(cJSON *parent) {
    cJSON *item = parent->child;  // raw pointer from struct field
    return item;  // ERROR: raw → _Owned conversion

// FIX — wrap in _Unsafe for boundary conversion
    _Unsafe { return (cJSON *_Owned)item; }
}
```

### Error 5: Using `NULL` instead of `nullptr` for `_Owned` pointers
```c
// WRONG — NULL is C macro, not BSC-aware
cJSON *_Owned _Nullable item = NULL;

// FIX — use nullptr in BSC
cJSON *_Owned _Nullable item = nullptr;
```

### Error 6: Ownership transfer into container then continued use
```c
// WRONG — after AddItemToObject, item is moved, caller cannot use it
cJSON *_Owned item = cJSON_CreateObject();
cJSON_AddItemToObject(root, "key", item);  // item ownership moved
cJSON_AddStringToObject(item, "name", "val");  // ERROR: use after move

// FIX — get a raw reference before transferring ownership
cJSON *_Owned item = cJSON_CreateObject();
cJSON *ref = item;  // raw alias (borrow)
cJSON_AddItemToObject(root, "key", item);  // item moved
// Use ref (raw pointer) for further modifications — ref is still valid
cJSON_AddStringToObject(ref, "name", "val");  // OK: using raw ref
```

## Checklist — Verify Before Done

- [ ] All files renamed `.c`→`.cbs`, `.h`→`.hbs`
- [ ] All `#include` paths updated
- [ ] `#include "bishengc_safety.hbs"` added where safe_malloc/safe_free are used
- [ ] Platform-specific code stripped
- [ ] **Every pointer analyzed** — classified as owned, borrowed, or raw
- [ ] **Owned struct fields** annotated `*_Owned`
- [ ] **Borrowed struct fields** annotated `*_Borrow`
- [ ] **Interior/arithmetic/iterator pointers** left as raw `T *`
- [ ] **Single-value allocations** converted to `safe_malloc<T>(val)` where possible
- [ ] **Variable-size allocations** (malloc/calloc/strdup/realloc) cast to `T *_Owned` in `_Unsafe`
- [ ] **Every free()** converted to `safe_free((void *_Owned)p)` or `safe_free((void *_Nullable _Owned)p)`
- [ ] **Function parameters** annotated where ownership is clear
- [ ] **Function returns** annotated where ownership is clear
- [ ] **Conditional ownership** patterns handled with `_Unsafe` or restructuring
- [ ] **`_Owned` + NULL**: Every `_Owned` pointer that can be NULL uses `_Nullable` and `nullptr`
- [ ] **No use-after-move**: After passing `_Owned` to a consuming function, only use raw aliases
- [ ] **`goto` cleanup paths**: `_Owned _Nullable` used for variables freed in error handlers
- [ ] **Qualifier placement**: `T *_Owned`, never `_Owned T*`
- [ ] Code compiles with `clang`
