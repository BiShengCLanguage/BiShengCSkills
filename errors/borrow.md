# BSC Borrow Checking Errors (BSC-E02xx)

This document covers all borrow checking diagnostics emitted by BishengC (BSC).
BSC enforces Rust-like borrow rules at compile time: a value may have **at most one
mutable borrow** or **any number of immutable borrows** at a time, and every borrow
must not outlive the value it borrows from.

> **Controlling these diagnostics.** All borrow errors fall under `-Wbsc-borrow`.
> Individual flags are listed with each error below.

---

## Borrow State Conflict Errors (New Borrow Checker)

---

## BSC-E0201: Cannot assign to a borrowed variable

**Diagnostic:** `err_borrow_assign_when_borrowed`
**Flag:** `-Wassign-borrowed`
**Message:** `cannot assign to '%0' because it is borrowed`

**Cause:**
You attempted to write to a variable while an outstanding borrow (via a `_Borrow`
pointer) still exists. The borrow guarantees the pointed-to value will not change
for the lifetime of the borrow. Assigning through the original name would violate
that guarantee and could cause the borrower to observe unexpected mutations.

**Example (bad):**

```c
void f(void) {
    int x = 10;
    const int *_Borrow bp = &_Const x;  // immutable borrow of x
    x = 20;          // ERROR: cannot assign to 'x' because it is borrowed
    printf("%d", *bp);
}
```

**Fix:**
- End the borrow before assigning by limiting the scope of the borrow pointer.
- Restructure code so that the assignment occurs before the borrow is created.

```c
void f(void) {
    int x = 10;
    {
        const int *_Borrow bp = &_Const x;
        printf("%d", *bp);
    }
    x = 20;  // OK: borrow has ended
}
```

**See also:** BSC-E0203, BSC-E0204, BSC-E0212

---

## BSC-E0202: Cannot move out of a borrowed variable

**Diagnostic:** `err_borrow_move_when_borrowed`
**Flag:** `-Wmove-borrowed`
**Message:** `cannot move out of '%0' because it is borrowed`

**Cause:**
Moving an `_Owned` value transfers ownership and invalidates the source. If any
borrow exists that points into that value, the move would leave the borrow dangling.
BSC prohibits moves while any borrow (mutable or immutable) is active on the value.

**Example (bad):**

```c
void f(void) {
    int *_Owned p = safe_malloc<int>(42);
    const int *_Borrow bp = &_Const *p;
    int *_Owned q = p;   // ERROR: cannot move out of 'p' because it is borrowed
    printf("%d", *bp);
}
```

**Fix:**
- End the borrow before the move.
- Clone / copy the value instead of moving it, if applicable.

```c
void f(void) {
    int *_Owned p = safe_malloc<int>(42);
    {
        const int *_Borrow bp = &_Const *p;
        printf("%d", *bp);
    }
    int *_Owned q = p;  // OK: borrow has ended
    free_owned<int>(q);
}
```

**See also:** BSC-E0201, BSC-E0216

---

## BSC-E0203: Cannot use a mutably borrowed variable

**Diagnostic:** `err_borrow_use_when_mut_borrowed`
**Flag:** `-Wuse-mutably-borrowed`
**Message:** `cannot use '%0' because it was mutably borrowed`

**Cause:**
While a mutable borrow is active, the original variable cannot be read through its
original path. A mutable borrow grants exclusive access to the borrower; allowing
reads through the original name would break this exclusivity and could lead to
observing partially updated state.

**Example (bad):**

```c
void f(void) {
    int x = 5;
    int *_Borrow mp = &_Mut x;  // mutable borrow of x
    int y = x;       // ERROR: cannot use 'x' because it was mutably borrowed
    *mp = 10;
}
```

**Fix:**
- Read the value through the mutable borrow pointer instead.
- End the mutable borrow before reading the original variable.

```c
void f(void) {
    int x = 5;
    int *_Borrow mp = &_Mut x;
    int y = *mp;     // OK: read through the borrow
    *mp = 10;
}
```

**See also:** BSC-E0201, BSC-E0204, BSC-E0213

---

## BSC-E0204: Cannot borrow as mutable more than once

**Diagnostic:** `err_borrow_mut_borrow_more_than_once`
**Flag:** `-Wrepeated-borrow`
**Message:** `cannot borrow '%0' as mutable more than once at a time`

