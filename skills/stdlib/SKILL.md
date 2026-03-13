---
name: bsc-stdlib
description: "BiSheng C standard library (libcbs). When you need to understand Vec<T>, String, LinkedList, Option, Result, Rc, Weak, Cell, RefCell, Slice, HashMap, safe_malloc, safe_free, safe_swap, forget, or other safe container types, use this Skill."
---

# BiSheng C Standard Library Skill

## 1. Overview

libcbs provides safe container types with RAII semantics. All containers are `_Owned struct` types with automatic destructors. Include the appropriate `.hbs` header.

**Key rule**: Generic containers can only be instantiated with `_Owned struct` or copyable types. If `T` has move semantics but is not an `_Owned struct`, wrap it in one.

## 2. Safety Utilities — `bishengc_safety.hbs`

Core safety primitives used by all other libcbs types.

```c
#include "bishengc_safety.hbs"

// Safe malloc — allocates and initializes with value, returns _Owned pointer
_Safe T *_Owned safe_malloc<T>(T t);

// Safe free — frees a nullable owned pointer
_Safe void safe_free(void * _Nullable _Owned p);

// Safe swap — swaps two borrowed values
_Safe void safe_swap<T>(T* _Borrow left, T* _Borrow right);

// Forget — takes ownership and drops without running destructor
_Safe void forget<T>(T t);
```

### Error Handlers

```c
// Customizable handlers (set your own or use defaults)
extern BSCBadAllocHandler bsc_bad_alloc_handler;      // allocation failure
extern BSCOutOfBoundHandler bsc_out_of_bound_handler;  // index out of bounds
extern BSCOverflowHandler bsc_overflow_handler;        // integer overflow

// Defaults print error + stack trace, then exit
_Noreturn void default_bad_alloc_handler(size_t size);
_Noreturn void default_out_of_bound_handler(size_t len, size_t index);
_Noreturn void default_overflow_handler();
```

### Usage Example

```c
#include "bishengc_safety.hbs"

_Safe void example(void) {
    // Allocate an owned int initialized to 42
    int *_Owned p = safe_malloc<int>(42);

    // Swap two values
    int a = 1;
    int b = 2;
    safe_swap<int>(&_Mut a, &_Mut b);  // a=2, b=1

    // Free owned pointer
    safe_free((void * _Nullable _Owned)p);
}
```

## 3. Vec\<T\> — Dynamic Array

```c
#include "vec.hbs"
```

| Method | Signature | Description |
|--------|-----------|-------------|
| `new` | `Vec<T>::new()` → `Vec<T>` | Create empty vec |
| `with_capacity` | `Vec<T>::with_capacity(size_t)` → `Vec<T>` | Create with pre-allocated capacity |
| `push` | `v.push(T)` | Append element (grows if needed) |
| `pop` | `v.pop()` → `T` | Remove and return last element (aborts if empty) |
| `get` | `v.get(size_t)` → `const T *_Borrow` | Immutable access (aborts if out of bounds) |
| `get_mut` | `v.get_mut(size_t)` → `T *_Borrow` | Mutable access (aborts if out of bounds) |
| `set` | `v.set(size_t, T)` | Set element at index (pushes if index == len) |
| `remove` | `v.remove(size_t)` → `T` | Remove element at index, shift remaining |
| `length` | `v.length()` → `size_t` | Number of elements |
| `capacity` | `v.capacity()` → `size_t` | Allocated capacity |
| `is_empty` | `v.is_empty()` → `_Bool` | Whether vec is empty |
| `clear` | `v.clear()` | Remove all elements (calls destructors) |
| `shrink_to_fit` | `v.shrink_to_fit()` | Reduce capacity to length |

```c
_Safe void vec_example(void) {
    Vec<int> v = Vec<int>::new();
    v.push(42);
    v.push(17);
    const int *_Borrow ref = v.get(0);       // 42
    int val = v.pop();                        // 17
    int removed = v.remove(0);               // 42
    // ~Vec auto-frees when v goes out of scope
}
```

## 4. String

```c
#include "string.hbs"
```

