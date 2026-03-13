---
name: bsc-coroutine
description: "BiSheng C coroutines. When you need to understand _Async functions, _Await expressions, Future<T> trait, PollResult<T>, poll/free, or async/await restrictions, use this Skill."
---

# BiSheng C Coroutines Skill

## 1. Overview

Stackless coroutines. Requires `#include "future.hbs"`.

## 2. PollResult<T> and Future<T>

`poll()` returns `struct PollResult<T>`, not void. This is critical for checking completion.

```c
struct PollResult<T> {
    _Bool isPending;  // true if not yet complete
    T res;            // result value (valid when isPending == false)
};

// Methods: is_completed(this, &out), pending(), completed(result)

_Trait Future<T> {
    struct PollResult<T> poll(This* this);
    void free(This* this);
};
```

## 3. Basic Syntax

```c
#include "future.hbs"

_Async int fetchData(int id) {
    return id * 2;
}

_Async int processAll() {
    int a = _Await fetchData(1);
    int b = _Await fetchData(2);
    return a + b;
}

int main() {
    _Trait Future<int>* task = processAll();  // returns Future, does not execute
    struct PollResult<int> pr = task->poll(); // drives the coroutine, returns PollResult
    // pr.isPending == false when done; pr.res holds the result
    task->free();                             // free coroutine resources
    return 0;
}
```

## 4. Rules

- `_Async` functions return `_Trait Future<ReturnType>*` when called
- For `void` return: use `_Trait Future<struct Void>*`
- `_Await` can only appear inside `_Async` functions
- `_Async` supports recursion
- `_Async` can modify member functions: `_Async void int::g(int* this);`
- `constexpr` cannot modify `_Async` functions
- No variable-length arrays in `_Async` functions

### 4.1 Where `_Await` CAN appear

- Assignments: `int x = _Await f();`
- Return statements: `return _Await f();`
- Nested `_Await` calls: `_Await f(_Await g())`
- Function args with no other side-effect expressions: `f(3, _Await g())`
- Directly awaiting a Future variable: `_Await futurePtr;`

### 4.2 Where `_Await` CANNOT appear

- if/while/for/do-while conditions: `if (_Await f()) { ... }`
- Binary expressions: `_Await f() + 1`
- Function args alongside other function calls (side-effects): `f(t(), _Await g())`
- Multiple `_Await` in same call args: `f(_Await g(), _Await h())`

The rule for function arguments: `_Await` cannot coexist with other side-effect expressions (function calls) in the same argument list. Literals and variables are fine.

### 4.3 Workarounds

```c
// ❌ Wrong: binary expression
int result = _Await compute(1) + _Await compute(2);

// ✅ Correct: split into assignments
int a = _Await compute(1);
int b = _Await compute(2);
int result = a + b;

// ❌ Wrong: side-effect expression alongside _Await
test(t(), _Await read(2));

// ✅ Correct: pre-evaluate the side-effect call
int tmp = t();
test(tmp, _Await read(2));
```

## 5. Complete Example

```c
#include "future.hbs"
#include <stdio.h>

_Async int computeValue(int x) {
    return x * 2;
}

// Recursion supported
_Async int factorial(int n) {
    if (n <= 1) return 1;
    int sub = _Await factorial(n - 1);
    return n * sub;
}

// _Await on a Future variable directly
_Async int awaitVariable() {
    _Trait Future<int>* fut = computeValue(5);
    return _Await fut;
}

_Async void logMessage(int id) {
    int val = _Await computeValue(id);
}

int main() {
    _Trait Future<int>* task1 = processData(5);
    struct PollResult<int> pr1 = task1->poll();
    // pr1.res contains the result when pr1.isPending == false
    task1->free();

    _Trait Future<struct Void>* task2 = logMessage(42);
    task2->poll();
    task2->free();

    return 0;
}
```

> For trait pointers (Future<T> uses them), see `bsc-trait` Skill
> For async errors (BSC-E08xx), see `bsc-errors` Skill