**Cause:**
BSC enforces that only one mutable borrow of a given value can exist at any time.
Multiple mutable borrows would allow aliased mutation, which can cause data races
in concurrent code and undefined behavior even in single-threaded code.

**Example (bad):**

```c
void f(void) {
    int x = 1;
    int *_Borrow m1 = &_Mut x;
    int *_Borrow m2 = &_Mut x;  // ERROR: cannot borrow 'x' as mutable more than once
    *m1 = 2;
    *m2 = 3;
}
```

**Fix:**
- Use a single mutable borrow and pass it to the code that needs it.
- End the first mutable borrow before creating the second.

```c
void f(void) {
    int x = 1;
    {
        int *_Borrow m1 = &_Mut x;
        *m1 = 2;
    }
    {
        int *_Borrow m2 = &_Mut x;
        *m2 = 3;
    }
}
```

**See also:** BSC-E0205, BSC-E0206, BSC-E0210

---

## BSC-E0205: Cannot borrow as immutable while mutably borrowed

**Diagnostic:** `err_borrow_immut_borrow_when_mut_borrowed`
**Flag:** `-Wrepeated-borrow`
**Message:** `cannot borrow '%0' as immutable because it is also borrowed as mutable`

**Cause:**
You cannot create an immutable borrow while a mutable borrow of the same value
exists. The mutable borrow has exclusive access; an immutable borrow would allow
observing the value through a second path, violating exclusivity.

**Example (bad):**

```c
void f(void) {
    int x = 1;
    int *_Borrow mp = &_Mut x;
    const int *_Borrow bp = &_Const x;  // ERROR: cannot borrow 'x' as immutable
                                         //        because it is also borrowed as mutable
    *mp = 2;
    printf("%d", *bp);
}
```

**Fix:**
- End the mutable borrow before creating the immutable borrow.
- Use only one kind of borrow at a time.

```c
void f(void) {
    int x = 1;
    {
        int *_Borrow mp = &_Mut x;
        *mp = 2;
    }
    const int *_Borrow bp = &_Const x;  // OK: mutable borrow has ended
    printf("%d", *bp);
}
```

**See also:** BSC-E0204, BSC-E0206

---

## BSC-E0206: Cannot borrow as mutable while immutably borrowed

**Diagnostic:** `err_borrow_mut_borrow_when_immut_borrowed`
**Flag:** `-Wrepeated-borrow`
**Message:** `cannot borrow '%0' as mutable because it is also borrowed as immutable`

**Cause:**
You cannot create a mutable borrow while one or more immutable borrows of the same
value are still active. Immutable borrowers expect the value to remain unchanged;
a mutable borrow could modify it and break that expectation.

**Example (bad):**

```c
void f(void) {
    int x = 1;
    const int *_Borrow bp = &_Const x;
    int *_Borrow mp = &_Mut x;  // ERROR: cannot borrow 'x' as mutable
                                 //        because it is also borrowed as immutable
    *mp = 2;
    printf("%d", *bp);
}
```

**Fix:**
- End all immutable borrows before creating a mutable borrow.
- Restructure code to separate read and write phases.

```c
void f(void) {
    int x = 1;
    {
        const int *_Borrow bp = &_Const x;
        printf("%d", *bp);
    }
    int *_Borrow mp = &_Mut x;  // OK: immutable borrow has ended
    *mp = 2;
}
```

**See also:** BSC-E0204, BSC-E0205

---

## Borrow Lifetime Errors

---

## BSC-E0207: Cannot return reference to local variable

**Diagnostic:** `err_borrow_return_local_borrow`
**Flag:** `-Wreturn-local-borrow`
**Message:** `cannot return reference to local variable '%0'`

**Cause:**
Local variables are destroyed when the function returns. Returning a `_Borrow`
pointer to a local variable would create a dangling pointer: the caller would
receive a reference to memory that is no longer valid. BSC detects this at compile
time and rejects it.

**Example (bad):**

```c
const int *_Borrow bad(void) {
    int x = 42;
    return &_Const x;  // ERROR: cannot return reference to local variable 'x'
}
```

**Fix:**
- Return an `_Owned` pointer to heap-allocated memory instead.
- Pass the result through an output parameter that the caller owns.
- Return the value by copy (non-pointer) when possible.

```c
int *_Owned good_heap(void) {
    int *_Owned p = safe_malloc<int>(42);
    return p;  // OK: ownership transferred to caller
}

int good_copy(void) {
    int x = 42;
    return x;  // OK: returned by value
}
```

