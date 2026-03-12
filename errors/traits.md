# Trait Errors (BSC-E05xx)

BSC's trait system allows defining interfaces (`_Trait`) and implementing them for types (`_Impl`). Traits enable polymorphism through trait pointers.

---

## BSC-E0501: Undefined Trait

**Diagnostic:** `err_trait_is_undefined`

**Message:** `<name> must be defined before it can be used`

**Cause:**
You referenced a trait that has not been defined yet. Traits must be declared with `_Trait` before they can be used in `_Impl` blocks or as pointer types.

**Example (bad):**
```c
_Impl Printable for int { /* ... */ }  // ERROR: Printable not defined
```

**Fix:**
- Define the trait before using it

```c
_Trait Printable {
    void print(This *this);
};

_Impl Printable for int {
    void print(int *this) { /* ... */ }
};
```

---

## BSC-E0502: Type Has Not Implemented Trait

**Diagnostic:** `err_type_has_not_impl_trait` | **Flag:** `-Wbsc-trait-missing` (warning variant: `warn_type_has_not_impl_trait`)

**Message:** `expected a pointer type which has implemented <trait>, found <type>`

**Cause:**
You assigned a pointer to a trait pointer variable, but the pointed-to type has not implemented the required trait. The type must have an `_Impl` block for that trait.

**Example (bad):**
```c
_Trait Drawable { void draw(This *this); };

struct Circle { int r; };

void f() {
    struct Circle c = { .r = 5 };
    _Trait Drawable *d = &c;  // ERROR: Circle has not implemented Drawable
}
```

**Fix:**
- Add an `_Impl` block for the trait

```c
_Impl Drawable for struct Circle {
    void draw(struct Circle *this) { /* ... */ }
};
```

---

## BSC-E0503: Trait Function Not Implemented

**Diagnostic:** `err_trait_impl`

**Message:** `function <func> in <trait> is not implemented for <type>`

**Cause:**
Your `_Impl` block is missing one or more functions declared in the trait. All trait functions must be implemented.

**Example (bad):**
```c
_Trait Shape {
    void draw(This *this);
    int area(This *this);
};

_Impl Shape for struct Circle {
    void draw(struct Circle *this) { /* ... */ }
    // ERROR: function area in Shape is not implemented for struct Circle
};
```

**Fix:**
- Implement all functions declared in the trait

---

## BSC-E0504: Trait Implementation Type Conflict

**Diagnostic:** `err_trait_impl_function_type_conflict`

**Message:** `type of <impl_func> conflicts with that of <trait_func>`

**Cause:**
The function you provided in your `_Impl` block has a different signature (parameter types or return type) than what the trait declares. The signatures must match exactly (except `This` is replaced with the concrete type).

**Fix:**
- Match the function signature exactly as declared in the trait, substituting the concrete type for `This`

---

## BSC-E0505: Non-Function Trait Member

**Diagnostic:** `err_trait_member_not_func`

**Message:** `only function declarations can be _Trait member`

**Cause:**
You declared something other than a function inside a `_Trait` block. Traits can only contain function declarations.

**Example (bad):**
```c
_Trait Foo {
    int value;  // ERROR: only function declarations can be trait member
};
```

**Fix:**
- Only declare functions in traits; use struct fields for data

---

## BSC-E0506: Impl Trait for Instantiated Type

**Diagnostic:** `err_impl_trait_for_instantiated_type`

**Message:** `cannot _Impl _Trait for an instantiated type`

**Cause:**
You tried to implement a trait for an already-instantiated generic type. Trait implementations must be for base types, not specific generic instantiations.

**Fix:**
- Implement the trait for the base (non-instantiated) type

---

## BSC-E0507: Non-Trait Pointer Declaration

**Diagnostic:** `err_variables_not_trait_pointer`

**Message:** `only _Trait pointer type is allowed to be declared`

**Cause:**
You tried to declare a trait variable that is not a pointer. Trait types can only be used as pointer types (`_Trait Name *`) because traits are dynamically dispatched and require indirection.

**Example (bad):**
```c
_Trait Printable p;  // ERROR: only trait pointer type is allowed
```

**Fix:**
```c
_Trait Printable *p;  // OK: trait pointer
```

---

## BSC-E0508: Invalid Trait Member Parameter

**Diagnostic:** `invalid_param_for_trait_member`

**Message:** `the first parameter of _Trait member function must be 'This* this'`

**Cause:**
Trait member functions must take `This *this` as their first parameter. `This` is a placeholder for the implementing type.

**Fix:**
```c
_Trait Foo {
    void bar(This *this);  // OK: This* this as first param
};
```

---

## BSC-E0509: Unexpected Token in Impl Trait

**Diagnostic:** `err_unexpected_token_for_impl_trait_decl`

**Message:** `unexpected token for ImplTraitDecl`

**Cause:**
The `_Impl` declaration has a syntax error. The expected syntax is `_Impl TraitName for TypeName { ... }`.

**Fix:**
- Check the `_Impl` syntax: `_Impl <Trait> for <Type> { <functions> };`

---

## BSC-E0510: Expected Identifier After Trait

**Diagnostic:** `err_expected_identifier_after_trait`

**Message:** `expected identifier after _Trait`

**Cause:**
The `_Trait` keyword must be followed by an identifier (the trait name).

**Fix:**
```c
_Trait MyTrait {  // OK: identifier follows _Trait
    // ...
};
```

---

## BSC-E0511: Trait Not at Top Level

**Diagnostic:** `err_trait_def_not_at_top_level`

**Message:** `_Trait is only allowed to be defined at top-level`

**Cause:**
Traits must be defined at file scope, not inside functions or other blocks.

**Fix:**
- Move the trait definition to the top level of the file

---

## BSC-E0512: Invalid Trait Syntax

**Diagnostic:** `err_invalid_trait`

**Message:** `invalid syntax, semi not expected after '_Trait <name>'`

**Cause:**
A semicolon was found immediately after `_Trait Name` instead of an opening brace. Trait definitions require a body.

**Fix:**
```c
_Trait Foo {  // OK: opening brace, not semicolon
    void bar(This *this);
};
```

---

## BSC-E0513: Direct Function Call on Multi-Trait

**Diagnostic:** `err_multi_trait_call_func`

**Message:** `<name> cannot directly call functions`

**Cause:**
You tried to call a function directly on a multi-trait pointer. Multi-trait pointers require disambiguation when calling trait functions.

**Fix:**
- Cast to a specific trait pointer before calling the function
