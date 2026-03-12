# Member Function / Attribute Errors (BSC-E11xx)

BSC allows defining member functions for any type (structs, enums, built-in types) using the `Type_functionName(Type *this, ...)` convention. These errors relate to member function resolution and BSC-specific attributes.

---

## BSC-E1101: No Instance Member

**Diagnostic:** `err_no_instance_member`

**Message:** `no instance member named <name> in <type>; did you mean to use '::' instead of '.'|'->'?`

**Cause:**
You used `.` or `->` to access a member that doesn't exist as an instance member of the type. It may be a static/type-level function that should be called with `::` instead.

**Example (bad):**
```c
struct Foo { int x; };
Foo Foo_create() { Foo f = { .x = 0 }; return f; }

void f() {
    Foo obj = { .x = 1 };
    Foo new_obj = obj.create();  // ERROR: no instance member 'create'
}
```

**Fix:**
- Use `::` for type-level (static) functions
- Use `.` or `->` only for instance members

```c
void f_fixed() {
    Foo new_obj = Foo::create();  // OK: type-level call
}
```

---

## BSC-E1102: Attribute Redundant Pointers

**Diagnostic:** `err_attribute_redundant_pointers`

**Message:** `(EnhanceC) <attr> attribute applied to function with more than one pointer arguments, please specify the index argument in the <attr> attribute`

**Cause:**
A BSC attribute was applied to a function that has multiple pointer parameters, but the attribute doesn't specify which pointer it applies to. When there is ambiguity, you must use the index argument.

**Fix:**
- Specify the pointer index in the attribute to disambiguate

---

## BSC-E1103: Attribute Zero Pointer Index

**Diagnostic:** `err_attribute_zero_pointer`

**Message:** `(EnhanceC) <attr> attribute: The number of pointer arguments index cannot be zero`

**Cause:**
The pointer index argument in a BSC attribute is 1-based. Passing `0` as the index is invalid.

**Fix:**
- Use index `1` for the first pointer parameter, `2` for the second, etc.