**See also:** BSC-E0208, BSC-E0211

---

## BSC-E0208: Value does not live long enough

**Diagnostic:** `err_borrow_not_live_long`
**Flag:** `-Wshort-life-borrow`
**Message:** `'%0' does not live long enough`

**Cause:**
The borrowed value goes out of scope while the borrow is still active. The borrow
pointer would become dangling because the value it references has been destroyed.
This commonly happens when an inner-scope variable is borrowed and the borrow
escapes to an outer scope.

**Example (bad):**

```c
void f(void) {
    const int *_Borrow bp;
    {
        int x = 10;
        bp = &_Const x;  // ERROR: 'x' does not live long enough
    }
    // x is destroyed here, but bp still references it
    printf("%d", *bp);
}
```

**Fix:**
- Extend the lifetime of the borrowed variable so it outlives the borrow.
- Move the borrow usage into the same scope as the variable.

```c
void f(void) {
    int x = 10;
    const int *_Borrow bp = &_Const x;
    printf("%d", *bp);  // OK: x is still alive
}
```

**See also:** BSC-E0207, BSC-E0209

---

## Legacy Borrow Checker Errors

The following errors are emitted by the legacy borrow checker. They may overlap
with errors from the new borrow checker (BSC-E0201 through BSC-E0208) but use
different diagnostic names and message text.

---

## BSC-E0209: Borrow pointer lives longer than target variable

**Diagnostic:** `err_borrow_live_longer_than_target_var`
**Message:** `borrow pointer variable '%0' lives longer than target variable`

**Cause:**
The `_Borrow` pointer variable has a lifetime that extends beyond the lifetime of
the variable it borrows from. When the target variable is destroyed, the borrow
pointer becomes dangling. This is the legacy checker's equivalent of BSC-E0208.

**Example (bad):**

```c
void f(void) {
    const int *_Borrow bp;
    {
        int val = 100;
        bp = &_Const val;
    }
    // ERROR: borrow pointer variable 'bp' lives longer than target variable
    printf("%d", *bp);
}
```

**Fix:**
- Ensure the target variable's scope encloses the borrow pointer's scope.
- Declare the target variable in the same or an outer scope.

```c
void f(void) {
    int val = 100;
    const int *_Borrow bp = &_Const val;
    printf("%d", *bp);  // OK: val outlives bp
}
```

**See also:** BSC-E0208, BSC-E0211

---

## BSC-E0210: At most one mutable borrow at a time

**Diagnostic:** `err_at_most_one_mut_borrow`
**Message:** `There should be at most one mutable borrow targeting to '%0' at the same time`

**Cause:**
This is the legacy checker's version of BSC-E0204. Two or more mutable `_Borrow`
pointers targeting the same variable exist simultaneously, which violates the
exclusivity rule for mutable borrows.

**Example (bad):**

```c
void f(void) {
    int x = 5;
    int *_Borrow a = &_Mut x;
    int *_Borrow b = &_Mut x;
    // ERROR: There should be at most one mutable borrow targeting to 'x'
    //        at the same time
    *a = 1;
    *b = 2;
}
```

**Fix:**
- Use only one mutable borrow at a time; end the first before creating the second.

```c
void f(void) {
    int x = 5;
    {
        int *_Borrow a = &_Mut x;
        *a = 1;
    }
    int *_Borrow b = &_Mut x;  // OK: previous borrow ended
    *b = 2;
}
```

**See also:** BSC-E0204

---

## BSC-E0211: Return value cannot borrow from local variable

**Diagnostic:** `err_return_value_borrow_local`
**Message:** `Return value cannot be a borrow from local variable '%0'`

**Cause:**
This is the legacy checker's version of BSC-E0207. The function returns a `_Borrow`
pointer that references a local variable. Once the function returns, the local is
destroyed and the returned pointer is dangling.

**Example (bad):**

```c
int *_Borrow bad(void) {
    int local = 99;
    return &_Mut local;
    // ERROR: Return value cannot be a borrow from local variable 'local'
}
```

**Fix:**
- Return an `_Owned` pointer to heap-allocated memory.
- Return by value instead of by reference.

```c
int *_Owned good(void) {
    int *_Owned p = safe_malloc<int>(99);
    return p;  // OK: ownership transferred
}
```

**See also:** BSC-E0207

---

## BSC-E0212: Cannot modify a borrowed variable

