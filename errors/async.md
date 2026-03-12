# Async Errors (BSC-E08xx)

BSC supports asynchronous programming with `_Async` functions and `_Await` expressions. `_Async` functions return `Future` types and can be awaited by callers.

---

## BSC-E0801: Async on Non-Function

**Diagnostic:** `err_async_non_function`

**Message:** `'_Async' can only appear on functions`

**Cause:**
The `_Async` qualifier was applied to something other than a function declaration. Only functions can be asynchronous.

**Fix:**
- Move `_Async` to a function declaration

```c
_Async void fetch_data() { /* ... */ }  // OK
```

---

## BSC-E0802: Async Main

**Diagnostic:** `err_async_main`

**Message:** `'main' is not allowed to be declared _Async`

**Cause:**
The `main` function cannot be `_Async` because it is the program entry point and has a fixed calling convention defined by the C runtime.

**Fix:**
- Create a separate `_Async` function and call it from `main`

```c
_Async void async_main() { /* ... */ }

int main() {
    // launch async_main via your async runtime
    return 0;
}
```

---

## BSC-E0803: Await in Invalid Scope

**Diagnostic:** `err_await_invalid_scope`

**Message:** `_Await expression is not allowed to appear in <context>`

**Cause:**
`_Await` was used in a context where it is not valid, such as inside a non-async function, a global initializer, or certain control flow constructs.

**Fix:**
- Use `_Await` only inside `_Async` functions

---

## BSC-E0804: Unsupported Feature in Async Function

**Diagnostic:** `err_async_func_unsupported`

**Message:** `_Async function does not support <feature>`

**Cause:**
Certain language features are not supported inside `_Async` functions due to the coroutine transformation. This may include specific control flow constructs or variable-length arrays.

**Fix:**
- Refactor the unsupported feature out of the `_Async` function
- Move the unsupported operation into a synchronous helper function

---

## BSC-E0805: Invalid Await Expression

**Diagnostic:** `err_not_a_async_call`

**Message:** `the _Await expression's external function declaration must be modified by _Async or return 'Future' type`

**Cause:**
`_Await` can only be applied to calls that return a `Future` type or to functions declared `_Async`. The expression you tried to await does not meet either condition.

**Example (bad):**
```c
int compute(int x) { return x * 2; }

_Async void f() {
    int result = _Await compute(5);  // ERROR: compute is not _Async
}
```

**Fix:**
- Make the called function `_Async`, or
- Ensure it returns a `Future` type

```c
_Async int compute(int x) { return x * 2; }

_Async void f() {
    int result = _Await compute(5);  // OK
}
```

---

## BSC-E0806: Required Function Not Found

**Diagnostic:** `err_function_not_found`

**Message:** `'<name>' was not found, you need to include <header> before using the '_Async' keyword`

**Cause:**
The `_Async` runtime requires certain support functions to be declared. You are missing the necessary header include.

**Fix:**
- Include the required header as specified in the error message

---

## BSC-E0807: Missing Await in Async Function

**Diagnostic:** `err_await_expression_not_found`

**Message:** `_Await expression was not found in _Async function`

**Cause:**
An `_Async` function must contain at least one `_Await` expression. A function declared `_Async` without any awaits should be a regular function instead.

**Fix:**
- Add an `_Await` expression, or
- Remove the `_Async` qualifier if the function doesn't need to be asynchronous

---

## BSC-E0808: Future Return Should Not Be Async

**Diagnostic:** `err_invalid_async_function`

**Message:** `function which returns 'Future' type should not be modified by '_Async'`

**Cause:**
A function that already returns a `Future` type should not also be marked `_Async`. The `_Async` qualifier automatically wraps the return type in `Future`; applying both would result in double-wrapping.

**Fix:**
- Remove `_Async` if you explicitly return `Future`
- Or remove the `Future` return type and let `_Async` handle it

```c
// Either:
Future compute(int x) { /* manually returns Future */ }

// Or:
_Async int compute(int x) { /* compiler wraps return in Future */ }
```
