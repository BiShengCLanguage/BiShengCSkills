---
name: bsc-ownership
description: "BiSheng C ownership system. When you need to understand _Owned pointers, move semantics, _Owned structs, destructors, RAII, _Public access, _Nullable, or ownership transfer rules, use this Skill."
---

# BiSheng C Ownership Skill

## 1. Overview

Move semantics for compile-time memory safety. Prevents use-after-free and double-free at compile time. Once ownership transfers, the original variable is dead.

## 2. Owned Pointers

```c
#include <stdlib.h>

int *_Owned create(int val) {
    int *_Owned p = (int *_Owned)malloc(sizeof(int));  // raw→owned requires cast
    *p = val;
    return p;  // ownership transfers to caller
}

int readAndFree(int *_Owned p) {
    int val = *p;
    free((void *_Owned)p);  // owned→raw cast to free
    return val;
}

int *_Owned transform(int *_Owned input) {
    int val = *input;
    free((void *_Owned)input);  // free old
    int *_Owned result = (int *_Owned)malloc(sizeof(int));
    *result = val * 2;
    return result;  // return new owned pointer
}

int main() {
    int *_Owned p = create(21);
    int *_Owned p2 = transform(p);
    // p is now dead — cannot use it
    int result = readAndFree(p2);
    // p2 is now dead

    // Nullable owned pointer
    int *_Owned _Nullable maybe = nullptr;
    return 0;
}
```

## 3. Rules

- **`_Owned` goes after the `*`**: write `int *_Owned`, NOT `_Owned int*`. It is a pointer qualifier (like `const`), not a type prefix
- `_Owned` types have **move semantics**: assignment, passing, returning **transfers** ownership
- After transfer, the original variable is **dead** — any use is a compile error
- Before scope ends, `_Owned` variables **must** have ownership released
- Release by: (a) passing to function taking `_Owned`, (b) casting to `void *_Owned` and freeing, (c) returning
- No pointer arithmetic on `_Owned` pointers (no `+`, `-`, `[]`, `++`, `--`)
- `_Owned` cannot be: global variables, union members
- Can be array elements, but cannot transfer individual elements
- Type matching is strict: `int *_Owned` != `int *`
- Converting between `_Owned` and raw requires explicit cast in `_Unsafe` context
- Exception: `T *_Owned` → `void *_Owned` is allowed in safe context
- `_Nullable`: `int *_Owned _Nullable p = nullptr;` allows null owned pointers

## 4. Owned Structs (RAII)

```c
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

_Owned struct Buffer {
_Public:
    char *ptr;
    int len;
    int cap;

    ~Buffer(Buffer this) {
        if (this.ptr) {
            printf("~Buffer: freeing %d bytes\n", this.cap);
            free(this.ptr);
        }
    }
};

Buffer Buffer::new(int capacity) {
    char *p = (char*)malloc(capacity);
    Buffer b = { .ptr = p, .len = 0, .cap = capacity };
    return b;
}

void Buffer::append(Buffer* this, const char* data, int datalen) {
    if (this->len + datalen <= this->cap) {
        memcpy(this->ptr + this->len, data, datalen);
        this->len += datalen;
    }
}

int main() {
    {
        Buffer buf = Buffer::new(256);
        buf.append("hello", 5);
        // ~Buffer automatically called here when buf goes out of scope
    }
    {
        Buffer buf1 = Buffer::new(128);
        Buffer buf2 = buf1;  // ownership MOVES from buf1 to buf2
        // buf1 is now dead — only ~Buffer(buf2) is called
    }
    return 0;
}
```

### 4.1 Owned Struct Rules

- `_Owned struct` has move semantics as a whole
- Destructor syntax: `~TypeName(TypeName this) { ... }` inside the struct body
- Destructor is called automatically when the variable goes out of scope (if not moved)
- `_Public:` makes fields accessible outside the struct
- Each `_Owned` field in a struct is tracked independently

> For borrowing (non-owning references), see `bsc-borrowing` Skill
> For safe zones with owned types, see `bsc-safe-zone` Skill
> For ownership errors (BSC-E01xx), see `bsc-errors` Skill
> For owned struct errors (BSC-E06xx), see `bsc-errors` Skill
