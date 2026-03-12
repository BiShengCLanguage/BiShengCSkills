---
name: bsc-member-function
description: "BiSheng C member functions. When you need to understand how to attach methods to structs, primitives, or other types using TypeName::method syntax, static methods, this pointer, This keyword, or method call syntax, use this Skill."
---

# BiSheng C Member Functions Skill

## 1. Overview

Attach methods to any type (struct, union, enum, int, float, etc.) without changing its memory layout. Three forms: instance methods, value receivers, and static methods.

## 2. Syntax

```c
// Instance method — first param is `this` pointer
RetType TypeName::method(TypeName* this, OtherParams...) { body }

// Value receiver — first param is `this` by value
RetType TypeName::method(TypeName this) { body }

// Static method — no `this` param
RetType TypeName::staticMethod(Params...) { body }

// `This` is a shorthand for the enclosing type name
RetType TypeName::method(This* this) { body }
```

## 3. Rules

- `this` must be the first parameter if present
- No method overloading or redefinition
- Cannot add methods to: `void`, pointer types, array types, function types, cv-qualified types (e.g. `const int`)
- Can add methods to primitives: `int`, `float`, `char`, etc.
- Must use `struct` keyword unless typedef-ed: `void struct S::f(struct S* this) {}`
- typedef-ed names work: `typedef struct { int x; } Vec2; void Vec2::f(This* this) {}`
- Method names must not collide with member variable names

## 4. Call Syntax

- Dot syntax: `obj.method()` for instances
- Arrow syntax: `ptr->method()` for pointers
- Explicit: `TypeName::method(&obj)` — equivalent to dot syntax

## 5. Complete Example

```c
#include <stdio.h>

struct Person {
    char name[32];
    int age;
};

// Instance methods
char* struct Person::getName(struct Person* this) {
    return this->name;
}

int struct Person::getAge(struct Person* this) {
    return this->age;
}

// Method on primitive type
void int::print(int* this) {
    printf("%d", *this);
}

// Value receiver
int int::doubled(int this) {
    return this * 2;
}

// Static method (no this)
struct Person struct Person::create(const char* name, int age) {
    struct Person p;
    int i = 0;
    while (name[i] != '\0' && i < 31) {
        p.name[i] = name[i];
        i++;
    }
    p.name[i] = '\0';
    p.age = age;
    return p;
}

int main() {
    struct Person p = struct Person::create("Alice", 30);
    printf("Name: %s\n", p.getName());
    printf("Age: %d\n", p.getAge());

    struct Person* pp = &p;
    printf("Via pointer: %s\n", pp->getName());

    int x = 21;
    x.print();
    printf("\n");
    int d = x.doubled();
    printf("Doubled: %d\n", d);

    printf("Explicit: %d\n", struct Person::getAge(&p));
    return 0;
}
```

> For generic member functions, see `bsc-generic` Skill
> For trait methods using This*, see `bsc-trait` Skill
> For member function errors (BSC-E11xx), see `bsc-errors` Skill
