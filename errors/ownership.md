# Ownership Errors (BSC-E01xx)

This document covers all ownership-related diagnostics emitted by the BishengC (BSC) compiler. Ownership errors arise from BSC's `_Owned` pointer system, which tracks heap-memory ownership at compile time. When a pointer is qualified with `_Owned`, the compiler enforces that ownership is transferred exactly once and that memory is freed before the owning variable goes out of scope.

---

## Table of Contents

- [Use Errors](#use-errors)
  - [BSC-E0101 Use of moved value](#bsc-e0101-use-of-moved-value)
  - [BSC-E0102 Use of partially moved value](#bsc-e0102-use-of-partially-moved-value)
  - [BSC-E0103 Use of all moved value](#bsc-e0103-use-of-all-moved-value)
  - [BSC-E0104 Use of uninitialized value](#bsc-e0104-use-of-uninitialized-value)
  - [BSC-E0105 Use of possibly uninitialized value](#bsc-e0105-use-of-possibly-uninitialized-value)
- [Assign Errors](#assign-errors)
  - [BSC-E0106 Assign to _Owned value](#bsc-e0106-assign-to-_owned-value)
  - [BSC-E0107 Assign to partially moved value](#bsc-e0107-assign-to-partially-moved-value)
  - [BSC-E0108 Assign to possibly partially moved value](#bsc-e0108-assign-to-possibly-partially-moved-value)
  - [BSC-E0109 Assign to all moved value](#bsc-e0109-assign-to-all-moved-value)
  - [BSC-E0110 Assign to part of uninitialized value](#bsc-e0110-assign-to-part-of-uninitialized-value)
  - [BSC-E0111 Assign to part of _Owned value](#bsc-e0111-assign-to-part-of-_owned-value)
  - [BSC-E0112 Assign to part of moved value](#bsc-e0112-assign-to-part-of-moved-value)
  - [BSC-E0113 Assign to subfield _Owned value](#bsc-e0113-assign-to-subfield-_owned-value)
- [Cast Errors](#cast-errors)
  - [BSC-E0114 Invalid cast of moved or uninitialized value](#bsc-e0114-invalid-cast-of-moved-or-uninitialized-value)
  - [BSC-E0115 Invalid cast of _Owned value](#bsc-e0115-invalid-cast-of-_owned-value)
  - [BSC-E0116 Invalid cast of uninit value](#bsc-e0116-invalid-cast-of-uninit-value)
  - [BSC-E0117 Invalid cast of not all moved value](#bsc-e0117-invalid-cast-of-not-all-moved-value)
- [Memory Leak Errors](#memory-leak-errors)
  - [BSC-E0118 Memory leak of value](#bsc-e0118-memory-leak-of-value)
  - [BSC-E0119 Field memory leak of value](#bsc-e0119-field-memory-leak-of-value)
  - [BSC-E0120 Partially moved _Owned struct at scope end](#bsc-e0120-partially-moved-_owned-struct-at-scope-end)
  - [BSC-E0121 Destructor for _Owned struct incorrect](#bsc-e0121-destructor-for-_owned-struct-incorrect)
- [Type Qualification Errors](#type-qualification-errors)
  - [BSC-E0122 Declaration cannot be qualified by _Owned](#bsc-e0122-declaration-cannot-be-qualified-by-_owned)
  - [BSC-E0123 Indirect _Owned type check](#bsc-e0123-indirect-_owned-type-check)
  - [BSC-E0124 Incompatible _Owned function pointer cast](#bsc-e0124-incompatible-_owned-function-pointer-cast)
  - [BSC-E0125 Incompatible _Owned types cast](#bsc-e0125-incompatible-_owned-types-cast)
  - [BSC-E0126 Temporary variable memory leak](#bsc-e0126-temporary-variable-memory-leak)
  - [BSC-E0127 Non-pointer type qualified by _Owned](#bsc-e0127-non-pointer-type-qualified-by-_owned)
  - [BSC-E0128 _Owned and _Borrow conflict](#bsc-e0128-_owned-and-_borrow-conflict)
- [Operator Errors on _Owned Types](#operator-errors-on-_owned-types)
  - [BSC-E0129 Invalid binary expression on _Owned types](#bsc-e0129-invalid-binary-expression-on-_owned-types)
  - [BSC-E0130 Invalid unary expression on _Owned types](#bsc-e0130-invalid-unary-expression-on-_owned-types)
  - [BSC-E0131 ArraySubscript on _Owned pointer](#bsc-e0131-arraysubscript-on-_owned-pointer)

---

## Use Errors

These errors occur when an `_Owned` value is used after its ownership has been moved or before it has been initialized.

---

### BSC-E0101 Use of moved value

| | |
|---|---|
| **Diagnostic** | `err_ownership_use_moved` |
| **Flag** | `-Wuse-moved-owned` |
| **Message** | `use of moved value: '%0'` |

**Cause:**
An `_Owned` pointer was used after its ownership was transferred (moved) to another variable or consumed by a function call. Once ownership moves, the source variable becomes invalid and cannot be read, dereferenced, or passed to another function. The compiler tracks these moves and flags any subsequent use of the invalidated variable.

**Bad code:**
```c
void example(void) {
    int *_Owned p = safe_malloc<int>(42);
    int *_Owned q = p;   // ownership moves from p to q
    *p = 10;             // error: use of moved value: `p`
}
```

**Fix strategies:**
- Do not use the variable after moving ownership. Access the data through the new owner instead.
- If you need to use the value in both places, copy the data before moving ownership.
- Restructure the code so the original owner is used before the move occurs.

**Good code:**
```c
void example(void) {
    int *_Owned p = safe_malloc<int>(42);
    *p = 10;             // use p before transferring ownership
    int *_Owned q = p;   // ownership moves from p to q
    free_owned<int>(q);
}
```

**See also:** [BSC-E0102](#bsc-e0102-use-of-partially-moved-value), [BSC-E0104](#bsc-e0104-use-of-uninitialized-value)

---

### BSC-E0102 Use of partially moved value

| | |
|---|---|
| **Diagnostic** | `err_ownership_use_partially_moved` |
| **Flag** | `-Wuse-moved-owned` |
| **Message** | `use of partially moved value: '%0', %1 moved` |

**Cause:**
A struct or composite value containing `_Owned` pointer fields was used after one or more (but not all) of its `_Owned` fields had their ownership moved out. The struct is in a partially valid state: some fields are still owned while others have been invalidated. Using the struct as a whole is not permitted because the moved fields are no longer valid.

**Bad code:**
```c
_Owned struct Pair {
    int *_Owned first;
    int *_Owned second;
};

void example(void) {
    _Owned struct Pair pair;
    pair.first = safe_malloc<int>(1);
    pair.second = safe_malloc<int>(2);
    int *_Owned a = pair.first;   // pair.first is moved
    consume(pair);                // error: use of partially moved value: `pair`, first moved
}
```

**Fix strategies:**
- Do not use the struct as a whole after moving individual fields. Access only the remaining valid fields.
- Reassign a new value to the moved field before using the struct again.
- Move all fields individually instead of using the struct as a whole.

**Good code:**
```c
void example(void) {
    _Owned struct Pair pair;
    pair.first = safe_malloc<int>(1);
    pair.second = safe_malloc<int>(2);
    int *_Owned a = pair.first;        // pair.first is moved
    pair.first = safe_malloc<int>(3);  // reinitialize the moved field
    consume(pair);                     // OK: pair is fully valid again
    free_owned<int>(a);
}
```

**See also:** [BSC-E0101](#bsc-e0101-use-of-moved-value), [BSC-E0103](#bsc-e0103-use-of-all-moved-value)

---

### BSC-E0103 Use of all moved value

| | |
|---|---|
| **Diagnostic** | `err_ownership_use_all_moved` |
| **Flag** | `-Wuse-moved-owned` |
| **Message** | `use of all moved value: '%0'` |

**Cause:**
A struct or composite value was used after all of its `_Owned` fields had their ownership moved out individually. The entire struct is now invalid because every owned field has been transferred elsewhere. This is distinct from a simple move of the struct itself -- here each field was moved separately, leaving the struct completely drained.

**Bad code:**
```c
_Owned struct Pair {
    int *_Owned first;
    int *_Owned second;
};

void example(void) {
    _Owned struct Pair pair;
    pair.first = safe_malloc<int>(1);
    pair.second = safe_malloc<int>(2);
    int *_Owned a = pair.first;
    int *_Owned b = pair.second;
    consume(pair);   // error: use of all moved value: `pair`
}
```

**Fix strategies:**
- Do not use the struct after all fields have been moved out.
- Reassign new values to all moved fields before using the struct again.
- Move the struct as a whole instead of draining individual fields.

**Good code:**
```c
void example(void) {
    _Owned struct Pair pair;
    pair.first = safe_malloc<int>(1);
    pair.second = safe_malloc<int>(2);
    int *_Owned a = pair.first;
    int *_Owned b = pair.second;
    // Use a and b directly instead of pair
    free_owned<int>(a);
    free_owned<int>(b);
}
```

**See also:** [BSC-E0101](#bsc-e0101-use-of-moved-value), [BSC-E0102](#bsc-e0102-use-of-partially-moved-value)

---

### BSC-E0104 Use of uninitialized value

| | |
|---|---|
| **Diagnostic** | `err_ownership_use_uninit` |
| **Flag** | `-Wuse-uninit-owned` |
| **Message** | `use of uninitialized value: '%0'` |

**Cause:**
An `_Owned` pointer variable was used before any value was assigned to it. Unlike regular C pointers where reading an uninitialized variable is merely undefined behavior, BSC treats this as a hard error for `_Owned` pointers. The compiler requires every `_Owned` variable to be definitively initialized before use to prevent double-free or use-after-free scenarios.

**Bad code:**
```c
void example(void) {
    int *_Owned p;
    *p = 42;       // error: use of uninitialized value: `p`
}
```

**Fix strategies:**
- Initialize the `_Owned` pointer at declaration using `safe_malloc` or another allocating function.
- Assign a value to the pointer before using it.
- If the pointer may not need allocation in all paths, initialize it to a known value and check before use.

**Good code:**
```c
void example(void) {
    int *_Owned p = safe_malloc<int>(0);
    *p = 42;       // OK: p is initialized
    free_owned<int>(p);
}
```

**See also:** [BSC-E0105](#bsc-e0105-use-of-possibly-uninitialized-value), [BSC-E0101](#bsc-e0101-use-of-moved-value)

---

### BSC-E0105 Use of possibly uninitialized value

| | |
|---|---|
| **Diagnostic** | `err_ownership_use_possibly_uninit` |
| **Flag** | `-Wuse-uninit-owned` |
| **Message** | `use of possibly uninitialized value: '%0'` |

**Cause:**
An `_Owned` pointer was used on a code path where it might not have been initialized. This typically happens when the variable is initialized inside a conditional branch but used unconditionally afterward. The compiler performs flow-sensitive analysis and detects that at least one execution path reaches the use without a prior initialization.

**Bad code:**
```c
void example(int cond) {
    int *_Owned p;
    if (cond) {
        p = safe_malloc<int>(42);
    }
    free_owned<int>(p);   // error: use of possibly uninitialized value: `p`
}
```

**Fix strategies:**
- Ensure all code paths initialize the variable before use.
- Move the use inside the branch where the variable is known to be initialized.
- Initialize the variable at its declaration point.

**Good code:**
```c
void example(int cond) {
    int *_Owned p;
    if (cond) {
        p = safe_malloc<int>(42);
    } else {
        p = safe_malloc<int>(0);
    }
    free_owned<int>(p);   // OK: p is initialized on all paths
}
```

**See also:** [BSC-E0104](#bsc-e0104-use-of-uninitialized-value)

---

## Assign Errors

These errors occur when an `_Owned` value is assigned to in a way that would leak memory or produce an inconsistent ownership state.

---

### BSC-E0106 Assign to _Owned value

| | |
|---|---|
| **Diagnostic** | `err_ownership_assign_owned` |
| **Flag** | `-Wassign-owned` |
| **Message** | `assign to _Owned value: '%0'` |

**Cause:**
A new value was assigned to an `_Owned` pointer that already owns allocated memory. This would silently leak the previously owned memory because the old pointer value is overwritten without being freed first. BSC requires that the current ownership be released (via `free_owned` or a move) before a new value can be assigned.

**Bad code:**
```c
void example(void) {
    int *_Owned p = safe_malloc<int>(1);
    p = safe_malloc<int>(2);   // error: assign to _Owned value: `p`
}
```

**Fix strategies:**
- Free the current value before assigning a new one.
- Move the current value to another variable before reassignment.
- Restructure the code to avoid reassigning `_Owned` pointers.

**Good code:**
```c
void example(void) {
    int *_Owned p = safe_malloc<int>(1);
    free_owned<int>(p);        // release current ownership
    p = safe_malloc<int>(2);   // OK: p was freed first
    free_owned<int>(p);
}
```

**See also:** [BSC-E0118](#bsc-e0118-memory-leak-of-value), [BSC-E0111](#bsc-e0111-assign-to-part-of-_owned-value)

---

### BSC-E0107 Assign to partially moved value

| | |
|---|---|
| **Diagnostic** | `err_ownership_assign_partially_moved` |
| **Flag** | `-Wassign-moved-owned` |
| **Message** | `assign to partially moved value: '%0', %1 moved` |

**Cause:**
A whole-struct assignment was attempted on an `_Owned` struct where some fields have been moved out but others still hold ownership. Overwriting the entire struct would leak the memory owned by the fields that were not moved. The compiler requires that the struct be in a consistent state (either fully owned or fully moved/freed) before a whole-struct assignment.

**Bad code:**
```c
_Owned struct Pair {
    int *_Owned first;
    int *_Owned second;
};

void example(void) {
    _Owned struct Pair pair;
    pair.first = safe_malloc<int>(1);
    pair.second = safe_malloc<int>(2);
    int *_Owned a = pair.first;   // pair.first moved
    pair = make_pair();           // error: assign to partially moved value: `pair`, first moved
}
```

**Fix strategies:**
- Free the remaining owned fields before reassigning the struct.
- Move the remaining fields out before reassigning the struct.
- Avoid partial moves by moving or freeing the entire struct at once.

**Good code:**
```c
void example(void) {
    _Owned struct Pair pair;
    pair.first = safe_malloc<int>(1);
    pair.second = safe_malloc<int>(2);
    int *_Owned a = pair.first;
    free_owned<int>(pair.second);  // free remaining field
    pair = make_pair();            // OK: no owned fields remain
    // ... use pair ...
    free_owned<int>(a);
}
```

**See also:** [BSC-E0106](#bsc-e0106-assign-to-_owned-value), [BSC-E0108](#bsc-e0108-assign-to-possibly-partially-moved-value)

---

### BSC-E0108 Assign to possibly partially moved value

| | |
|---|---|
| **Diagnostic** | `err_ownership_assign_possibly_partially_moved` |
| **Flag** | `-Wassign-moved-owned` |
| **Message** | `assign to possibly partially moved value: '%0', %1 possibly moved` |

**Cause:**
A whole-struct assignment was attempted on an `_Owned` struct where some fields may or may not have been moved out depending on the control flow. The compiler cannot guarantee that the struct is in a consistent state at the assignment point, because some execution paths move a field while others do not. This ambiguity makes it impossible to determine whether the assignment would leak memory.

**Bad code:**
```c
_Owned struct Pair {
    int *_Owned first;
    int *_Owned second;
};

void example(int cond) {
    _Owned struct Pair pair;
    pair.first = safe_malloc<int>(1);
    pair.second = safe_malloc<int>(2);
    if (cond) {
        int *_Owned a = pair.first;   // pair.first moved on this path
        free_owned<int>(a);
    }
    pair = make_pair();   // error: assign to possibly partially moved value: `pair`, first possibly moved
}
```

**Fix strategies:**
- Ensure the struct is in the same ownership state on all paths before the assignment.
- Move or free the same fields on every branch so the struct reaches a consistent state.
- Restructure the code to avoid conditionally moving individual fields.

**Good code:**
```c
void example(int cond) {
    _Owned struct Pair pair;
    pair.first = safe_malloc<int>(1);
    pair.second = safe_malloc<int>(2);
    // Free both fields unconditionally
    free_owned<int>(pair.first);
    free_owned<int>(pair.second);
    pair = make_pair();   // OK: all fields freed on all paths
}
```

**See also:** [BSC-E0107](#bsc-e0107-assign-to-partially-moved-value)

---

### BSC-E0109 Assign to all moved value

| | |
|---|---|
| **Diagnostic** | `err_ownership_assign_all_moved` |
| **Flag** | `-Wassign-moved-owned` |
| **Message** | `assign to all moved value: '%0'` |

**Cause:**
A whole-struct assignment was attempted on an `_Owned` struct where all `_Owned` fields have been individually moved out. While this might seem safe (no memory would leak), BSC still flags this because the struct was drained field-by-field rather than moved as a whole unit. The compiler treats an all-moved struct as being in an invalid state that requires explicit reinitialization through field-by-field assignment rather than whole-struct assignment.

**Bad code:**
```c
_Owned struct Pair {
    int *_Owned first;
    int *_Owned second;
};

void example(void) {
    _Owned struct Pair pair;
    pair.first = safe_malloc<int>(1);
    pair.second = safe_malloc<int>(2);
    int *_Owned a = pair.first;
    int *_Owned b = pair.second;
    pair = make_pair();   // error: assign to all moved value: `pair`
}
```

**Fix strategies:**
- Reinitialize the struct field by field instead of using whole-struct assignment.
- Move or free the struct as a whole instead of draining individual fields.
- Use a new variable for the new struct value.

**Good code:**
```c
void example(void) {
    _Owned struct Pair pair;
    pair.first = safe_malloc<int>(1);
    pair.second = safe_malloc<int>(2);
    int *_Owned a = pair.first;
    int *_Owned b = pair.second;
    // Reinitialize field by field
    pair.first = safe_malloc<int>(3);
    pair.second = safe_malloc<int>(4);
    // ... use pair, a, b ...
    free_owned<int>(a);
    free_owned<int>(b);
}
```

**See also:** [BSC-E0107](#bsc-e0107-assign-to-partially-moved-value), [BSC-E0103](#bsc-e0103-use-of-all-moved-value)

---

### BSC-E0110 Assign to part of uninitialized value

| | |
|---|---|
| **Diagnostic** | `err_ownership_assign_field_uninit` |
| **Flag** | `-Wassign-uninit-owned` |
| **Message** | `assign to part of uninitialized value: '%0'` |

**Cause:**
An assignment was made to a field of an `_Owned` struct that has not been initialized at all. BSC requires that the struct variable itself be in a known state before individual fields can be assigned. Assigning to a single field of a completely uninitialized struct leaves other fields in an indeterminate state, which can lead to double-free or leak issues when the struct goes out of scope.

**Bad code:**
```c
_Owned struct Pair {
    int *_Owned first;
    int *_Owned second;
};

void example(void) {
    _Owned struct Pair pair;
    // pair is completely uninitialized
    pair.first = safe_malloc<int>(1);   // error: assign to part of uninitialized value: `pair`
}
```

**Fix strategies:**
- Initialize the entire struct before assigning to individual fields (e.g., zero-initialize or use a constructor).
- Assign all fields of the struct together at declaration time.
- Use a factory function that returns a fully initialized struct.

**Good code:**
```c
void example(void) {
    _Owned struct Pair pair = { .first = safe_malloc<int>(1), .second = safe_malloc<int>(2) };
    // Now pair is fully initialized
    free_owned<int>(pair.first);
    free_owned<int>(pair.second);
}
```

**See also:** [BSC-E0104](#bsc-e0104-use-of-uninitialized-value), [BSC-E0111](#bsc-e0111-assign-to-part-of-_owned-value)

---

### BSC-E0111 Assign to part of _Owned value

| | |
|---|---|
| **Diagnostic** | `err_ownership_assign_field_owned` |
| **Flag** | `-Wassign-owned` |
| **Message** | `assign to part of _Owned value: '%0'` |

**Cause:**
An assignment was made to a field of an `_Owned` struct when that field already holds an owned value. Overwriting the field would leak the memory it currently owns. Just as with reassigning a top-level `_Owned` pointer, BSC requires the field's current value to be freed or moved before a new value can be assigned to it.

**Bad code:**
```c
_Owned struct Pair {
    int *_Owned first;
    int *_Owned second;
};

void example(void) {
    _Owned struct Pair pair = { .first = safe_malloc<int>(1), .second = safe_malloc<int>(2) };
    pair.first = safe_malloc<int>(3);   // error: assign to part of _Owned value: `pair`
}
```

**Fix strategies:**
- Free the field's current value before assigning a new one.
- Move the field's value to another variable before reassignment.

**Good code:**
```c
void example(void) {
    _Owned struct Pair pair = { .first = safe_malloc<int>(1), .second = safe_malloc<int>(2) };
    free_owned<int>(pair.first);        // free the current value first
    pair.first = safe_malloc<int>(3);   // OK: field was freed
    free_owned<int>(pair.first);
    free_owned<int>(pair.second);
}
```

**See also:** [BSC-E0106](#bsc-e0106-assign-to-_owned-value), [BSC-E0113](#bsc-e0113-assign-to-subfield-_owned-value)

---

### BSC-E0112 Assign to part of moved value

| | |
|---|---|
| **Diagnostic** | `err_ownership_assign_field_moved` |
| **Flag** | `-Wassign-moved-owned` |
| **Message** | `assign to part of moved value: '%0'` |

**Cause:**
An assignment was made to a field of an `_Owned` struct whose ownership has been moved as a whole. Once the entire struct has been moved to another variable or consumed by a function, the original variable is invalid. Assigning to a field of a moved struct is not permitted because the struct itself no longer exists as a valid entity in the current scope.

**Bad code:**
```c
_Owned struct Pair {
    int *_Owned first;
    int *_Owned second;
};

void example(void) {
    _Owned struct Pair pair = { .first = safe_malloc<int>(1), .second = safe_malloc<int>(2) };
    consume(pair);                       // pair is moved
    pair.first = safe_malloc<int>(3);    // error: assign to part of moved value: `pair`
}
```

**Fix strategies:**
- Do not access the struct after moving it. Create a new struct variable instead.
- Reinitialize the entire struct before assigning to its fields.

**Good code:**
```c
void example(void) {
    _Owned struct Pair pair = { .first = safe_malloc<int>(1), .second = safe_malloc<int>(2) };
    consume(pair);    // pair is moved
    // Create a fresh struct instead
    _Owned struct Pair pair2 = { .first = safe_malloc<int>(3), .second = safe_malloc<int>(4) };
    consume(pair2);
}
```

**See also:** [BSC-E0101](#bsc-e0101-use-of-moved-value), [BSC-E0110](#bsc-e0110-assign-to-part-of-uninitialized-value)

---

### BSC-E0113 Assign to subfield _Owned value

| | |
|---|---|
| **Diagnostic** | `err_ownership_assign_field_subfield_owned` |
| **Flag** | `-Wassign-owned` |
| **Message** | `assign to subfield _Owned value: '%0', %1 _Owned` |

**Cause:**
An assignment was attempted to a nested field (subfield) of an `_Owned` struct where the subfield or its parent still holds an owned value. This is the nested variant of BSC-E0111: when structs contain other structs with `_Owned` fields, the ownership tracking extends transitively. Overwriting a subfield that still owns memory would leak that memory.

**Bad code:**
```c
_Owned struct Inner {
    int *_Owned data;
};

_Owned struct Outer {
    _Owned struct Inner inner;
    int *_Owned other;
};

void example(void) {
    _Owned struct Outer obj = { .inner = { .data = safe_malloc<int>(1) }, .other = safe_malloc<int>(2) };
    obj.inner.data = safe_malloc<int>(3);   // error: assign to subfield _Owned value: `obj`, inner.data _Owned
}
```

**Fix strategies:**
- Free the subfield's current value before assigning a new one.
- Move the subfield's value out before reassignment.

**Good code:**
```c
void example(void) {
    _Owned struct Outer obj = { .inner = { .data = safe_malloc<int>(1) }, .other = safe_malloc<int>(2) };
    free_owned<int>(obj.inner.data);         // free current subfield value
    obj.inner.data = safe_malloc<int>(3);    // OK: subfield was freed
    free_owned<int>(obj.inner.data);
    free_owned<int>(obj.other);
}
```

**See also:** [BSC-E0111](#bsc-e0111-assign-to-part-of-_owned-value), [BSC-E0106](#bsc-e0106-assign-to-_owned-value)

---

## Cast Errors

These errors occur when `_Owned` pointers are cast to `void *_Owned` in an invalid ownership state.

---

### BSC-E0114 Invalid cast of moved or uninitialized value

| | |
|---|---|
| **Diagnostic** | `err_ownership_cast_moved` |
| **Flag** | `-Wcast-moved-owned` |
| **Message** | `invalid cast to 'void * _Owned' of moved or uninitialized value: '%0'` |

**Cause:**
A cast to `void *_Owned` was attempted on a variable whose ownership has already been moved or that was never initialized. Casting a moved or uninitialized pointer to `void *_Owned` would create a dangling owned pointer, because the underlying memory is either owned elsewhere or does not exist. This would lead to double-free or use-after-free bugs.

**Bad code:**
```c
void example(void) {
    int *_Owned p = safe_malloc<int>(1);
    int *_Owned q = p;                   // p is moved
    void *_Owned v = (void *_Owned)p;    // error: invalid cast to `void * _Owned` of moved or uninitialized value: `p`
}
```

**Fix strategies:**
- Cast the pointer before moving its ownership.
- Cast the new owner instead of the moved variable.
- Ensure the variable is initialized before casting.

**Good code:**
```c
void example(void) {
    int *_Owned p = safe_malloc<int>(1);
    void *_Owned v = (void *_Owned)p;    // OK: p still owns memory
    free_owned<void>(v);
}
```

**See also:** [BSC-E0115](#bsc-e0115-invalid-cast-of-_owned-value), [BSC-E0101](#bsc-e0101-use-of-moved-value)

---

### BSC-E0115 Invalid cast of _Owned value

| | |
|---|---|
| **Diagnostic** | `err_ownership_cast_owned` |
| **Flag** | `-Wcast-owned` |
| **Message** | `invalid cast to 'void * _Owned' of _Owned value: '%0'` |

**Cause:**
A cast to `void *_Owned` was attempted on a variable that currently owns memory. This cast would create a second `_Owned` reference to the same memory, violating the single-ownership invariant. The original variable would still appear to own the memory, leading to potential double-free when both the original and the cast result are freed.

**Bad code:**
```c
void example(void) {
    int *_Owned p = safe_malloc<int>(42);
    void *_Owned v = (void *_Owned)p;    // error: invalid cast to `void * _Owned` of _Owned value: `p`
    free_owned<int>(p);
    free_owned<void>(v);                 // would be double-free
}
```

**Fix strategies:**
- Move ownership through the cast instead of duplicating it (use a move-cast idiom).
- Free the original before casting, or do not use the original after the cast.
- Restructure the code to avoid casting between owned pointer types.

**Good code:**
```c
void example(void) {
    int *_Owned p = safe_malloc<int>(42);
    void *_Owned v = (void *_Owned)p;    // ownership transfers through the cast
    // Do not use p after this point
    free_owned<void>(v);
}
```

**See also:** [BSC-E0114](#bsc-e0114-invalid-cast-of-moved-or-uninitialized-value), [BSC-E0117](#bsc-e0117-invalid-cast-of-not-all-moved-value)

---

### BSC-E0116 Invalid cast of uninit value

| | |
|---|---|
| **Diagnostic** | `err_ownership_cast_uninit` |
| **Flag** | `-Wcast-owned` |
| **Message** | `invalid cast to 'void * _Owned' of uninit value: '%0'` |

**Cause:**
A cast to `void *_Owned` was attempted on a variable that has never been initialized. The pointer contains an indeterminate value, and casting it to `void *_Owned` would create an owned pointer pointing to arbitrary memory. Any subsequent operation on this pointer (dereference, free) would cause undefined behavior.

**Bad code:**
```c
void example(void) {
    int *_Owned p;
    void *_Owned v = (void *_Owned)p;    // error: invalid cast to `void * _Owned` of uninit value: `p`
}
```

**Fix strategies:**
- Initialize the pointer before casting it.
- Remove the cast if the variable is not needed.

**Good code:**
```c
void example(void) {
    int *_Owned p = safe_malloc<int>(42);
    void *_Owned v = (void *_Owned)p;    // OK: p is initialized
    free_owned<void>(v);
}
```

**See also:** [BSC-E0114](#bsc-e0114-invalid-cast-of-moved-or-uninitialized-value), [BSC-E0104](#bsc-e0104-use-of-uninitialized-value)

---

### BSC-E0117 Invalid cast of not all moved value

| | |
|---|---|
| **Diagnostic** | `err_ownership_cast_subfield_owned` |
| **Flag** | `-Wcast-owned` |
| **Message** | `invalid cast to 'void * _Owned' of not all moved value: '%0', %1 _Owned` |

**Cause:**
A cast to `void *_Owned` was attempted on an `_Owned` struct pointer where some fields have been moved but others still hold ownership. Casting the struct pointer to `void *_Owned` in this inconsistent state is not permitted because it is unclear whether the cast should transfer ownership of the remaining fields. The struct must be in a fully owned or fully moved state for a safe cast.

**Bad code:**
```c
_Owned struct Pair {
    int *_Owned first;
    int *_Owned second;
};

void example(void) {
    _Owned struct Pair *_Owned pp = safe_malloc<_Owned struct Pair>((struct Pair){0});
    int *_Owned a = pp->first;                  // first is moved
    void *_Owned v = (void *_Owned)pp;          // error: invalid cast to `void * _Owned` of not all moved value: `pp`, second _Owned
}
```

**Fix strategies:**
- Free or move all remaining owned fields before casting.
- Restore moved fields so the struct is fully owned before casting.
- Avoid partial moves before casting to `void *_Owned`.

**Good code:**
```c
void example(void) {
    _Owned struct Pair *_Owned pp = safe_malloc<_Owned struct Pair>((struct Pair){0});
    pp->first = safe_malloc<int>(1);
    pp->second = safe_malloc<int>(2);
    // Cast while fully owned
    void *_Owned v = (void *_Owned)pp;
    free_owned<void>(v);
}
```

**See also:** [BSC-E0115](#bsc-e0115-invalid-cast-of-_owned-value), [BSC-E0102](#bsc-e0102-use-of-partially-moved-value)

---

## Memory Leak Errors

These errors occur when `_Owned` memory is not properly freed before going out of scope.

---

### BSC-E0118 Memory leak of value

| | |
|---|---|
| **Diagnostic** | `err_ownership_memory_leak` |
| **Flag** | `-Wcheck-memory-leak` |
| **Message** | `memory leak of value: '%0'` |

**Cause:**
An `_Owned` pointer variable goes out of scope while still owning heap memory. BSC requires that all `_Owned` pointers be either freed or moved before the end of their scope. If the pointer is not explicitly handled, the allocated memory is leaked. This is one of the most fundamental ownership errors and directly corresponds to a memory leak bug.

**Bad code:**
```c
void example(void) {
    int *_Owned p = safe_malloc<int>(42);
    // p goes out of scope without being freed or moved
}   // error: memory leak of value: `p`
```

**Fix strategies:**
- Call `free_owned` on the pointer before the end of the scope.
- Move ownership to another variable or pass it to a consuming function.
- Return the owned pointer from the function to transfer ownership to the caller.

**Good code:**
```c
void example(void) {
    int *_Owned p = safe_malloc<int>(42);
    free_owned<int>(p);   // OK: ownership released
}
```

**See also:** [BSC-E0119](#bsc-e0119-field-memory-leak-of-value), [BSC-E0106](#bsc-e0106-assign-to-_owned-value)

---

### BSC-E0119 Field memory leak of value

| | |
|---|---|
| **Diagnostic** | `err_ownership_memory_leak_field` |
| **Flag** | `-Wcheck-memory-leak` |
| **Message** | `field memory leak of value: '%0', %1 leak` |

**Cause:**
An `_Owned` struct goes out of scope while one or more of its `_Owned` fields still own heap memory. Even if the struct itself was handled (e.g., some fields were moved), the remaining fields still hold allocations that are not freed. Each `_Owned` field in a struct must be individually freed or moved before the struct goes out of scope.

**Bad code:**
```c
_Owned struct Pair {
    int *_Owned first;
    int *_Owned second;
};

void example(void) {
    _Owned struct Pair pair = { .first = safe_malloc<int>(1), .second = safe_malloc<int>(2) };
    free_owned<int>(pair.first);
    // pair.second is not freed
}   // error: field memory leak of value: `pair`, second leak
```

**Fix strategies:**
- Free all `_Owned` fields before the struct goes out of scope.
- Move the entire struct to a consuming function that handles all fields.
- Use the struct's destructor if one is defined.

**Good code:**
```c
void example(void) {
    _Owned struct Pair pair = { .first = safe_malloc<int>(1), .second = safe_malloc<int>(2) };
    free_owned<int>(pair.first);
    free_owned<int>(pair.second);   // free all fields
}
```

**See also:** [BSC-E0118](#bsc-e0118-memory-leak-of-value), [BSC-E0120](#bsc-e0120-partially-moved-_owned-struct-at-scope-end)

---

### BSC-E0120 Partially moved _Owned struct at scope end

| | |
|---|---|
| **Diagnostic** | `err_ownership_owned_struct_patially_moved` |
| **Flag** | `-Wpartially-moved-struct` |
| **Message** | `partially moved _Owned struct:'%0' at scope end, %1 moved` |

**Cause:**
An `_Owned` struct reached the end of its scope in a partially moved state: some fields had their ownership transferred while others were not freed or moved. This is related to but distinct from BSC-E0119. The compiler specifically flags that the struct is in an inconsistent state at scope end, meaning neither a full free nor a full move was performed. The unmoved fields leak and the struct is left in an invalid intermediate state.

**Bad code:**
```c
_Owned struct Pair {
    int *_Owned first;
    int *_Owned second;
};

void example(void) {
    _Owned struct Pair pair = { .first = safe_malloc<int>(1), .second = safe_malloc<int>(2) };
    int *_Owned a = pair.first;   // first is moved out
    free_owned<int>(a);
    // pair.second still owned, pair.first moved
}   // error: partially moved _Owned struct:`pair` at scope end, first moved
```

**Fix strategies:**
- Free or move all remaining fields before the scope ends.
- Move the entire struct as a unit instead of moving individual fields.
- Use a destructor to handle cleanup of all fields.

**Good code:**
```c
void example(void) {
    _Owned struct Pair pair = { .first = safe_malloc<int>(1), .second = safe_malloc<int>(2) };
    int *_Owned a = pair.first;
    free_owned<int>(a);
    free_owned<int>(pair.second);   // free the remaining field too
}
```

**See also:** [BSC-E0119](#bsc-e0119-field-memory-leak-of-value), [BSC-E0102](#bsc-e0102-use-of-partially-moved-value)

---

### BSC-E0121 Destructor for _Owned struct incorrect

| | |
|---|---|
| **Diagnostic** | `err_ownership_owned_struct_not_properly_freed` |
| **Flag** | `-Wdestruct-owned-struct` |
| **Message** | `destructor for'%0' incorrect, %1 of _Owned type and needs to be handled manually` |

**Cause:**
The destructor defined for an `_Owned` struct does not properly handle all of the struct's `_Owned` fields. BSC verifies that destructors free or move every `_Owned` field in the struct. If any `_Owned` field is not explicitly handled within the destructor body, the compiler reports this error because those fields would leak when the destructor is called.

**Bad code:**
```c
_Owned struct Pair {
    int *_Owned first;
    int *_Owned second;

    void ~Pair(Pair this) {
        free_owned<int>(this.first);
        // forgot to free this.second
    }
};
// error: destructor for`Pair` incorrect, second of _Owned type and needs to be handled manually
```

**Fix strategies:**
- Ensure the destructor frees or moves every `_Owned` field.
- Review the struct definition for any newly added `_Owned` fields that the destructor does not handle.

**Good code:**
```c
_Owned struct Pair {
    int *_Owned first;
    int *_Owned second;

    void ~Pair(Pair this) {
        free_owned<int>(this.first);
        free_owned<int>(this.second);   // handle all _Owned fields
    }
};
```

**See also:** [BSC-E0118](#bsc-e0118-memory-leak-of-value), [BSC-E0119](#bsc-e0119-field-memory-leak-of-value)

---

## Type Qualification Errors

These errors occur when the `_Owned` qualifier is applied incorrectly or when incompatible `_Owned` types are mixed.

---

### BSC-E0122 Declaration cannot be qualified by _Owned

| | |
|---|---|
| **Diagnostic** | `err_owned_decl` |
| **Flag** | (hard error, no flag) |
| **Message** | `%0 cannot be qualified by '_Owned'` |

**Cause:**
The `_Owned` qualifier was applied to a declaration that does not support ownership semantics. Not all declarations can be qualified with `_Owned`. For example, function declarations, typedef names, or certain storage classes may not be compatible with ownership tracking. The `_Owned` qualifier is only meaningful on pointer types that represent heap-allocated memory.

**Bad code:**
```c
_Owned int x = 42;           // error: x cannot be qualified by '_Owned'
_Owned void func(void);      // error: func cannot be qualified by '_Owned'
```

**Fix strategies:**
- Apply `_Owned` only to pointer types that represent owned heap memory.
- Remove the `_Owned` qualifier from non-pointer declarations.

**Good code:**
```c
int x = 42;
int *_Owned p = safe_malloc<int>(42);   // OK: _Owned on a pointer type
free_owned<int>(p);
```

**See also:** [BSC-E0127](#bsc-e0127-non-pointer-type-qualified-by-_owned), [BSC-E0128](#bsc-e0128-_owned-and-_borrow-conflict)

---

### BSC-E0123 Indirect _Owned type check

| | |
|---|---|
| **Diagnostic** | `err_owned_inderictOwned_type_check` |
| **Flag** | (hard error, no flag) |
| **Message** | (multi-select) `type of %2 cannot qualified by '%1'` / `type of %2 cannot qualified by '%1', %3 contains '%1' type` / `type of %2 cannot qualified by '%1'(even indirectly), %3 contains '%1' type` |

**Cause:**
The compiler detected that a type is being qualified with `_Owned` (or contains `_Owned` indirectly through nested types) in a context where this is not allowed. BSC performs deep type inspection and tracks `_Owned` qualifiers through nested structs, typedefs, and pointer chains. If an `_Owned` type appears at a nesting level where ownership cannot be properly tracked, this error is emitted. The three message variants correspond to: direct qualification error, direct containment of `_Owned`, and indirect (transitive) containment of `_Owned`.

**Bad code:**
```c
// Suppose Container has an _Owned field
struct Container {
    int *_Owned data;
};

void func(struct Container c);   // error: type of c cannot qualified by '_Owned', data contains '_Owned' type
```

**Fix strategies:**
- Use pointer-to-struct parameters when the struct contains `_Owned` fields, so ownership can be properly tracked.
- Remove `_Owned` fields from the struct if ownership tracking is not needed.
- Restructure the type hierarchy to avoid indirect `_Owned` containment where it is not supported.

**Good code:**
```c
struct Container {
    int *_Owned data;
};

void func(struct Container *_Owned c) {   // OK: pass by owned pointer
    free_owned<int>(c->data);
    free_owned<struct Container>(c);
}
```

**See also:** [BSC-E0122](#bsc-e0122-declaration-cannot-be-qualified-by-_owned), [BSC-E0127](#bsc-e0127-non-pointer-type-qualified-by-_owned)

---

### BSC-E0124 Incompatible _Owned function pointer cast

| | |
|---|---|
| **Diagnostic** | `err_owned_funcPtr_incompatible` |
| **Flag** | (hard error, no flag) |
| **Message** | `cannot cast %0 to %1` |

**Cause:**
A function pointer cast was attempted between two function pointer types that have incompatible `_Owned` qualifiers in their parameter or return types. Function pointer casts that change ownership semantics are dangerous because the caller and callee would disagree about who owns the memory. For example, casting a function that takes a non-owned pointer to one that takes an `_Owned` pointer could lead to double-free or leak.

**Bad code:**
```c
typedef void (*FreeFunc)(int *_Owned);
typedef void (*PlainFunc)(int *);

void my_func(int *p) { /* ... */ }

void example(void) {
    FreeFunc f = (FreeFunc)my_func;   // error: cannot cast void (*)(int *) to void (*)(int *_Owned)
}
```

**Fix strategies:**
- Ensure both function pointer types have matching `_Owned` qualifiers.
- Change the source function's signature to match the target function pointer type.
- Use a wrapper function with the correct signature.

**Good code:**
```c
typedef void (*FreeFunc)(int *_Owned);

void my_func(int *_Owned p) {
    free_owned<int>(p);
}

void example(void) {
    FreeFunc f = my_func;   // OK: signatures match
}
```

**See also:** [BSC-E0125](#bsc-e0125-incompatible-_owned-types-cast)

---

### BSC-E0125 Incompatible _Owned types cast

| | |
|---|---|
| **Diagnostic** | `err_owned_qualcheck_incompatible` |
| **Flag** | (hard error, no flag) |
| **Message** | `incompatible _Owned types, cannot cast %0 to %1` |

**Cause:**
A cast was attempted between two pointer types with incompatible `_Owned` qualifications. BSC enforces that casts preserve ownership semantics: you cannot cast a non-owned pointer to an `_Owned` pointer (which would fabricate ownership) or cast an `_Owned` pointer to a non-owned pointer (which would silently discard ownership and leak memory). Only compatible ownership-preserving casts are allowed.

**Bad code:**
```c
void example(void) {
    int *p = (int *)malloc(sizeof(int));
    int *_Owned q = (int *_Owned)p;   // error: incompatible _Owned types, cannot cast int * to int *_Owned
}
```

**Fix strategies:**
- Use `safe_malloc` instead of `malloc` to produce `_Owned` pointers directly.
- Ensure both sides of the cast have matching `_Owned` qualifications.
- If interfacing with non-BSC code, use the appropriate BSC wrapper functions.

**Good code:**
```c
void example(void) {
    int *_Owned p = safe_malloc<int>(0);   // OK: safe_malloc returns _Owned
    free_owned<int>(p);
}
```

**See also:** [BSC-E0124](#bsc-e0124-incompatible-_owned-function-pointer-cast), [BSC-E0115](#bsc-e0115-invalid-cast-of-_owned-value)

---

### BSC-E0126 Temporary variable memory leak

| | |
|---|---|
| **Diagnostic** | `err_owned_temporary_memLeak` |
| **Flag** | (hard error, no flag) |
| **Message** | `memory leak because temporary variable '%0' is _Owned or indirect _Owned type, please fix it` |

**Cause:**
A temporary (unnamed or short-lived) variable of `_Owned` type or a type that indirectly contains `_Owned` fields was created but its result was not captured. Since temporary values are destroyed at the end of the full expression, any `_Owned` memory they hold would be leaked. BSC detects this pattern and requires that the result of expressions producing `_Owned` types be stored in a named variable so the ownership can be properly managed.

**Bad code:**
```c
_Owned struct Data {
    int *_Owned value;
};

_Owned struct Data make_data(void);

void example(void) {
    make_data();   // error: memory leak because temporary variable 'make_data()' is _Owned or indirect _Owned type, please fix it
}
```

**Fix strategies:**
- Store the result in a named variable and free it when done.
- If the return value is not needed, capture it and immediately free it.

**Good code:**
```c
void example(void) {
    _Owned struct Data d = make_data();   // capture the result
    free_owned<int>(d.value);             // properly free
}
```

**See also:** [BSC-E0118](#bsc-e0118-memory-leak-of-value)

---

### BSC-E0127 Non-pointer type qualified by _Owned

| | |
|---|---|
| **Diagnostic** | `err_owned_qualifier_non_pointer` |
| **Flag** | `-Wowned-qualifier-type` |
| **Message** | `type of %1 cannot be qualified by '%0'` |

**Cause:**
The `_Owned` qualifier was applied to a non-pointer type. The `_Owned` qualifier is only meaningful on pointer types because it indicates that the pointer is responsible for the lifetime of the heap memory it points to. Applying `_Owned` to an integer, float, struct (non-pointer), or other non-pointer type has no meaningful ownership semantics and is rejected by the compiler.

**Bad code:**
```c
void example(void) {
    int _Owned x = 42;       // error: type of x cannot be qualified by '_Owned'
    float _Owned f = 3.14;   // error: type of f cannot be qualified by '_Owned'
}
```

**Fix strategies:**
- Remove the `_Owned` qualifier from non-pointer types.
- If you intend to track ownership, use a pointer type (e.g., `int *_Owned` instead of `int _Owned`).

**Good code:**
```c
void example(void) {
    int x = 42;
    int *_Owned p = safe_malloc<int>(42);   // OK: _Owned on pointer type
    free_owned<int>(p);
}
```

**See also:** [BSC-E0122](#bsc-e0122-declaration-cannot-be-qualified-by-_owned), [BSC-E0128](#bsc-e0128-_owned-and-_borrow-conflict)

---

### BSC-E0128 _Owned and _Borrow conflict

| | |
|---|---|
| **Diagnostic** | `err_owned_and_borrow_conflict` |
| **Flag** | (hard error, no flag) |
| **Message** | `cannot combine '_Owned' and '_Borrow' qualifiers on the same type` |

**Cause:**
Both `_Owned` and `_Borrow` qualifiers were applied to the same type. These qualifiers are mutually exclusive: `_Owned` means the pointer owns its memory and is responsible for freeing it, while `_Borrow` means the pointer is a temporary, non-owning reference to memory owned elsewhere. A pointer cannot simultaneously own and not own the memory it points to.

**Bad code:**
```c
void example(void) {
    int *_Owned _Borrow p;   // error: cannot combine '_Owned' and '_Borrow' qualifiers on the same type
}
```

**Fix strategies:**
- Choose either `_Owned` or `_Borrow` based on the intended ownership semantics.
- Use `_Owned` if the pointer should own and free the memory.
- Use `_Borrow` if the pointer is a temporary reference to memory owned by another variable.

**Good code:**
```c
void example(void) {
    int *_Owned p = safe_malloc<int>(42);
    int *_Borrow b = &*p;   // borrow from p
    // Use b for temporary access
    free_owned<int>(p);      // p owns the memory
}
```

**See also:** [BSC-E0122](#bsc-e0122-declaration-cannot-be-qualified-by-_owned), [BSC-E0127](#bsc-e0127-non-pointer-type-qualified-by-_owned)

---

## Operator Errors on _Owned Types

These errors occur when arithmetic or subscript operators are applied to `_Owned` pointer types, which is not permitted because such operations would produce pointers that do not correspond to a valid allocation boundary.

---

### BSC-E0129 Invalid binary expression on _Owned types

| | |
|---|---|
| **Diagnostic** | `err_typecheck_invalid_owned_binOp` |
| **Flag** | (hard error, no flag) |
| **Message** | `invalid operands to binary expression (%0 and %1)` |

**Cause:**
A binary operator (such as `+`, `-`, `<`, `>`, `==`) was applied to one or more `_Owned` pointer operands. BSC does not allow arithmetic or comparison operations on `_Owned` pointers because these operations could produce interior pointers that do not represent the start of an allocation. Freeing such an interior pointer would cause undefined behavior. Comparison is also restricted to prevent reliance on pointer identity for owned values.

**Bad code:**
```c
void example(void) {
    int *_Owned p = safe_malloc<int>(42);
    int *_Owned q = safe_malloc<int>(43);
    if (p == q) { /* ... */ }   // error: invalid operands to binary expression (int *_Owned and int *_Owned)
    free_owned<int>(p);
    free_owned<int>(q);
}
```

**Fix strategies:**
- Compare the pointed-to values instead of the pointers themselves (`*p == *q`).
- If pointer arithmetic is needed, borrow the pointer first and operate on the non-owned borrow.
- Remove the operator and use a different approach to achieve the desired logic.

**Good code:**
```c
void example(void) {
    int *_Owned p = safe_malloc<int>(42);
    int *_Owned q = safe_malloc<int>(43);
    if (*p == *q) { /* ... */ }   // OK: compare values, not pointers
    free_owned<int>(p);
    free_owned<int>(q);
}
```

**See also:** [BSC-E0130](#bsc-e0130-invalid-unary-expression-on-_owned-types), [BSC-E0131](#bsc-e0131-arraysubscript-on-_owned-pointer)

---

### BSC-E0130 Invalid unary expression on _Owned types

| | |
|---|---|
| **Diagnostic** | `err_typecheck_invalid_owned_unaOp` |
| **Flag** | (hard error, no flag) |
| **Message** | `invalid operands to unary expression (%0)` |

**Cause:**
A unary operator (such as `++`, `--`, or unary `-`) was applied to an `_Owned` pointer. Incrementing or decrementing an `_Owned` pointer would change it to point to an interior location within (or outside) the allocation, making it impossible to correctly free the memory. BSC prohibits any unary operation that would alter the value of an `_Owned` pointer away from the original allocation address.

**Bad code:**
```c
void example(void) {
    int *_Owned p = safe_malloc<int>(42);
    p++;                  // error: invalid operands to unary expression (int *_Owned)
    free_owned<int>(p);   // would free wrong address
}
```

**Fix strategies:**
- Borrow the pointer and perform arithmetic on the non-owned borrow.
- Use array indexing on a borrowed pointer instead of pointer increment.
- Restructure the algorithm to avoid modifying the owned pointer.

**Good code:**
```c
void example(void) {
    int *_Owned p = safe_malloc<int>(42);
    int *_Borrow b = &*p;
    b++;                   // OK: arithmetic on borrow
    free_owned<int>(p);    // p still points to allocation start
}
```

**See also:** [BSC-E0129](#bsc-e0129-invalid-binary-expression-on-_owned-types), [BSC-E0131](#bsc-e0131-arraysubscript-on-_owned-pointer)

---

### BSC-E0131 ArraySubscript on _Owned pointer

| | |
|---|---|
| **Diagnostic** | `err_typecheck_invalid_owned_arrsub` |
| **Flag** | (hard error, no flag) |
| **Message** | `_Owned pointer type (%0) do not support ArraySubscript operate` |

**Cause:**
The array subscript operator (`[]`) was applied to an `_Owned` pointer. In C, `p[i]` is equivalent to `*(p + i)`, which involves pointer arithmetic. Since `_Owned` pointers must always point to the exact start of their allocation, array subscript operations are not allowed on them. This restriction prevents the creation of interior pointers that cannot be correctly freed.

**Bad code:**
```c
void example(void) {
    int *_Owned arr = safe_malloc<int>(0);   // allocate array
    arr[2] = 42;   // error: _Owned pointer type (int *_Owned) do not support ArraySubscript operate
}
```

**Fix strategies:**
- Borrow the pointer and use array subscript on the borrow.
- Use a non-owned pointer for array access and keep the `_Owned` pointer only for ownership tracking.

**Good code:**
```c
void example(void) {
    int *_Owned arr = safe_malloc<int>(0);
    int *_Borrow b = &*arr;
    b[2] = 42;              // OK: subscript on borrow
    free_owned<int>(arr);
}
```

**See also:** [BSC-E0129](#bsc-e0129-invalid-binary-expression-on-_owned-types), [BSC-E0130](#bsc-e0130-invalid-unary-expression-on-_owned-types)

---

## Controlling Ownership Diagnostics

Most ownership errors can be controlled with Clang warning flags:

```
-Wbsc-ownership                # All ownership checks
  -Wuse-moved-owned            # BSC-E0101 through BSC-E0103
  -Wuse-uninit-owned           # BSC-E0104, BSC-E0105
  -Wassign-owned               # BSC-E0106, BSC-E0111, BSC-E0113
  -Wassign-moved-owned         # BSC-E0107, BSC-E0108, BSC-E0109, BSC-E0112
  -Wassign-uninit-owned        # BSC-E0110
  -Wcast-moved-owned           # BSC-E0114
  -Wcast-owned                 # BSC-E0115, BSC-E0116, BSC-E0117
  -Wcheck-memory-leak          # BSC-E0118, BSC-E0119
  -Wpartially-moved-struct     # BSC-E0120
  -Wdestruct-owned-struct      # BSC-E0121
  -Wowned-qualifier-type       # BSC-E0127
```

Type qualification errors (BSC-E0122 through BSC-E0126, BSC-E0128) and operator errors (BSC-E0129 through BSC-E0131) are hard errors and cannot be suppressed.

## See Also

- [BiShengC Language User Manual](../BiShengCLanguageUserManual.md)
- [Borrow Checking Errors](borrow.md)
- [Memory Leak Errors](#memory-leak-errors)
- [Error Reference Guide](README.md)
