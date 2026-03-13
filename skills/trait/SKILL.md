---
name: bsc-trait
description: "BiSheng C traits. When you need to understand _Trait definition, _Impl registration, trait pointers, dynamic dispatch (vtable), generic traits, or trait-based polymorphism, use this Skill."
---

# BiSheng C Traits Skill

## 1. Overview

Interface abstraction with vtable-based dynamic dispatch. Define a set of methods, implement them for concrete types, and call through trait pointers for polymorphism.

## 2. Defining Traits

```c
_Trait Printable {
    void print(This* this);          // First param MUST be `This* this`
    int toInt(This* this);
};
```

- Only function declarations inside `_Trait` body (no implementations)
- First param must be `This* this` — named exactly `this`
- `_Trait` definitions only at top-level scope
- Empty traits are allowed: `_Trait T {};`
- Cannot extend member functions on a trait type: `void _Trait T::method(_Trait T* this)` is an error

## 3. Implementing Traits

```c
struct Circle { float r; };

void struct Circle::print(struct Circle* this) {
    printf("Circle(r=%f)\n", this->r);
}
int struct Circle::toInt(struct Circle* this) {
    return (int)this->r;
}

_Impl _Trait Printable for struct Circle;  // all methods must exist before this line
```

- Can implement for primitives: `_Impl _Trait Printable for int;`
- Can implement for typedef-ed types
- All trait methods must be defined **before** the `_Impl` statement
- Cannot implement trait for a trait type: `_Impl _Trait T for _Trait T;` is an error
- Cannot implement trait for an instantiated generic struct type:
  ```c
  struct G<T> {};
  _Impl _Trait Printable for struct G<int>;  // ERROR: cannot _Impl _Trait for an instantiated type
  ```

## 4. Trait Pointers (Dynamic Dispatch)

```c
void printAnything(_Trait Printable* obj) {
    obj->print();  // vtable dispatch
}

int main() {
    struct Circle c = {.r = 3.14};
    _Trait Printable* p = &c;      // implicit conversion
    p->print();
    printAnything(&c);

    int x = 42;
    p = &x;                        // OK if int implements Printable
    p->print();
    return 0;
}
```

- Only pointer form: `_Trait T* p;` (NOT `_Trait T p;`)
- Trait pointers cannot be dereferenced with `*`
- Can cast to concrete type: `int* q = (int*)p;` (explicit only, no implicit)
- Can cast to `void*`: `void* v = (void*)p;` — but `void*` CANNOT be cast back to trait pointer
- Comparison limited to `==` and `!=` only:
  - `p == NULL` / `p != NULL` — OK
  - `p1 == p2` — OK if same trait type; warning if different trait types
  - `p == concretePtr` — OK if concrete type implements the trait; warning if it does not
- Can typedef: `typedef _Trait Printable { ... } P;`

## 5. Generic Traits

```c
_Trait Converter<T> {
    T convert(This* this);
};

int int::convert(int* this) { return *this; }
_Impl _Trait Converter<int> for int;
```

- Only instantiated trait can be `_Impl`'d
- `_Impl _Trait Converter<T> for int;` is ERROR — `T` is undefined

## 6. Complete Example

```c
#include <stdio.h>

_Trait Describable {
    void describe(This* this);
    int value(This* this);
};

struct Circle { float radius; };

void struct Circle::describe(struct Circle* this) {
    printf("Circle with radius %f\n", this->radius);
}
int struct Circle::value(struct Circle* this) {
    return (int)(this->radius * this->radius * 3);
}
_Impl _Trait Describable for struct Circle;

void int::describe(int* this) {
    printf("Integer: %d\n", *this);
}
int int::value(int* this) {
    return *this;
}
_Impl _Trait Describable for int;

// Dynamic dispatch through trait pointer
void showInfo(_Trait Describable* obj) {
    obj->describe();                        // vtable dispatch
    printf("  value = %d\n", obj->value()); // vtable dispatch
}

int main() {
    struct Circle c = {.radius = 5.0};
    int x = 42;

    _Trait Describable* p = &c;  // implicit conversion
    showInfo(p);                 // "Circle with radius 5.0" / "value = 75"

    p = &x;                      // reassign to different implementing type
    showInfo(p);                 // "Integer: 42" / "value = 42"

    // Compare trait pointers
    _Trait Describable* p2 = &c;
    if (p != p2) {
        printf("Different objects\n");
    }
    return 0;
}
```

> For member function basics, see `bsc-member-function` Skill
> For generic functions/structs, see `bsc-generic` Skill
> For trait errors (BSC-E05xx), see `bsc-errors` Skill