**Diagnostic:** `err_modify_after_be_borrow`
**Message:** `Can not modify '%0' because be borrowed`

**Cause:**
This is the legacy checker's version of BSC-E0201. You attempted to modify a
variable while it is borrowed. The borrow guarantees the value will remain stable
for the duration of the borrow.

**Example (bad):**

```c
void f(void) {
    int x = 10;
    const int *_Borrow bp = &_Const x;
    x = 20;  // ERROR: Can not modify 'x' because be borrowed
    printf("%d", *bp);
}
```

**Fix:**
- End the borrow before modifying the variable.
- Move the modification before the borrow is created.

```c
void f(void) {
    int x = 10;
    {
        const int *_Borrow bp = &_Const x;
        printf("%d", *bp);
    }
    x = 20;  // OK: borrow has ended
}
```

**See also:** BSC-E0201

---

## BSC-E0213: Cannot read a mutably borrowed variable

**Diagnostic:** `err_read_after_be_mut_borrow`
**Message:** `Can not read '%0' because be mut borrowed`

**Cause:**
This is the legacy checker's version of BSC-E0203. While a mutable borrow is
active, reads through the original variable name are forbidden because the mutable
borrow has exclusive access.

**Example (bad):**

```c
void f(void) {
    int x = 7;
    int *_Borrow mp = &_Mut x;
    int val = x;  // ERROR: Can not read 'x' because be mut borrowed
    *mp = 10;
}
```

**Fix:**
- Read through the mutable borrow pointer instead of the original variable.
- End the mutable borrow before reading the original variable.

```c
void f(void) {
    int x = 7;
    int *_Borrow mp = &_Mut x;
    int val = *mp;  // OK: reading through the borrow
    *mp = 10;
}
```

**See also:** BSC-E0203

---

## BSC-E0214: Cannot use an expired borrow variable

**Diagnostic:** `err_use_expired_borrow_var`
**Message:** `Can not use '%0' because expired`

**Cause:**
The `_Borrow` pointer has expired -- the value it was borrowing from has gone out
of scope or has been moved. Using an expired borrow is equivalent to dereferencing
a dangling pointer, so BSC rejects it at compile time.

**Example (bad):**

```c
void f(void) {
    const int *_Borrow bp;
    {
        int x = 42;
        bp = &_Const x;
    }
    printf("%d", *bp);  // ERROR: Can not use 'bp' because expired
}
```

**Fix:**
- Ensure the borrowed value outlives the borrow pointer.
- Restructure scopes so the borrow is used while the target is still alive.

```c
void f(void) {
    int x = 42;
    const int *_Borrow bp = &_Const x;
    printf("%d", *bp);  // OK: x is still in scope
}
```

**See also:** BSC-E0208, BSC-E0209

---

## Borrow Type/Qualifier Errors

---

## BSC-E0215: Disallowed qualifier on a _Borrow type

**Diagnostic:** `err_borrow_on_borrow`
**Message:** `%0 on a '_Borrow' qualified type is not allowed`

**Cause:**
Certain qualifiers or operations cannot be applied to a type that is already
`_Borrow` qualified. For instance, applying `_Owned` on top of `_Borrow` is
contradictory: a pointer is either owning or borrowing, not both.

**Example (bad):**

```c
void f(int *_Borrow bp) {
    int *_Owned _Borrow p = bp;
    // ERROR: _Owned on a '_Borrow' qualified type is not allowed
}
```

**Fix:**
- Remove the conflicting qualifier. Decide whether the pointer should be `_Owned` or `_Borrow`.

```c
void f(int *_Borrow bp) {
    int *_Borrow p = bp;  // OK: just _Borrow
}
```

**See also:** BSC-E0216, BSC-E0219

---

## BSC-E0216: _Borrow type does not allow move ownership

**Diagnostic:** `err_move_borrow`
**Message:** `_Borrow type does not allow move ownership`

**Cause:**
`_Borrow` pointers do not own the data they point to. You cannot transfer ownership
of a `_Borrow` pointer because there is no ownership to transfer. Only `_Owned`
pointers can be moved.

**Example (bad):**

```c
void consume(int *_Owned p) {
    free_owned<int>(p);
}

void f(void) {
    int x = 10;
    int *_Borrow bp = &_Mut x;
    consume(bp);  // ERROR: _Borrow type does not allow move ownership
}
```