| Method | Signature | Description |
|--------|-----------|-------------|
| `new` | `String::new()` → `String` | Create empty string |
| `with_capacity` | `String::with_capacity(size_t)` → `String` | Create with capacity |
| `from` | `String::from(const char*)` → `String` | **_Unsafe** — create from C string |
| `as_str` | `s.as_str()` → `const char *_Borrow` | Immutable C string view |
| `as_mut_str` | `s.as_mut_str()` → `char *_Borrow` | Mutable C string view |
| `at` | `s.at(size_t)` → `char` | Character at index |
| `get` | `s.get(size_t)` → `const char *_Borrow` | Immutable ref to char at index |
| `get_mut` | `s.get_mut(size_t)` → `char *_Borrow` | Mutable ref to char at index |
| `push` | `s.push(char)` | Append character |
| `set` | `s.set(size_t, char)` | Set character at index |
| `find` | `s.find(char)` → `size_t` | Find first occurrence (returns `bsc_string_no_pos` if not found) |
| `slice` | `s.slice(size_t start, size_t len)` → `String` | Extract substring |
| `equals` | `s.equals(&other)` → `_Bool` | Compare two strings |
| `length` | `s.length()` → `size_t` | String length |
| `capacity` | `s.capacity()` → `size_t` | Allocated capacity |
| `is_empty` | `s.is_empty()` → `_Bool` | Whether string is empty |
| `shrink_to_fit` | `s.shrink_to_fit()` | Reduce capacity |

**Note**: `String::from()` is `_Unsafe` — wrap in `_Unsafe {}` block when used in `_Safe` code.

## 5. LinkedList\<T\>

```c
#include "list.hbs"
```

| Method | Signature | Description |
|--------|-----------|-------------|
| `new` | `LinkedList<T>::new()` → `LinkedList<T>` | Create empty list |
| `push_back` | `l.push_back(T)` | Append to end |
| `push_front` | `l.push_front(T)` | Prepend to front |
| `pop_back` | `l.pop_back()` → `T` | Remove and return last (aborts if empty) |
| `pop_front` | `l.pop_front()` → `T` | Remove and return first (aborts if empty) |
| `front` | `l.front()` → `T` | Return copy of first element |
| `back` | `l.back()` → `T` | Return copy of last element |
| `remove` | `l.remove(T)` | Remove all elements equal to value |
| `split_off` | `l.split_off(size_t)` → `LinkedList<T>` | Split list at index |
| `contains` | `l.contains(T)` → `_Bool` | Check if element exists |
| `length` | `l.length()` → `size_t` | Number of elements |
| `is_empty` | `l.is_empty()` → `_Bool` | Whether list is empty |
| `clear` | `l.clear()` | Remove all elements |

## 6. Option\<T\>

```c
#include "option.hbs"
```

| Method / Function | Signature | Description |
|--------|-----------|-------------|
| `Some` | `Option<T>::Some(T)` → `Option<T>` | Create Some value |
| `None` | `Option<T>::None()` → `Option<T>` | Create None value |
| `is_some` | `o.is_some()` → `_Bool` | Check if Some |
| `is_none` | `o.is_none()` → `_Bool` | Check if None |
| `option_unwrap` | `option_unwrap<T>(Option<T>)` → `T` | Extract value (aborts if None) |

```c
_Safe void option_example(void) {
    Option<int> some = Option<int>::Some(42);
    Option<int> none = Option<int>::None();

    if (some.is_some()) {
        int val = option_unwrap<int>(some);  // 42
    }
    // ~Option auto-destructs
}
```

**Note**: `option_unwrap` is a free function, not a method. It consumes the Option (takes by value).

## 7. Result\<T, E\>

```c
#include "result.hbs"
```

| Method / Function | Signature | Description |
|--------|-----------|-------------|
| `Ok` | `Result<T, E>::Ok(T)` → `Result<T, E>` | Create Ok value |
| `Err` | `Result<T, E>::Err(E)` → `Result<T, E>` | Create Err value |
| `is_ok` | `r.is_ok()` → `_Bool` | Check if Ok |
| `is_err` | `r.is_err()` → `_Bool` | Check if Err |
| `result_unwrap` | `result_unwrap<T, E>(Result<T, E>)` → `T` | Extract Ok value (aborts if Err) |
| `result_unwrap_err` | `result_unwrap_err<T, E>(Result<T, E>)` → `E` | Extract Err value (aborts if Ok) |

