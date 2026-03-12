---
name: bsc-constexpr
description: "BiSheng C constexpr. When you need to understand constexpr variables, constexpr functions, _Static_assert, constexpr if, type traits (is_integral, is_pointer, etc.), or compile-time evaluation, use this Skill."
---

# BiSheng C constexpr Skill

## 1. constexpr Variables

```c
constexpr int SIZE = 1024;
constexpr int DOUBLED = SIZE * 2;
int arr[SIZE];  // OK: constexpr as array size
_Static_assert(SIZE == 1024, "wrong");
```

- Must be initialized. Integer/bool/char types only (no float/double)
- Cannot be modified after definition
- Initializer must be a constant expression

## 2. constexpr Functions

```c
constexpr int factorial(int n) {
    if (n <= 1) return 1;
    return n * factorial(n - 1);
}

constexpr int result = factorial(5);  // evaluated at compile time
int runtime_result = factorial(x);    // also works at runtime
```

- Params and return: compile-time computable types only
- Body: no static vars, no non-constexpr calls, no external non-constexpr vars, no asm
- Can modify constexpr generic functions: `constexpr int f<T>() { ... }`
- Can modify static member functions: `constexpr int int::foo() { ... }`
- Cannot modify instance member functions (this pointer is not constexpr)

## 3. constexpr if

Requires `#include <bsc_type_traits.hbs>`.

```c
#include <bsc_type_traits.hbs>

void process<T>(T value) {
    if constexpr (is_pointer<T>()) {
        void* p = (void*)value;        // only compiled when T is pointer
    } else if constexpr (is_integral<T>()) {
        int n = value;                 // only compiled when T is integer
    } else {
        // generic fallback
    }
}
```

- Condition must be compile-time boolean constant expression
- False branch is discarded (not type-checked in generic context)
- Enables type-specialized behavior without overloading

## 4. Type Traits

Require `#include <bsc_type_traits.hbs>`.

### 4.1 Type Classification

```c
constexpr bool is_integral<T>();         // int, char, bool, etc.
constexpr bool is_floating_point<T>();   // float, double
constexpr bool is_pointer<T>();
constexpr bool is_function<T>();
constexpr bool is_array<T>();
constexpr bool is_struct<T>();
constexpr bool is_union<T>();
constexpr bool is_enum<T>();
constexpr bool is_void<T>();
```

### 4.2 Type Properties

```c
constexpr bool is_signed<T>();
constexpr bool is_unsigned<T>();
constexpr bool is_const<T>();
constexpr bool is_volatile<T>();
constexpr bool is_move_semantic<T>();    // _Owned pointer, _Owned struct, or struct with _Owned members
constexpr bool is_owned_pointer<T>();
constexpr bool is_owned_struct<T>();
constexpr size_t rank<T>();              // array dimension count
constexpr size_t extent<T, size_t N>();  // size of Nth dimension
```

### 4.3 Type Relationships

```c
constexpr bool is_same<T1, T2>();
constexpr bool is_convertible<From, To>();
```

### 4.4 Conditional Type Alias

Requires `#include <bsc_conditional.hbs>`.

```c
#include <bsc_conditional.hbs>
typedef conditional<int C, T, F> = __conditional(int C, T, F);

conditional<1, int, float> x = 42;     // x is int
conditional<0, int, float> y = 3.14;   // y is float
```

## 5. Complete Example

```c
#include <stdio.h>
#include <bsc_type_traits.hbs>

constexpr int fib(int n) {
    if (n <= 1) return n;
    return fib(n - 1) + fib(n - 2);
}

_Static_assert(fib(10) == 55, "fib(10) should be 55");

constexpr int FIB10 = fib(10);
int arr[FIB10];  // array of 55 elements

void printTyped<T>(T value) {
    if constexpr (is_integral<T>()) {
        printf("int: %d\n", (int)value);
    } else if constexpr (is_floating_point<T>()) {
        printf("float: %f\n", (double)value);
    } else if constexpr (is_pointer<T>()) {
        printf("pointer: %p\n", (void*)value);
    }
}

int main() {
    printf("fib(10) = %d\n", FIB10);
    printTyped<int>(42);
    printTyped<float>(3.14f);
    int x = 10;
    printTyped<int*>(&x);
    return 0;
}
```

> For generic functions, see `bsc-generic` Skill
> For generics/constexpr errors (BSC-E09xx), see `bsc-errors` Skill