**Fix:**
- Pass the borrow as a `_Borrow` parameter instead of an `_Owned` parameter.
- If ownership transfer is needed, use an `_Owned` pointer from the start.

```c
void use_val(int *_Borrow p) {
    printf("%d", *p);
}

void f(void) {
    int x = 10;
    int *_Borrow bp = &_Mut x;
    use_val(bp);  // OK: passing a borrow as a borrow
}
```

**See also:** BSC-E0202, BSC-E0215

---

## BSC-E0217: Incompatible borrow types in cast

**Diagnostic:** `err_borrow_qualcheck_incompatible`
**Message:** `incompatible borrow types, cannot cast %0 to %1`

**Cause:**
You attempted to cast between pointer types whose `_Borrow` qualifications are
incompatible. BSC tracks borrow qualifiers as part of the type system and does
not allow implicit or explicit casts that would violate borrow safety.

**Example (bad):**

```c
void f(void) {
    int x = 10;
    const int *_Borrow bp = &_Const x;
    int *_Owned op = (int *_Owned)bp;
    // ERROR: incompatible borrow types, cannot cast 'const int *_Borrow' to 'int *_Owned'
}
```

**Fix:**
- Avoid casting between `_Borrow` and `_Owned` types.
- Redesign the code to use the correct qualifier from the start.

```c
void f(void) {
    int *_Owned op = safe_malloc<int>(10);
    // work with op as _Owned directly
    free_owned<int>(op);
}
```

**See also:** BSC-E0215, BSC-E0218, BSC-E0222

---

## BSC-E0218: Incompatible borrow types in comparison

**Diagnostic:** `err_borrow_qualcheck_compare`
**Message:** `incompatible borrow types, %0 and %1 cannot be compared`

**Cause:**
You attempted to compare two pointers whose `_Borrow` qualifications are
incompatible. BSC disallows comparisons between pointers with mismatched borrow
qualifiers because such comparisons are semantically meaningless and usually
indicate a logic error.

**Example (bad):**

```c
void f(void) {
    int x = 10;
    int *_Owned op = safe_malloc<int>(10);
    int *_Borrow bp = &_Mut x;
    if (op == bp) { }
    // ERROR: incompatible borrow types, 'int *_Owned' and 'int *_Borrow' cannot be compared
    free_owned<int>(op);
}
```

**Fix:**
- Compare pointers of the same borrow qualification.
- Reconsider whether the comparison is logically correct.

```c
void f(void) {
    int x = 10;
    int y = 20;
    int *_Borrow bp1 = &_Mut x;
    int *_Borrow bp2 = &_Mut y;
    if (bp1 == bp2) { }  // OK: same qualifier
}
```

**See also:** BSC-E0217

---

## BSC-E0219: _Borrow requires a pointer or reference type

**Diagnostic:** `err_typecheck_invalid_borrow_not_pointer`
**Message:** `_Borrow type requires a pointer or reference (%0 is invalid)`

**Cause:**
The `_Borrow` qualifier can only be applied to pointer types. Applying `_Borrow` to
a non-pointer type such as `int` or a struct value is invalid because borrowing is
a concept that applies to indirection -- a borrow is a reference to data owned
elsewhere.

**Example (bad):**

```c
void f(void) {
    int _Borrow x = 10;
    // ERROR: _Borrow type requires a pointer or reference ('int _Borrow' is invalid)
}
```

**Fix:**
- Apply `_Borrow` only to pointer types.
- If you need a non-owning reference, use a pointer.

```c
void f(void) {
    int val = 10;
    int *_Borrow bp = &_Const val;  // OK: _Borrow on a pointer type
}
```

**See also:** BSC-E0215, BSC-E0223

---

## BSC-E0220: Return type _Borrow without _Borrow parameter

**Diagnostic:** `err_typecheck_borrow_func`
**Message:** `no _Borrow qualified type found in the function parameters, the return type is not allowed to be _Borrow qualified`

**Cause:**
A function that returns a `_Borrow` pointer must receive at least one `_Borrow`
parameter, because the returned borrow must refer to data that outlives the
function call. If no parameter is `_Borrow` qualified, the only possible source
for the returned borrow would be a local variable, which is always invalid.

**Example (bad):**

```c
int *_Borrow bad(int *_Owned p) {
    // ERROR: no _Borrow qualified type found in the function parameters,
    //        the return type is not allowed to be _Borrow qualified
    return &_Const *p;
}
```