```c
_Safe void result_example(void) {
    Result<int, int> ok = Result<int, int>::Ok(42);
    Result<int, int> err = Result<int, int>::Err(-1);

    if (ok.is_ok()) {
        int val = result_unwrap<int, int>(ok);   // 42
    }
    if (err.is_err()) {
        int e = result_unwrap_err<int, int>(err); // -1
    }
}
```

**Note**: `result_unwrap` and `result_unwrap_err` are free functions that consume the Result.

## 8. Rc\<T\> and Weak\<T\> — Reference Counting

```c
#include "rc.hbs"
```

### Rc\<T\> (strong reference)

| Method | Signature | Description |
|--------|-----------|-------------|
| `new` | `Rc<T>::new(T)` → `Rc<T>` | Create new Rc with value |
| `clone` | `rc.clone()` → `Rc<T>` | Increment ref count, return new Rc |
| `deref` | `rc.deref()` → `const T *_Borrow` | Get immutable borrow to inner value |
| `strong_ref_count` | `rc.strong_ref_count()` → `unsigned` | Current strong reference count |
| `weak_ref_count` | `rc.weak_ref_count()` → `unsigned` | Current weak reference count |

### Weak\<T\> (weak reference)

| Method | Signature | Description |
|--------|-----------|-------------|
| `new` | `Weak<T>::new(&rc)` → `Weak<T>` | Create weak ref from Rc |
| `clone` | `w.clone()` → `Weak<T>` | Clone weak reference |
| `upgrade` | `w.upgrade()` → `Option<Rc<T>>` | Try to upgrade to Rc (None if dropped) |
| `strong_ref_count` | `w.strong_ref_count()` → `unsigned` | Strong count (0 if dropped) |
| `weak_ref_count` | `w.weak_ref_count()` → `unsigned` | Weak count |

```c
_Safe void rc_example(void) {
    Rc<int> a = Rc<int>::new(42);
    Rc<int> b = a.clone();                          // strong_count = 2
    const int *_Borrow val = a.deref();             // 42

    Weak<int> w = Weak<int>::new(&_Const a);        // weak_count = 1
    Option<Rc<int>> upgraded = w.upgrade();         // Some(Rc)
    // ~Rc, ~Weak auto-destruct; memory freed when strong_count reaches 0
}
```

## 9. Cell\<T\> and RefCell\<T\> — Interior Mutability

```c
#include "cell.hbs"
```

### Cell\<T\> (copyable types only)

| Method | Signature | Description |
|--------|-----------|-------------|
| `new` | `Cell<T>::new(T)` → `Cell<T>` | Create new Cell |
| `get` | `c.get()` → `T` | Return copy of contained value |
| `set` | `c.set(T)` | Replace contained value |

### RefCell\<T\> (runtime borrow checking)

| Method | Signature | Description |
|--------|-----------|-------------|
| `new` | `RefCell<T>::new(T)` → `RefCell<T>` | Create new RefCell |
| `borrow_immut` | `rc.borrow_immut()` → `RefImmut<T>` | Immutable borrow (aborts if mut-borrowed) |
| `borrow_mut` | `rc.borrow_mut()` → `RefMut<T>` | Mutable borrow (aborts if any borrow active) |
| `try_borrow_immut` | `rc.try_borrow_immut()` → `Option<RefImmut<T>>` | Try immutable borrow |
| `try_borrow_mut` | `rc.try_borrow_mut()` → `Option<RefMut<T>>` | Try mutable borrow |

### RefImmut\<T\> / RefMut\<T\> (RAII borrow guards)

| Method | Signature | Description |
|--------|-----------|-------------|
| `deref` (RefImmut) | `ri.deref()` → `const T *_Borrow` | Get immutable reference |
| `deref` (RefMut) | `rm.deref()` → `T *_Borrow` | Get mutable reference |

Borrow guards automatically release the borrow when they go out of scope.

```c
_Safe void refcell_example(void) {
    RefCell<int> cell = RefCell<int>::new(42);

    // Immutable borrow
    RefImmut<int> ri = cell.borrow_immut();
    const int *_Borrow val = ri.deref();     // 42
    // ~RefImmut releases borrow when ri goes out of scope

    // Mutable borrow (after immutable borrow is released)
    RefMut<int> rm = cell.borrow_mut();
    int *_Borrow mval = rm.deref();
    *mval = 100;
    // ~RefMut releases borrow
}
```

## 10. Slice\<T\> and SliceMut\<T\>

