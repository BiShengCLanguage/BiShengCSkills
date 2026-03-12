# Owned Struct / Destructor Errors (BSC-E06xx)

`_Owned struct` declarations define structs that may contain `_Owned` pointer fields. These structs have special rules: they can have destructors, visibility modifiers (`_Public`, `_Private`), and member functions. Destructors must properly free all `_Owned` fields.

---

## BSC-E0601: Invalid Owned Struct Tag

**Diagnostic:** `err_tag_name`

**Message:** `must ignore '_Owned struct' tag before struct name`

**Cause:**
When referring to an `_Owned struct` type after its declaration, you should not prefix it with `struct`. The `_Owned struct Name { ... }` declaration introduces `Name` as a type name directly.

**Example (bad):**
```c
_Owned struct Foo { _Public: int *_Owned p; };

void f(struct Foo *p) {}  // ERROR: must ignore '_Owned struct' tag
```

**Fix:**
```c
void f(Foo *p) {}  // OK: use Foo directly, not struct Foo
```

---

## BSC-E0602: Inconsistent Struct Tag

**Diagnostic:** `err_inconsistent_tag_name`

**Message:** `inconsistent tag before struct name`

**Cause:**
You used an inconsistent tag (e.g., `struct` vs no tag) when referring to an `_Owned struct` type across different declarations.

**Fix:**
- Use the type name consistently without the `struct` prefix for `_Owned struct` types

---

## BSC-E0603: Missing Explicit Constructor

**Diagnostic:** `err_need_explicit_constructor_owned_struct`

**Message:** `need explicit constructor because <name> has private field`

**Cause:**
The `_Owned struct` has `_Private` fields, so it cannot be initialized with a designated initializer (`{ .field = value }`). You must provide an explicit constructor function.

**Example (bad):**
```c
_Owned struct Foo {
_Private:
    int *_Owned data;
};

void f() {
    Foo x = { .data = safe_malloc<int>(0) };  // ERROR: needs explicit constructor
}
```

**Fix:**
- Create a constructor function that initializes the struct

```c
Foo Foo_new() {
    Foo x;
    x.data = safe_malloc<int>(0);
    return x;
}
```

---

## BSC-E0604: Struct Member Redeclared

**Diagnostic:** `err_struct_member_redeclared`

**Message:** `struct member cannot be redeclared`

**Cause:**
You declared the same member name more than once in an `_Owned struct`.

**Fix:**
- Remove the duplicate member declaration

---

## BSC-E0605: Invalid Implicit Member Use

**Diagnostic:** `err_invalid_member_use_in_class_method`

**Message:** `invalid implicit use of member <name> in struct member function`

**Cause:**
You used a member name without explicitly accessing it through `this->` in a member function. BSC requires explicit member access via `this` pointer.

**Example (bad):**
```c
_Owned struct Foo {
_Public:
    int value;
};

int Foo_get(Foo *this) {
    return value;  // ERROR: invalid implicit use of member
}
```

**Fix:**
```c
int Foo_get(Foo *this) {
    return this->value;  // OK: explicit this-> access
}
```

---

## BSC-E0606: Static Function in Struct Scope

**Diagnostic:** `err_static_class_func`

**Message:** `function declared in struct scope cannot have 'static' storage class`

**Cause:**
Member functions of `_Owned struct` cannot be declared `static`. Use a regular (non-member) function if you need a static function.

**Fix:**
- Remove the `static` keyword from the member function

---

## BSC-E0607: Direct Destructor Call

**Diagnostic:** `err_destructor_call`

**Message:** `destructor <name> cannot be called directly`

**Cause:**
Destructors are called automatically when an `_Owned struct` variable goes out of scope. You cannot invoke them manually.

**Example (bad):**
```c
void f() {
    Foo x = Foo_new();
    ~Foo(&x);  // ERROR: destructor cannot be called directly
}
```

**Fix:**
- Let the destructor run automatically at scope end
- If you need early cleanup, use a block scope

```c
void f() {
    {
        Foo x = Foo_new();
    }  // destructor runs here automatically
}
```

---

## BSC-E0608: Move 'this' in Destructor

**Diagnostic:** `err_assignment_in_destructor`

**Message:** `'this' cannot be moved in destructor`

**Cause:**
Inside a destructor, the `this` pointer represents the object being destroyed. Moving `this` to another variable would transfer ownership away from the destruction process, leaving the object in an invalid state.

**Fix:**
- Don't move `this` in the destructor; only free the owned fields

---

## BSC-E0609: Destructor Name Mismatch

**Diagnostic:** `err_owned_struct_destructor_name`

**Message:** `expected the _Owned struct name after '~' to name the enclosing _Owned struct`

**Cause:**
The name after `~` in a destructor declaration doesn't match the struct name. Destructors must be named `~StructName`.

**Fix:**
```c
_Owned struct Foo { _Public: int *_Owned p; };

void ~Foo(Foo *this) {  // OK: matches struct name
    free_owned<int>(this->p);
}
```

---

## BSC-E0610: Destructor Missing Body

**Diagnostic:** `err_owned_struct_destructor_body`

**Message:** `destructor must have a function body`

**Cause:**
You declared a destructor without providing a function body. Destructors cannot be forward-declared; they must be defined with a body.

**Fix:**
- Provide a function body that frees all `_Owned` fields

---

## BSC-E0611: Invalid Destructor Parameter Type

**Diagnostic:** `invalid_param_for_destructor`

**Message:** `the parameter of destructor must be '<Type> this'`

**Cause:**
The destructor's parameter must be a pointer to the struct type, named `this`.

**Fix:**
```c
void ~Foo(Foo *this) { /* ... */ }  // OK
```

---

## BSC-E0612: Destructor Parameter Count

**Diagnostic:** `invalid_param_num_for_destructor`

**Message:** `destructor can only have one parameter`

**Cause:**
Destructors take exactly one parameter: `StructName *this`. Additional parameters are not allowed.

**Fix:**
- Remove extra parameters; if you need additional cleanup logic, call helper functions from within the destructor