**Fix:**
- Add a `_Borrow` parameter that the return value can borrow from.
- Change the return type to `_Owned` and transfer ownership instead.

```c
int *_Borrow good(int *_Borrow p) {
    return p;  // OK: returned borrow comes from a _Borrow parameter
}
```

**See also:** BSC-E0207, BSC-E0211

---

## BSC-E0221: Subscript of _Borrow pointer is not allowed

**Diagnostic:** `err_typecheck_borrow_subscript`
**Message:** `subscript of _Borrow pointer is not allowed`

**Cause:**
`_Borrow` pointers represent a borrow of a single value, not an array. Array
subscript operations (`bp[i]`) on a `_Borrow` pointer are disallowed because BSC
cannot verify that the subscript stays within the bounds of valid memory. This
prevents out-of-bounds access through borrowed pointers.

**Example (bad):**

```c
void f(int *_Borrow bp) {
    int val = bp[1];  // ERROR: subscript of _Borrow pointer is not allowed
}
```

**Fix:**
- Access the value through simple dereference (`*bp`) instead of subscript.
- If array access is needed, use a different pointer type with appropriate bounds guarantees.

```c
void f(int *_Borrow bp) {
    int val = *bp;  // OK: single-value dereference
}
```

**See also:** BSC-E0219

---

## BSC-E0222: Incompatible _Borrow function pointer types

**Diagnostic:** `err_funcPtr_incompatible`
**Message:** `incompatible _Borrow function pointer types, cannot cast %0 to %1`

**Cause:**
You attempted to cast between function pointer types that have different `_Borrow`
qualifications on their parameters or return types. BSC prevents this because
changing the borrow qualifier on a function pointer could lead to incorrect
lifetime tracking when the function is called through the cast pointer.

**Example (bad):**

```c
typedef int *_Borrow (*fn_borrow)(int *_Borrow);
typedef int *_Owned (*fn_owned)(int *_Owned);

void f(void) {
    fn_borrow fb = some_func;
    fn_owned fo = (fn_owned)fb;
    // ERROR: incompatible _Borrow function pointer types, cannot cast
    //        'fn_borrow' to 'fn_owned'
}
```

**Fix:**
- Use function pointers with matching `_Borrow` qualifications.
- Wrap the call in a new function with the correct signature.

```c
typedef int *_Borrow (*fn_borrow)(int *_Borrow);

void f(fn_borrow fb) {
    int x = 10;
    int *_Borrow bp = &_Mut x;
    int *_Borrow result = fb(bp);  // OK: types match
}
```

**See also:** BSC-E0217, BSC-E0225

---

## BSC-E0223: _Borrow variable must be initialized at declaration

**Diagnostic:** `err_borrow_not_init`
**Message:** `variable declarations of _Borrow qualified must be initialized`

**Cause:**
A `_Borrow` pointer must always refer to valid data. An uninitialized `_Borrow`
variable would be a dangling reference from the start. BSC requires that every
`_Borrow` variable is initialized at the point of declaration to ensure it
immediately references valid memory.

**Example (bad):**

```c
void f(void) {
    int *_Borrow bp;  // ERROR: variable declarations of _Borrow qualified must be initialized
    int x = 10;
    bp = &_Const x;
}
```

**Fix:**
- Initialize the `_Borrow` variable at declaration.

```c
void f(void) {
    int x = 10;
    int *_Borrow bp = &_Const x;  // OK: initialized at declaration
}
```

**See also:** BSC-E0219

---

## Mutable Borrow Specific Errors

---

## BSC-E0224: Expression after &_Mut must be modifiable

**Diagnostic:** `err_mut_expr_unmodifiable`
**Message:** `the expression after '&_Mut' must be modifiable`

**Cause:**
The `&_Mut` operator creates a mutable borrow, which allows writing to the
referenced value. The target expression must therefore be a modifiable lvalue.
Taking a mutable borrow of a `const` variable, a literal, or any other
non-modifiable expression is invalid.

**Example (bad):**

```c
void f(const int x) {
    int *_Borrow mp = &_Mut x;
    // ERROR: the expression after '&_Mut' must be modifiable
}
```

**Fix:**
- Use `&_Const` if you only need to read the value.
- Remove the `const` qualifier if the variable should be mutable.

```c
void f(int x) {
    int *_Borrow mp = &_Mut x;  // OK: x is modifiable
    *mp = 42;
}
```

**See also:** BSC-E0225, BSC-E0227

