---
name: bsc-generic
description: "BiSheng C generics. When you need to understand generic functions, generic structs, constant generics, generic type aliases, generic member functions, or type deduction, use this Skill."
---

# BiSheng C Generics Skill

## 1. Overview

Compile-time monomorphization — no runtime overhead. The compiler generates specialized code for each type used.

## 2. Generic Functions

```c
T max<T>(T a, T b) {
    return a > b ? a : b;
}

void swap<T>(T* a, T* b) {
    T tmp = *a;
    *a = *b;
    *b = tmp;
}

int main() {
    int m1 = max<int>(3, 5);       // explicit instantiation
    int m2 = max(3, 5);            // implicit type deduction
    float m3 = max<float>(1.2, 2.5);
    return 0;
}
```

## 3. Generic Structs

```c
struct Pair<T1, T2> {
    T1 first;
    T2 second;
};

T1 struct Pair<T1, T2>::getFirst(This* this) {
    return this->first;
}

int main() {
    struct Pair<int, float> p = {.first = 1, .second = 2.0};
    int f = p.getFirst();
    Pair<int, float> p2 = p;  // `struct` can be omitted with generic struct types
    return 0;
}
```

## 4. Constant Generics

```c
struct Array<T, int N> {
    T data[N];
};

int sumN<int N>(int arr[N]) {
    int s = 0;
    for (int i = 0; i < N; i++) s += arr[i];
    return s;
}

int main() {
    struct Array<int, 5> a;
    constexpr int sz = 10;
    struct Array<float, sz> b;  // constexpr OK as arg
    return 0;
}
```

- Constant generic params: integer types only (int, short, long, unsigned, etc.)
- Constant generic args: integer literals, constexpr variables, constexpr function calls

## 5. Generic Type Aliases

```c
// New-style typedef required for generic aliases:
typedef Alias<T> = T*;
typedef IntArray<int N> = int[N];
typedef MyPair<T> = struct Pair<T, T>;

// Non-generic new-style also works:
typedef Int64 = long int;
```

- Cannot define generic type aliases inside function bodies
- Cannot extend member functions on a generic type alias

## 6. Generic Member Functions

```c
struct MyStruct<T> { T val; };

T struct MyStruct<T>::get(This* this) { return this->val; }

T static struct MyStruct<T>::zero() { T z = 0; return z; }

int main() {
    struct MyStruct<int> s = {.val = 42};
    int v = s.get();
    int z = MyStruct<int>::zero();
    return 0;
}
```

## 7. Complete Example

```c
#include <stdio.h>

T max<T>(T a, T b) {
    return a > b ? a : b;
}

void swap<T>(T* a, T* b) {
    T tmp = *a;
    *a = *b;
    *b = tmp;
}

int sizeOf<T>() {
    return sizeof(T);
}

int main() {
    int m1 = max<int>(3, 7);
    printf("max<int>(3, 7) = %d\n", m1);

    float m2 = max<float>(1.5, 2.3);
    printf("max<float>(1.5, 2.3) = %f\n", m2);

    int m3 = max(10, 20);
    printf("max(10, 20) = %d\n", m3);

    int a = 1, b = 2;
    swap<int>(&a, &b);
    printf("After swap: a=%d, b=%d\n", a, b);

    printf("sizeof(int) = %d\n", sizeOf<int>());
    printf("sizeof(double) = %d\n", sizeOf<double>());
    return 0;
}
```

> For member function basics, see `bsc-member-function` Skill
> For generic traits, see `bsc-trait` Skill
> For constexpr generic functions, see `bsc-constexpr` Skill
> For generics/constexpr errors (BSC-E09xx), see `bsc-errors` Skill
