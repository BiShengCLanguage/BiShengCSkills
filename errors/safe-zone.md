# Safe Zone Errors (BSC-E03xx)

BSC's safe zone system (`_Safe` functions and blocks) restricts operations that could lead to undefined behavior. Code in a safe zone cannot perform unsafe casts, access union fields, use raw pointer arithmetic, or call unsafe functions.

---

## BSC-E0301: Unsafe Action in Safe Zone

**Diagnostic:** `err_unsafe_action`

**Message:** `<action> is forbidden in the safe zone`

**Cause:**
You performed an operation that BSC considers unsafe inside a `_Safe` function or block. Unsafe operations include raw pointer arithmetic, calling functions not marked `_Safe`, and certain type punning operations. These operations must be moved to an `_Unsafe` block.

**Example (bad):**
```c
_Safe void f(int *p) {
    p++;  // ERROR: pointer arithmetic is forbidden in the safe zone
}
```

**Fix:**
- Wrap the unsafe operation in an `_Unsafe { }` block
- Refactor to use safe alternatives

```c
_Safe void f_fixed(int *p) {
    _Unsafe {
        p++;  // OK: explicitly marked as unsafe
    }
}
```

**See also:** BSC-E0307

---

## BSC-E0302: Invalid Safe/Unsafe Declaration Position

**Diagnostic:** `err_safe_zone_decl`

**Message:** `'_Safe'|'_Unsafe' can only appear before on function or statement or parenthesized expression`

**Cause:**
You placed `_Safe` or `_Unsafe` in a syntactically invalid position. These qualifiers can only appear on function declarations, before statements (as block qualifiers), or on parenthesized expressions.

**Example (bad):**
```c
int _Safe x = 5;  // ERROR: _Safe can only appear on function or statement
```

**Fix:**
- Move the qualifier to a valid position (function declaration or block statement)

```c
_Safe void f() {   // OK: on function declaration
    // ...
}
void g() {
    _Safe { /* ... */ }  // OK: on block statement
}
```

---

## BSC-E0303: Union Member Access in Safe Zone

**Diagnostic:** `err_union_member_access_in_safe_zone`

**Message:** `access to union field is _Unsafe and requires _Unsafe block`

**Cause:**
Accessing a union member is inherently unsafe because unions allow type punning — reading a member that wasn't the last one written is undefined behavior. BSC requires union field access to be wrapped in an `_Unsafe` block.

**Example (bad):**
```c
union Data { int i; float f; };

_Safe void f(union Data *d) {
    int x = d->i;  // ERROR: access to union field is _Unsafe
}
```

**Fix:**
- Wrap the union access in an `_Unsafe` block

```c
_Safe void f_fixed(union Data *d) {
    int x;
    _Unsafe { x = d->i; }  // OK
}
```

---

## BSC-E0304: Forbidden Cast in Safe Zone

**Diagnostic:** `err_unsafe_cast`

**Message:** `conversion from type <src> to <dst> is forbidden in the safe zone`

**Cause:**
You performed an explicit type cast that BSC considers unsafe inside a safe zone. This includes casts between incompatible pointer types, pointer-to-integer casts, and other conversions that could violate type safety or memory safety.

**Example (bad):**
```c
_Safe void f(void *p) {
    int *q = (int *)p;  // ERROR: conversion forbidden in safe zone
}
```

**Fix:**
- Wrap the cast in an `_Unsafe` block
- Use a safer alternative (e.g., pass the correct pointer type)

```c
_Safe void f_fixed(void *p) {
    int *q;
    _Unsafe { q = (int *)p; }
}
```

**See also:** BSC-E0305, BSC-E0306

---

## BSC-E0305: Forbidden Implicit Cast in Safe Zone

**Diagnostic:** `err_unsafe_implicit_cast`

**Message:** `implicit conversion from type <src> to <dst> is forbidden in the safe zone; please use explicit cast or other means instead`

**Cause:**
An implicit type conversion that BSC considers unsafe occurred in a safe zone. Unlike BSC-E0304, this happens without an explicit cast — the compiler would normally perform the conversion silently, but BSC flags it because the conversion could violate safety guarantees.

**Example (bad):**
```c
_Safe void f(int *p, void (*callback)(void *)) {
    callback(p);  // ERROR: implicit conversion from int* to void* is forbidden
}
```

**Fix:**
- Use an explicit cast inside an `_Unsafe` block
- Change the function signature to accept the correct type

```c
_Safe void f_fixed(int *p, void (*callback)(void *)) {
    _Unsafe { callback((void *)p); }
}
```