---

## BSC-E0225: &_Mut for function pointer is not allowed

**Diagnostic:** `err_mut_expr_func`
**Message:** `'&_Mut' for function pointer is not allowed`

**Cause:**
Function pointers refer to code, not data. Taking a mutable borrow of a function
pointer with `&_Mut` is meaningless because you cannot mutate a function's code
through a borrow. BSC prohibits this to prevent confusion and misuse.

**Example (bad):**

```c
void my_func(void) { }

void f(void) {
    void (*fp)(void) = my_func;
    void (**_Borrow mp)(void) = &_Mut fp;
    // ERROR: '&_Mut' for function pointer is not allowed
}
```

**Fix:**
- Use `&_Const` if you need a reference to the function pointer for reading.
- Pass the function pointer by value instead.

```c
void my_func(void) { }

void call_it(void (*fn)(void)) {
    fn();  // OK: passed by value
}

void f(void) {
    call_it(my_func);
}
```

**See also:** BSC-E0222, BSC-E0224

---

## BSC-E0226: Mutable borrow of global/static in safe zone

**Diagnostic:** `err_safe_mut`
**Message:** `global or static variables are not allowed to be mutably borrowed within the safe zone`

**Cause:**
Within a `_Safe` function or `_Safe` block, mutable borrows of global or static
variables are prohibited. Global and static variables can be accessed from multiple
threads or re-entrant calls; allowing mutable borrows in safe code would undermine
the data-race prevention that safe zones provide.

**Example (bad):**

```c
int global_counter = 0;

_Safe void increment(void) {
    int *_Borrow mp = &_Mut global_counter;
    // ERROR: global or static variables are not allowed to be mutably
    //        borrowed within the safe zone
    *mp += 1;
}
```

**Fix:**
- Move the operation outside the safe zone.
- Use atomic operations or synchronization primitives for thread-safe mutation.
- Redesign the code to avoid mutable global state in safe contexts.

```c
void increment(int *_Borrow counter) {
    *counter += 1;  // OK: borrowing a parameter, not a global
}
```

**See also:** BSC-E0204, BSC-E0224

---

## BSC-E0227: Cannot take mutable borrow of string literal

**Diagnostic:** `err_mut_borrow_string_literal`
**Message:** `cannot take mutable borrow of string literal with '&_Mut'; string literals are immutable`

**Cause:**
String literals are stored in read-only memory and are inherently immutable. Taking
a mutable borrow with `&_Mut` on a string literal would imply the ability to
modify the string contents, which is undefined behavior. BSC rejects this at
compile time.

**Example (bad):**

```c
void f(void) {
    char *_Borrow mp = &_Mut "hello";
    // ERROR: cannot take mutable borrow of string literal with '&_Mut';
    //        string literals are immutable
}
```

**Fix:**
- Use `&_Const` for an immutable borrow of the string literal.
- Copy the string into a mutable buffer if modification is needed.

```c
void f(void) {
    const char *_Borrow bp = &_Const "hello";  // OK: immutable borrow

    char buf[] = "hello";
    char *_Borrow mp = &_Mut buf[0];  // OK: mutable borrow of a mutable array
}
```

**See also:** BSC-E0224, BSC-E0228, BSC-E0229

---

## BSC-E0228: Cannot take mutable borrow through string literal indirection

**Diagnostic:** `err_mut_borrow_string_literal_indirect`
**Message:** `cannot take mutable borrow through string literal with '&_Mut *'; string literals are immutable`

**Cause:**
Even when dereferencing a string literal pointer and then taking a mutable borrow
(`&_Mut *`), BSC still detects that the underlying data is a string literal and
rejects the operation. String literals are immutable regardless of how they are
accessed.

**Example (bad):**

```c
void f(void) {
    const char *s = "hello";
    char *_Borrow mp = &_Mut *s;
    // ERROR: cannot take mutable borrow through string literal with '&_Mut *';
    //        string literals are immutable
}
```

**Fix:**
- Use `&_Const` for an immutable borrow.
- Copy the string into a mutable buffer first.

```c
void f(void) {
    char buf[] = "hello";
    char *_Borrow mp = &_Mut buf[0];  // OK: mutable borrow of a mutable copy
}
```

**See also:** BSC-E0227, BSC-E0229

---

## BSC-E0229: Cannot pass string literal to mutable borrow parameter

