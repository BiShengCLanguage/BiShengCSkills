---
name: bsc-borrowing
description: "BiSheng C borrowing. When you pass pointers without transferring ownership, use &_Const or &_Mut, or design functions that read/mutate without consuming, use this Skill."
---

# BSC Borrowing (Lite)

## 1. Critical Rule

`_Borrow` is a **pointer qualifier**, like `const`. It goes AFTER `*`, never before the type.

```c
int *_Borrow p = &_Mut x;              // CORRECT
_Borrow int* p = ...;                   // WRONG — compile error
```

Pattern: `T *_Borrow`. Never `_Borrow T*`.

## 2. What `_Borrow` Means

- `T *_Borrow` is a pointer that **does NOT own** what it points to.
- Borrows are temporary — the original variable keeps ownership.
- Use borrows when a function needs to read or mutate a value but shouldn't consume it.

## 3. Two Kinds of Borrow

**Immutable borrow** — read-only access:
```c
const int *_Borrow r = &_Const x;    // read-only borrow of x
int y = *r;                           // OK to read
*r = 5;                               // ERROR: can't write through const _Borrow
```

**Mutable borrow** — read/write access:
```c
int *_Borrow m = &_Mut x;             // mutable borrow of x
*m = 5;                               // OK to write
```

Use `&_Const` to create an immutable borrow, `&_Mut` for a mutable one. Never use plain `&` in `_Safe` code.

## 4. The One-Writer-Or-Many-Readers Rule

At any moment, a value can have:
- **Many immutable borrows** (all readers), OR
- **Exactly one mutable borrow** (one writer), OR
- **Neither** (just the owner)

Never both. Never two writers.

```c
int x = 10;
const int *_Borrow r1 = &_Const x;
const int *_Borrow r2 = &_Const x;   // OK: multiple readers
int val = *r1 + *r2;

int *_Borrow w = &_Mut x;             // ERROR: reader r1 still alive
```

Fix: let the immutable borrows end before starting a mutable one.

```c
{
    const int *_Borrow r = &_Const x;
    int val = *r;
}   // r ends here
int *_Borrow w = &_Mut x;             // OK now
*w = 20;
```

## 5. Function Signatures With Borrows

```c
// Read-only function — takes const _Borrow
_Safe size_t string_length(const String *_Borrow s);

// Mutating function — takes mut _Borrow
_Safe void string_append(String *_Borrow s, char c);

// Caller
String s = String::new();
size_t n = string_length(&_Const s);      // immutable borrow
string_append(&_Mut s, 'x');               // mutable borrow
```

## 6. Borrow Lifetime

A borrow must not outlive the value it points to:

```c
// WRONG — returning a borrow to a local
_Safe const int *_Borrow bad(void) {
    int x = 42;
    return &_Const x;   // ERROR: x dies at scope exit
}

// OK — borrow comes from a parameter, lifetime tied to input
_Safe const int *_Borrow get_field(const Node *_Borrow n) {
    return &_Const n->value;
}
```

## 7. Borrowing From `_Owned`

```c
int *_Owned p = safe_malloc<int>(42);
const int *_Borrow r = &_Const *p;     // borrow the pointee
int v = *r;
safe_free((void *_Owned)p);            // borrow r must have ended by now
```

## 8. Nullable Borrows

A `_Borrow` may be nullable if absence is meaningful:

```c
_Safe const T *_Borrow _Nullable find(const Vec<T> *_Borrow v, int key);

const T *_Borrow _Nullable result = find(&_Const v, 42);
if (result != nullptr) {
    use(*result);
}
```

By default `T *_Borrow` is non-null. Add `_Nullable` only when the function genuinely may not find a value.

## 9. Common Mistakes

**Plain `&` in `_Safe` code:**
```c
_Safe void f(void) {
    int x = 1;
    int *p = &x;                 // ERROR: plain & forbidden in _Safe
    int *_Borrow p = &_Mut x;    // OK
}
```

**Overlapping mut borrows:**
```c
int *_Borrow w1 = &_Mut x;
int *_Borrow w2 = &_Mut x;       // ERROR: w1 still live
```

**Outliving the owner:**
```c
const int *_Borrow r;
{
    int local = 5;
    r = &_Const local;            // r borrows local
}
int v = *r;                       // ERROR: local is gone
```

**Mutable borrow while readers live:**
```c
const int *_Borrow r = &_Const x;
int *_Borrow w = &_Mut x;         // ERROR: r still alive
```
