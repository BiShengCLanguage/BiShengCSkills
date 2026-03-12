# Nullability Errors (BSC-E04xx)

BSC's nullability system uses `_Nullable` and `_Nonnull` pointer qualifiers to track whether a pointer may be null. The compiler enforces that potentially null pointers are checked before use.

---

## BSC-E0401: Nullable Pointer Dereference

**Diagnostic:** `err_nullable_pointer_dereference` | **Flag:** `-Wderef-nullable`

**Message:** `nullable pointer cannot be dereferenced`

**Cause:**
You attempted to dereference a pointer that is `_Nullable` — meaning it could be `NULL`. Dereferencing a null pointer is undefined behavior. BSC requires an explicit null check before dereferencing any nullable pointer.

**Example (bad):**
```c
void f(int *_Nullable p) {
    int x = *p;  // ERROR: nullable pointer cannot be dereferenced
}
```

**Fix:**
- Add a null check before dereferencing
- If you know the pointer is never null in this context, cast it to `_Nonnull`

```c
void f_fixed(int *_Nullable p) {
    if (p != NULL) {
        int x = *p;  // OK: null check guards the dereference
    }
}
```

**See also:** BSC-E0405

---

## BSC-E0402: Pass Nullable Argument

**Diagnostic:** `err_pass_nullable_argument` | **Flag:** `-Wpass-nullable`

**Message:** `cannot pass nullable pointer argument`

**Cause:**
A function parameter expects a `_Nonnull` pointer, but you are passing a `_Nullable` pointer. The callee assumes the pointer is valid and may dereference it without checking.

**Example (bad):**
```c
void process(int *_Nonnull data);

void f(int *_Nullable p) {
    process(p);  // ERROR: cannot pass nullable pointer argument
}
```

**Fix:**
- Add a null check before the call
- If the pointer is known non-null, annotate it as `_Nonnull`

```c
void f_fixed(int *_Nullable p) {
    if (p != NULL) {
        process(p);  // OK: guarded by null check
    }
}
```

**See also:** BSC-E0401, BSC-E0403

---

## BSC-E0403: Return Nullable

**Diagnostic:** `err_return_nullable` | **Flag:** `-Wreturn-nullable`

**Message:** `cannot return nullable pointer type`

**Cause:**
The function's return type is `_Nonnull`, but you are returning a `_Nullable` pointer. Callers of this function expect a valid pointer and won't check for null.

**Example (bad):**
```c
int *_Nonnull get_value(int *_Nullable p) {
    return p;  // ERROR: cannot return nullable pointer type
}
```

**Fix:**
- Add a null check and provide a fallback or early return
- Change the return type to `_Nullable` if null is a valid return value

```c
int *_Nonnull get_value_fixed(int *_Nullable p, int *_Nonnull fallback) {
    if (p != NULL) {
        return p;
    }
    return fallback;
}
```

**See also:** BSC-E0402

---

## BSC-E0404: Nullable Cast to Nonnull

**Diagnostic:** `err_nullable_cast_nonnull` | **Flag:** `-Wcast-nullable`

**Message:** `cannot cast nullable pointer to nonnull type`

**Cause:**
You are explicitly casting a `_Nullable` pointer to a `_Nonnull` type without first establishing that the pointer is non-null. This bypasses the safety guarantee.

**Example (bad):**
```c
void f(int *_Nullable p) {
    int *_Nonnull q = (int *_Nonnull)p;  // ERROR: cannot cast nullable to nonnull
}
```

**Fix:**
- Check for null before casting
- Use a conditional assignment

```c
void f_fixed(int *_Nullable p) {
    if (p != NULL) {
        int *_Nonnull q = (int *_Nonnull)p;  // OK: guarded
    }
}
```

**See also:** BSC-E0401, BSC-E0406

---

## BSC-E0405: Nullable Pointer Member Access

**Diagnostic:** `err_nullable_pointer_access_member` | **Flag:** `-Wassign-nullable`

**Message:** `cannot access member through nullable pointer`

**Cause:**
You tried to access a struct member through a `_Nullable` pointer using `->`. If the pointer is null, this would be undefined behavior. A null check is required first.

**Example (bad):**
```c
struct Point { int x; int y; };

void f(struct Point *_Nullable p) {
    int x = p->x;  // ERROR: cannot access member through nullable pointer
}
```

**Fix:**
- Add a null check before member access

```c
void f_fixed(struct Point *_Nullable p) {
    if (p != NULL) {
        int x = p->x;  // OK
    }
}
```

**See also:** BSC-E0401

---

## BSC-E0406: Nonnull Assigned by Nullable

**Diagnostic:** `err_nonnull_assigned_by_nullable` | **Flag:** `-Wassign-nonnull`

**Message:** `nonnull pointer cannot be assigned by nullable pointer`

**Cause:**
You are assigning a `_Nullable` pointer to a `_Nonnull` variable. This would allow a potentially null value to enter a non-null context, violating the nullability contract.

**Example (bad):**
```c
void f(int *_Nullable p) {
    int *_Nonnull q = p;  // ERROR: nonnull cannot be assigned by nullable
}
```

**Fix:**
- Guard with a null check before assignment
- Change the target type to `_Nullable` if null is acceptable

```c
void f_fixed(int *_Nullable p) {
    if (p != NULL) {
        int *_Nonnull q = p;  // OK: guarded
    }
}
```

**See also:** BSC-E0404

---

## BSC-E0407: Nonnull Not Initialized

**Diagnostic:** `err_nonnull_init_by_default` | **Flag:** `-Winit-nonnull`

**Message:** `` `<variable>` is a _Nonnull pointer and must be properly initialized. ``

**Cause:**
A `_Nonnull` pointer variable was declared without initialization. Since `_Nonnull` guarantees the pointer is always valid, it must be given a valid value at declaration time. An uninitialized `_Nonnull` pointer could be null or contain garbage.

**Example (bad):**
```c
void f() {
    int *_Nonnull p;  // ERROR: _Nonnull pointer must be properly initialized
}
```

**Fix:**
- Initialize the pointer at declaration
- If the value isn't available yet, use `_Nullable` instead

```c
void f_fixed() {
    int value = 42;
    int *_Nonnull p = &value;  // OK: initialized with valid pointer
}
```

**See also:** BSC-E0406