**Diagnostic:** `err_pass_string_literal_to_mut_borrow`
**Message:** `cannot pass string literal to parameter of type %0; string literals are immutable`

**Cause:**
A function parameter expects a mutable `_Borrow` pointer, but you passed a string
literal. Since string literals are immutable, they cannot satisfy a mutable borrow
requirement. BSC catches this at the call site to prevent the function from
attempting to modify read-only memory.

**Example (bad):**

```c
void modify(char *_Borrow mp) {
    *mp = 'H';
}

void f(void) {
    modify("hello");
    // ERROR: cannot pass string literal to parameter of type 'char *_Borrow';
    //        string literals are immutable
}
```

**Fix:**
- Copy the string literal into a mutable buffer and pass that instead.
- Change the function signature to accept `const char *_Borrow` if it does not need mutation.

```c
void modify(char *_Borrow mp) {
    *mp = 'H';
}

void f(void) {
    char buf[] = "hello";
    modify(&_Mut buf[0]);  // OK: mutable buffer
}
```

**See also:** BSC-E0227, BSC-E0228

---

## Quick Reference Table

| Code | Diagnostic | Flag | Summary |
|------|-----------|------|---------|
| BSC-E0201 | `err_borrow_assign_when_borrowed` | `-Wassign-borrowed` | Assign while borrowed |
| BSC-E0202 | `err_borrow_move_when_borrowed` | `-Wmove-borrowed` | Move while borrowed |
| BSC-E0203 | `err_borrow_use_when_mut_borrowed` | `-Wuse-mutably-borrowed` | Use while mutably borrowed |
| BSC-E0204 | `err_borrow_mut_borrow_more_than_once` | `-Wrepeated-borrow` | Multiple mutable borrows |
| BSC-E0205 | `err_borrow_immut_borrow_when_mut_borrowed` | `-Wrepeated-borrow` | Immutable + mutable borrow |
| BSC-E0206 | `err_borrow_mut_borrow_when_immut_borrowed` | `-Wrepeated-borrow` | Mutable + immutable borrow |
| BSC-E0207 | `err_borrow_return_local_borrow` | `-Wreturn-local-borrow` | Return reference to local |
| BSC-E0208 | `err_borrow_not_live_long` | `-Wshort-life-borrow` | Value does not live long enough |
| BSC-E0209 | `err_borrow_live_longer_than_target_var` | (legacy) | Borrow outlives target |
| BSC-E0210 | `err_at_most_one_mut_borrow` | (legacy) | Duplicate mutable borrow |
| BSC-E0211 | `err_return_value_borrow_local` | (legacy) | Return borrow of local |
| BSC-E0212 | `err_modify_after_be_borrow` | (legacy) | Modify while borrowed |
| BSC-E0213 | `err_read_after_be_mut_borrow` | (legacy) | Read while mutably borrowed |
| BSC-E0214 | `err_use_expired_borrow_var` | (legacy) | Use expired borrow |
| BSC-E0215 | `err_borrow_on_borrow` | | Conflicting qualifier on _Borrow |
| BSC-E0216 | `err_move_borrow` | | Move a _Borrow type |
| BSC-E0217 | `err_borrow_qualcheck_incompatible` | | Incompatible borrow cast |
| BSC-E0218 | `err_borrow_qualcheck_compare` | | Incompatible borrow compare |
| BSC-E0219 | `err_typecheck_invalid_borrow_not_pointer` | | _Borrow on non-pointer |
| BSC-E0220 | `err_typecheck_borrow_func` | | Return _Borrow without _Borrow param |
| BSC-E0221 | `err_typecheck_borrow_subscript` | | Subscript of _Borrow pointer |
| BSC-E0222 | `err_funcPtr_incompatible` | | _Borrow function pointer cast |
| BSC-E0223 | `err_borrow_not_init` | | Uninitialized _Borrow variable |
| BSC-E0224 | `err_mut_expr_unmodifiable` | | &_Mut on non-modifiable |
| BSC-E0225 | `err_mut_expr_func` | | &_Mut on function pointer |
| BSC-E0226 | `err_safe_mut` | | Mutable borrow in safe zone |
| BSC-E0227 | `err_mut_borrow_string_literal` | | &_Mut on string literal |
| BSC-E0228 | `err_mut_borrow_string_literal_indirect` | | &_Mut * on string literal |
| BSC-E0229 | `err_pass_string_literal_to_mut_borrow` | | String literal to mut param |