**See also:** BSC-E0304

---

## BSC-E0306: Forbidden Function Type Conversion

**Diagnostic:** `err_unsafe_fun_cast`

**Message:** `conversion from type <src> to <dst> is forbidden`

**Cause:**
You attempted to convert between incompatible function pointer types. This is dangerous because calling a function through a pointer with the wrong signature is undefined behavior. BSC blocks this even when not explicitly in a safe zone for function pointer assignments.

**Example (bad):**
```c
void foo(int x);

_Safe void f() {
    void (*p)(float) = (void (*)(float))foo;  // ERROR: conversion forbidden
}
```

**Fix:**
- Ensure function pointer types match exactly
- Wrap in `_Unsafe` if the conversion is intentional and correct

---

## BSC-E0307: Forbidden Operation in Safe Function

**Diagnostic:** `err_safe_function`

**Message:** `<operation> is forbidden in the _Safe function`

**Cause:**
You performed a specific operation that is not allowed in a `_Safe` function. This is similar to BSC-E0301 but specifically targets function-level restrictions. Operations like inline assembly, `goto`, or calling `_Unsafe` functions are forbidden.

**Example (bad):**
```c
_Safe void f() {
    __asm__("nop");  // ERROR: inline assembly is forbidden in _Safe function
}
```

**Fix:**
- Move the operation to an `_Unsafe` block within the function
- Extract the unsafe operation into a separate non-safe function

---

## BSC-E0308: Mutable Global Variable in Safe Zone

**Diagnostic:** `err_safe_global_var`

**Message:** `defining mutable global variables is not allowed within the safe zone`

**Cause:**
Mutable global variables are a source of data races in concurrent programs. BSC's safe zone prohibits defining new mutable global variables. Constant globals are still allowed.

**Example (bad):**
```c
_Safe {
    int global_counter = 0;  // ERROR: mutable global not allowed in safe zone
}
```

**Fix:**
- Make the global `const` if it doesn't need to change
- Define the global outside the safe zone

```c
const int global_max = 100;  // OK: const global

int global_counter = 0;  // OK: outside safe zone
```

---

## BSC-E0309: Return Increment/Decrement in Safe Zone

**Diagnostic:** `err_return_inc_dec_void_in_safe_zone`

**Message:** `result of '++' or '--' cannot be used as return value in safe zone; move the increment/decrement out of the return statement (or add an explicit cast to void to suppress)`

**Cause:**
In BSC's safe zone, prefix/postfix `++` and `--` operators on pointers produce `void` to prevent pointer arithmetic mistakes. Returning this void result is an error.

**Example (bad):**
```c
_Safe int f(int *p) {
    return (*p)++;  // ERROR: result of ++ cannot be used as return value in safe zone
}
```

**Fix:**
- Separate the increment from the return statement

```c
_Safe int f_fixed(int *p) {
    int val = *p;
    (*p)++;
    return val;
}
```

---

## BSC-E0310: Generic Function with Both Safe and Unsafe Declarations

**Diagnostic:** `err_bsc_generic_heterogeneous_redecl`

**Message:** `generic function <name> cannot have both _Safe and _Unsafe declarations`

**Cause:**
A generic function was declared with both `_Safe` and `_Unsafe` variants, which is not allowed. Generic functions must have a single safety qualification.

**Example (bad):**
```c
_Safe void process<T>(T *p);
_Unsafe void process<T>(T *p);  // ERROR: cannot have both
```

**Fix:**
- Choose one safety qualification for the generic function
- If both variants are needed, use different function names

---

## BSC-E0311: Incompatible Heterogeneous Redeclaration

**Diagnostic:** `err_bsc_incompatible_heterogeneous_redecl`

**Message:** `function <name> has incompatible _Safe and _Unsafe declarations`

**Cause:**
A function has both `_Safe` and `_Unsafe` overloads, but their signatures are incompatible beyond the safety qualifier.

**Fix:**
- Ensure the `_Safe` and `_Unsafe` declarations have compatible parameter and return types

---

## BSC-E0312: No Matching Heterogeneous Function

**Diagnostic:** `err_bsc_no_matching_heterogeneous_function`

**Message:** `no matching function for call to <name>; argument types do not match any _Safe or _Unsafe declaration`

**Cause:**
You called a function that has `_Safe`/`_Unsafe` overloads, but the provided arguments don't match any of the declared variants.

**Fix:**
- Check the function's declared parameter types for both the `_Safe` and `_Unsafe` variants
- Adjust argument types to match one of the declarations
