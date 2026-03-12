# Generics / Constexpr Errors (BSC-E09xx)

BSC supports generic functions (using `<T>` syntax) and `constexpr` compile-time evaluation. These errors relate to restrictions on those features.

---

## BSC-E0901: Struct Definition in Generic Function

**Diagnostic:** `err_invalid_struct_definition`

**Message:** `struct definition in generic function is not supported in BSC`

**Cause:**
BSC does not allow defining new struct types inside generic functions. Struct definitions must be at file scope or inside non-generic functions.

**Fix:**
- Move the struct definition outside the generic function

```c
struct Result { int code; int value; };  // OK: at file scope

int process<T>(T *data) {
    struct Result r = { .code = 0, .value = 0 };
    // ...
}
```

---

## BSC-E0902: Extended Type Cannot Be Instantiated

**Diagnostic:** `err_extended_type_not_instantiated_type`

**Message:** `extended type of a BSC member function cannot be an instantiated type`

**Cause:**
When declaring a member function for a generic type, you cannot use an instantiated (concrete) type as the extended type. Use the uninstantiated generic form instead.

**Fix:**
- Use the generic type form, not a specific instantiation

---

## BSC-E0903: Conflicting Function Declarations

**Diagnostic:** `err_conflicting_function_declarations`

**Message:** `conflicting function declarations for <name>`

**Cause:**
Multiple declarations of the same function have incompatible signatures. This often happens with generic function specializations or overloads that create ambiguity.

**Fix:**
- Ensure all declarations of the same function have matching signatures
- Remove or rename conflicting declarations

---

## BSC-E0904: Extended Type Cannot Be Generic Typealias

**Diagnostic:** `err_extended_type_not_generic_typealias`

**Message:** `extended type of a BSC member function cannot be a generic typealias`

**Cause:**
Member functions cannot be defined for generic type aliases. They must be defined for the actual type.

**Fix:**
- Define the member function on the concrete type, not the typealias

---

## BSC-E0905: Generic Typealias in Function Scope

**Diagnostic:** `err_generic_typealias_not_within_function`

**Message:** `BSC generic typealias cannot be declared within a function`

**Cause:**
Generic type aliases must be declared at file scope, not inside function bodies.

**Fix:**
- Move the generic typealias to file scope

---

## BSC-E0906: Constexpr Function Unsupported Feature

**Diagnostic:** `err_constexpr_func_unsupported`

**Message:** `BSC constexpr function does not support <feature>`

**Cause:**
BSC's `constexpr` functions are evaluated at compile time and support only a limited subset of operations. Features like dynamic allocation, I/O, and certain control flow are not available.

**Fix:**
- Remove the unsupported feature from the constexpr function
- If the feature is necessary, make the function a regular (non-constexpr) function

---

## BSC-E0907: Constexpr Function Unsupported Type

**Diagnostic:** `err_constexpr_func_unsupported_type`

**Message:** `BSC constexpr function does not support type <type>`

**Cause:**
The type used in a constexpr function is not supported for compile-time evaluation. Only simple types (integers, floats, etc.) are supported in constexpr contexts.

**Fix:**
- Use a supported type, or make the function non-constexpr

---

## BSC-E0908: Constexpr Variable Unsupported Type

**Diagnostic:** `err_constexpr_var_unsupported_type`

**Message:** `BSC constexpr variable does not support type <type>`

**Cause:**
A `constexpr` variable was declared with a type that cannot be evaluated at compile time.

**Fix:**
- Use a compile-time-compatible type (e.g., `int`, `float`, `char`)

---

## BSC-E0909: Constexpr If Condition Unsupported Type

**Diagnostic:** `err_constexpr_if_cond_expr_unsupported_type`

**Message:** `BSC constexpr if condition expression does not support type <type>`

**Cause:**
The condition in a `constexpr if` statement uses a type that cannot be evaluated at compile time. The condition must be a compile-time constant of a supported type.

**Fix:**
- Ensure the condition is a compile-time integer or boolean expression
