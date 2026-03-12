---
name: bsc-stdlib
description: "BiSheng C standard library (libcbs). When you need to understand Vec<T>, String, LinkedList, Option, Result, Rc, or other safe container types, use this Skill."
---

# BiSheng C Standard Library Skill

## 1. Overview

libcbs provides safe container types with RAII semantics. Include the appropriate `.hbs` header.

## 2. Vec<T> — Dynamic Array

```c
#include "vec.hbs"

Vec<int> v = Vec<int>::new();
Vec<int> v2 = Vec<int>::with_capacity(100);
v.push(42);
v.push(17);
int val = v.pop();                       // returns and removes last
const int *_Borrow ref = v.get(0);       // immutable access by index
int *_Borrow mref = v.get_mut(0);        // mutable access by index
v.set(0, 99);                            // set by index
size_t len = v.length();
_Bool empty = v.is_empty();
size_t cap = v.capacity();
v.clear();
v.shrink_to_fit();
// ~Vec destructor auto-frees memory when v goes out of scope
```

### Vec<T> Methods

| Method | Signature | Description |
|--------|-----------|-------------|
| `new` | `Vec<T>::new()` → `Vec<T>` | Create empty vec |
| `with_capacity` | `Vec<T>::with_capacity(size_t)` → `Vec<T>` | Create with pre-allocated capacity |
| `push` | `v.push(T)` | Append element |
| `pop` | `v.pop()` → `T` | Remove and return last element |
| `get` | `v.get(size_t)` → `const T *_Borrow` | Immutable access |
| `get_mut` | `v.get_mut(size_t)` → `T *_Borrow` | Mutable access |
| `set` | `v.set(size_t, T)` | Set element at index |
| `length` | `v.length()` → `size_t` | Number of elements |
| `capacity` | `v.capacity()` → `size_t` | Allocated capacity |
| `is_empty` | `v.is_empty()` → `_Bool` | Whether vec is empty |
| `clear` | `v.clear()` | Remove all elements |
| `shrink_to_fit` | `v.shrink_to_fit()` | Reduce capacity to length |

## 3. Other Types

```c
#include "string.hbs"     // String type with auto memory management
#include "list.hbs"       // LinkedList<T>
#include "option.hbs"     // Option<T> — some/none
#include "result.hbs"     // Result<T> — ok/err
#include "rc.hbs"         // Rc<T> — reference-counted pointer
```

## 4. Pattern: Safe API with Unsafe Internals

libcbs types follow a consistent pattern:

```c
_Owned struct Vec<T> {
_Public:
    T *ptr;
    size_t len;
    size_t cap;

    ~Vec(Vec<T> this) { /* free ptr */ }
};

// Public API is _Safe with _Borrow params
_Safe void Vec<T>::push(Vec<T> *_Borrow this, T value) {
    _Unsafe { /* realloc, memcpy */ }
}

_Safe const T *_Borrow Vec<T>::get(const Vec<T> *_Borrow this, size_t index) {
    // bounds check, return borrow
}
```

> For ownership/RAII patterns, see `bsc-ownership` Skill
> For borrowing in API design, see `bsc-borrowing` Skill
