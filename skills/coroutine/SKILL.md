---
name: bsc-coroutine
description: "BiSheng C coroutines. When you need to understand _Async functions, _Await expressions, Future<T> trait, poll/free, or async/await restrictions, use this Skill."
---

# BiSheng C Coroutines Skill

## 1. Overview

Stackless coroutines. Requires `#include "future.hbs"`.

## 2. Syntax

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
    task->poll();                              // drives the coroutine
    task->free();                              // free coroutine resources
    return 0;
}
```

## 3. Rules

- `_Async` functions return `_Trait Future<ReturnType>*` when called
- For `void` return: use `_Trait Future<struct Void>*`
- `_Await` can only appear inside `_Async` functions

### 3.1 Where `_Await` CAN appear

- Assignments: `int x = _Await f();`
- Return statements: `return _Await f();`
- Nested `_Await` calls: `_Await f(_Await g())`
- Single function argument: `f(_Await g())`

### 3.2 Where `_Await` CANNOT appear

- if/while/for conditions: ❌ `if (_Await f()) { ... }`
- Binary expressions: ❌ `_Await f() + 1`
- Multiple function arguments: ❌ `f(_Await g(), _Await h())`

### 3.3 Workaround for binary expressions

```c
// ❌ Wrong
int result = _Await compute(1) + _Await compute(2);

// ✅ Correct
int a = _Await compute(1);
int b = _Await compute(2);
int result = a + b;
```

- No variable-length arrays in `_Async` functions

## 4. Complete Example

```c
#include "future.hbs"
#include <stdio.h>

_Async int computeValue(int x) {
    return x * 2;
}

_Async int processData(int start) {
    int a = _Await computeValue(start);
    int b = _Await computeValue(start + 10);
    return a + b;
}

_Async int nestedAwait(int x) {
    int result = _Await computeValue(_Await computeValue(x));
    return result;
}

_Async void logMessage(int id) {
    int val = _Await computeValue(id);
}

int main() {
    _Trait Future<int>* task1 = processData(5);
    task1->poll();
    task1->free();

    _Trait Future<int>* task2 = nestedAwait(3);
    task2->poll();
    task2->free();

    _Trait Future<struct Void>* task3 = logMessage(42);
    task3->poll();
    task3->free();

    return 0;
}
```

> For trait pointers (Future<T> uses them), see `bsc-trait` Skill
> For async errors (BSC-E08xx), see `bsc-errors` Skill
