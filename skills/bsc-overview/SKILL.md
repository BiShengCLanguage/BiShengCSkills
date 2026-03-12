---
name: bsc-overview
description: "BiSheng C language overview. When you need to understand what BiSheng C is, its file types (.cbs/.hbs), compiler usage, or get an overview of all BSC features and keywords, use this Skill."
---

# BiSheng C Overview Skill

## 1. What is BiSheng C

BiSheng C (BSC) is a **superset of C** with Rust-inspired memory safety, traits, generics, and async/await. All valid C code is valid BSC code.

- Source files: `.cbs`
- Header files: `.hbs`
- Compiler: clang fork — `clang file.cbs -o output`

## 2. Feature Overview

| Feature | Keywords | Description |
|---------|----------|-------------|
| Member functions | `TypeName::method`, `this`, `This` | Attach methods to any type (struct, primitive, etc.) |
| Generics | `<T>`, `<T, int N>` | Compile-time monomorphization, constant generics, type aliases |
| Traits | `_Trait`, `_Impl`, `This*` | Interface abstraction with vtable dynamic dispatch |
| Ownership | `_Owned`, `_Nullable`, `_Public` | Move semantics, RAII destructors, compile-time memory safety |
| Borrowing | `_Borrow`, `&_Const`, `&_Mut` | Non-owning references with lifetime enforcement |
| Safe zones | `_Safe`, `_Unsafe` | Compiler-enforced memory safety regions |
| Coroutines | `_Async`, `_Await`, `Future` | Stackless coroutines with poll-based execution |
| constexpr | `constexpr`, `_Static_assert`, `if constexpr` | Compile-time evaluation and type-specialized branches |
| Type traits | `is_integral<T>()`, `is_pointer<T>()`, etc. | Compile-time type classification |
| Standard library | `Vec<T>`, `String`, `Option<T>`, `Result<T>` | Safe containers with RAII |

## 3. Quick Syntax Summary

| Feature | Syntax |
|---------|--------|
| Source/header | `.cbs` / `.hbs` |
| Member function | `RetType TypeName::method(TypeName* this, ...)` |
| Static member | `RetType TypeName::method(...)` (no this) |
| Generic function | `T func<T>(T arg)` |
| Generic struct | `struct S<T> { T field; };` |
| Constant generic | `struct A<T, int N> { T data[N]; };` |
| Type alias (generic) | `typedef Alias<T> = OldType<T>;` |
| Trait definition | `_Trait Name { RetType method(This* this); };` |
| Trait impl | `_Impl _Trait Name for TypeName;` |
| Trait pointer | `_Trait Name* ptr = &value;` |
| Owned pointer | `T *_Owned` |
| Owned struct | `_Owned struct S { _Public: ...; ~S(S this) {...} };` |
| Immutable borrow | `const T *_Borrow ref = &_Const value;` |
| Mutable borrow | `T *_Borrow ref = &_Mut value;` |
| Safe function | `_Safe RetType func(ParamType param) { ... }` |
| Unsafe block | `_Unsafe { ... }` |
| Async function | `_Async RetType func(...) { ... }` |
| Await | `T result = _Await asyncFunc();` |
| constexpr if | `if constexpr (expr) { ... }` |
| Destructor | `~TypeName(TypeName this) { ... }` (inside `_Owned struct`) |

## 4. Skill Index

> For member functions, see `bsc-member-function` Skill
> For generics, see `bsc-generic` Skill
> For traits, see `bsc-trait` Skill
> For ownership, see `bsc-ownership` Skill
> For borrowing, see `bsc-borrowing` Skill
> For safe zones, see `bsc-safe-zone` Skill
> For coroutines, see `bsc-coroutine` Skill
> For constexpr, see `bsc-constexpr` Skill
> For standard library, see `bsc-stdlib` Skill
> For compilation, see `bsc-compile` Skill
> For common pitfalls, see `bsc-common-mistakes` Skill
> For error codes and diagnostics, see `bsc-errors` Skill
