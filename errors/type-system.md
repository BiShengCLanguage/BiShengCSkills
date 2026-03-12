# Type System Errors (BSC-E07xx)

These errors relate to BSC's extended type qualifier system for `_Owned`, `_Borrow`, and `const` qualifiers on pointer types, particularly in the context of member function calls.

---

## BSC-E0701: Incompatible Pointer Cast in Member Call

**Diagnostic:** `err_incompatible_pointer_cast`

**Message:** `incompatible conversion from pointer type '<src>' to non-pointer type '<dst>' in member function call`

**Cause:**
A member function call involves passing a pointer type where a non-pointer type is expected, or vice versa. The `this` parameter or other parameters have a type mismatch involving pointer indirection.

**Fix:**
- Check the member function's parameter types and ensure the object/arguments match
- If calling `obj.method()`, ensure `obj` has the correct pointer indirection level

---

## BSC-E0702: Incompatible Const Cast in Member Call

**Diagnostic:** `err_incompatible_const_cast`

**Message:** `incompatible conversion from const type '<src>' to non-const type '<dst>' in member function call`

**Cause:**
You are calling a non-const member function on a const-qualified object. The function expects a mutable `this` pointer but received a `const` one.

**Example (bad):**
```c
void Foo_mutate(Foo *this) { /* modifies this */ }

void f(const Foo *p) {
    p->mutate();  // ERROR: incompatible const to non-const conversion
}
```

**Fix:**
- Call only const-compatible member functions on const objects
- Remove the `const` qualifier if mutation is intended

---

## BSC-E0703: Incompatible Owned Cast in Member Call

**Diagnostic:** `err_incompatible_owned_cast`

**Message:** `incompatible conversion from non _Owned type '<src>' to _Owned type '<dst>' in member function call`

**Cause:**
A member function expects an `_Owned` pointer parameter, but you passed a non-owned (raw or `_Borrow`) pointer. Ownership cannot be implicitly created — it must be explicitly transferred.

**Fix:**
- Pass an `_Owned` pointer to the function
- If the function needs to consume ownership, ensure the caller has ownership to give

---

## BSC-E0704: CVR Qualified Member Type Unsupported

**Diagnostic:** `err_cvrqualified_member_type_unsupported`

**Message:** `type of member function is wrong, CVR qualified type is unsupported, but found '<type>'`

**Cause:**
The member function's type uses a const/volatile/restrict (CVR) qualified type in a position where BSC does not support it. BSC member functions have specific rules about where qualifiers can appear.

**Fix:**
- Remove unsupported CVR qualifiers from the member function's type

---

## BSC-E0705: Invalid 'this' Parameter Type

**Diagnostic:** `err_this_type_unsupported`

**Message:** `type of parameter 'this' is wrong, expected 'This*' or 'This' or '<Type>*' or '<Type>', but found '<actual>'`

**Cause:**
The `this` parameter in a member function has an incorrect type. It must be either a pointer to the struct type (`Type *this`) or the struct type itself (`Type this`).

**Example (bad):**
```c
struct Foo { int x; };

int Foo_get(int *this) {  // ERROR: expected Foo* or Foo, found int*
    return *this;
}
```

**Fix:**
```c
int Foo_get(Foo *this) {  // OK
    return this->x;
}
```