```c
#include "slice.hbs"
```

### Slice\<T\> (immutable view)

| Method | Signature | Description |
|--------|-----------|-------------|
| `new` | `Slice<T>::new(ptr, len)` → `Slice<T>` | **_Unsafe** — create from pointer + length |
| `get` | `s.get(size_t)` → `const T *_Borrow` | Get element (bounds-checked) |
| `sub` | `s.sub(start, end)` → `Slice<T>` | Sub-slice [start, end) |
| `length` | `s.length()` → `size_t` | Number of elements |
| `is_empty` | `s.is_empty()` → `_Bool` | Whether slice is empty |
| `as_ptr` | `s.as_ptr()` → `const T*` | **_Unsafe** — raw pointer |

### SliceMut\<T\> (mutable view)

| Method | Signature | Description |
|--------|-----------|-------------|
| `new` | `SliceMut<T>::new(ptr, len)` → `SliceMut<T>` | **_Unsafe** — create from pointer + length |
| `get` | `s.get(size_t)` → `const T *_Borrow` | Get immutable element |
| `get_mut` | `s.get_mut(size_t)` → `T *_Borrow` | Get mutable element |
| `sub` | `s.sub(start, end)` → `Slice<T>` | Immutable sub-slice |
| `sub_mut` | `s.sub_mut(start, end)` → `SliceMut<T>` | Mutable sub-slice |
| `length` | `s.length()` → `size_t` | Number of elements |
| `is_empty` | `s.is_empty()` → `_Bool` | Whether slice is empty |

## 11. HashMap\<K, V, S\>

```c
#include "hash_map.hbs"
```

| Method | Signature | Description |
|--------|-----------|-------------|
| `with_hasher` | `HashMap<K,V,S>::with_hasher(S)` → `HashMap<K,V,S>` | Create empty with hasher |
| `with_capacity_and_hasher` | `HashMap<K,V,S>::with_capacity_and_hasher(size_t, S)` → `HashMap<K,V,S>` | Create with capacity and hasher |
| `insert` | `m.insert(K, V)` → `Option<V>` | Insert key-value (returns old value if key existed) |
| `get_mut` | `m.get_mut(&k)` → `Option<V *_Borrow>` | Get mutable ref to value |
| `remove` | `m.remove(&k)` → `Option<V>` | Remove key, return value |
| `contains_key` | `m.contains_key(&k)` → `_Bool` | Check if key exists |
| `reserve` | `m.reserve(size_t)` | Reserve additional capacity |
| `length` | `m.length()` → `size_t` | Number of entries |
| `capacity` | `m.capacity()` → `size_t` | Current capacity |
| `is_empty` | `m.is_empty()` → `_Bool` | Whether map is empty |
| `clear` | `m.clear()` | Remove all entries |

**Note**: Keys must implement `hash` and `equals` functions. Built-in types have these pre-implemented.

## 12. Pattern: Safe API with Unsafe Internals

All libcbs types follow a consistent pattern:

```c
_Owned struct MyType<T> {
_Public:
    // ... fields ...

    ~MyType(MyType<T> this) { /* cleanup */ }
};

// Public API is _Safe, takes _Borrow params
_Safe void MyType<T>::method(MyType<T> *_Borrow this, ...) {
    _Unsafe { /* implementation using raw operations */ }
}
```

## 13. Include Summary

| Header | Types Provided |
|--------|---------------|
| `bishengc_safety.hbs` | `safe_malloc<T>`, `safe_free`, `safe_swap<T>`, `forget<T>`, error handlers |
| `vec.hbs` | `Vec<T>` |
| `string.hbs` | `String` |
| `list.hbs` | `LinkedList<T>` |
| `option.hbs` | `Option<T>` |
| `result.hbs` | `Result<T, E>` |
| `rc.hbs` | `Rc<T>`, `Weak<T>` |
| `cell.hbs` | `Cell<T>`, `RefCell<T>`, `RefImmut<T>`, `RefMut<T>` |
| `slice.hbs` | `Slice<T>`, `SliceMut<T>` |
| `hash_map.hbs` | `HashMap<K, V, S>` |

> For ownership/RAII patterns, see `bsc-ownership` Skill
> For borrowing in API design, see `bsc-borrowing` Skill
> For safe zone rules, see `bsc-safe-zone` Skill
