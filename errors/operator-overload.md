# Operator Overload Errors (BSC-E12xx)

BSC supports operator overloading for struct and enum types. These errors relate to restrictions on which operators can be overloaded and what types are valid.

---

## BSC-E1201: Function Does Not Support Overload

**Diagnostic:** `err_unsupport_overload_fun`

**Message:** `function unsupport overload`

**Cause:**
The function you are trying to overload does not support operator overloading. Only specific operator functions can be overloaded in BSC.

**Fix:**
- Check that you are overloading a supported operator

---

## BSC-E1202: Unsupported Operator Type

**Diagnostic:** `err_unsupport_overload_type`

**Message:** `unsupported operator type`

**Cause:**
The operator type you are trying to overload is not supported by BSC. BSC supports overloading for a specific set of operators (arithmetic, comparison, etc.).

**Fix:**
- Use a supported operator type for overloading

---

## BSC-E1203: Overload Requires Struct/Enum Pointer

**Diagnostic:** `err_operator_overload_needs_point`

**Message:** `overloaded function <name> first parameter or return type must be struct or enumeration pointer type`

**Cause:**
Operator overloads in BSC must involve user-defined types. The first parameter or return type of the overloaded operator function must be a pointer to a struct or enum type.

**Example (bad):**
```c
int operator_add(int a, int b) {  // ERROR: must be struct/enum pointer type
    return a + b;
}
```

**Fix:**
```c
struct Vec2 { int x; int y; };

struct Vec2 *_Owned operator_add(struct Vec2 *a, struct Vec2 *b) {  // OK
    struct Vec2 *_Owned result = safe_malloc<struct Vec2>((struct Vec2){ .x = 0, .y = 0 });
    result->x = a->x + b->x;
    result->y = a->y + b->y;
    return result;
}
```
