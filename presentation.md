---
title: The secrets of the 🦀
subtitle: A tour of free rustc optimizations
author: Pedro Mendes
---

# Who am I?

<ul>
<li class="fragment">Ex estudante da Eng. Informática</li>
<li class="fragment">Escrevo rust nos meus tempos livres</li>
<li class="fragment">Pagam me para escrever Rust nos meus tempos não livres</li>
</ul>

## __Disclaimer__

Vai haver um bocadinho de assembly nesta talk 👀. Espero que tenham prestado
atenção ao Proença.

# Enums and their niches

## Enums são `sum types`

```rust
enum MaybeNumbers {
    Just(Vec<i32>),
    Nothing,
}

fn main() {
    let has_numbers = MaybeNumbers::Just(vec![1, 2, 3]);
    let no_numbers = MaybeNumbers::Nothing;
}
```

## Memory layout

```
size_of::<Vec<i32>>() == 24;
```
```
+--------+------------------------+
|  tag   | Just / Nothing         |
|        |                        |
|8 bytes | 24 bytes               |
+--------+------------------------+
  ^         ^
   \         \ Espaço suficiente para a
    \          maior variante do enum
     \
      Tag que pode ser 0 para Just ou 1 para Nothing
```

Total: 32 bytes

<div class="fragment">
```rust
size_of::<MaybeNumbers>() == 24;
```
</div>
<div class="fragment">
???
</div>

## Niche optimization.

Na verdade não precisamos de uma tag porque há estados inválidos para um `Vec`!

<div class="fragment">
**O pointer interior nunca pode ser null!**
</div>

<div class="fragment">
```
+------------------------+
| METER AQUI UM NULL     |
|                        |
| METER AQUI UM VEC      |
+------------------------+
  ^         ^
   \         \ Espaço suficiente para a
    \          maior variante do enum
     \
      Tag que pode ser 0 para Just ou 1 para Nothing
```

Mas será que `Vec` é especial?
</div>
<img class="fragment" src="./assets/bye-alice-rabbit-hole.gif"/>

## Vec

```rust
// https://doc.rust-lang.org/src/alloc/vec/mod.rs.html#396
pub struct Vec<T, A: Allocator = Global> {
    buf: RawVec<T, A>,
    len: usize,
}
```

## RawVec

```rust
// https://doc.rust-lang.org/src/alloc/raw_vec.rs.html#51
pub(crate) struct RawVec<T, A: Allocator = Global> {
    ptr: Unique<T>,
    cap: usize,
    alloc: A,
}
```

## Unique

```rust
// https://doc.rust-lang.org/src/core/ptr/unique.rs.html#37
pub struct Unique<T: ?Sized> {
    pointer: NonNull<T>,
    // NOTE: this marker is necessary for dropck to
    // understand that we logically own a `T`.
    _marker: PhantomData<T>,
}
```

## NonNull

Behold! The magic sauce!

<div class="fragment">
```rust
// https://doc.rust-lang.org/src/core/ptr/non_null.rs.html#67
#[repr(transparent)]
#[rustc_layout_scalar_valid_range_start(1)]
#[rustc_nonnull_optimization_guaranteed]
pub struct NonNull<T: ?Sized> {
    pointer: *const T,
}
```
</div>

# Zero Sized Types

## Types have size

```rust
use std::mem::size_of;

size_of::<bool>() == 1;
size_of::<i32>() == 4;
```

## O tamanho de uma struct é a soma dos membros

```rust
struct Foo { a: i32, b: i32 }

size_of::<Foo>() == 8;
```

## E o tamanho de uma struct com 0 membros?

```rust
struct Zero;

size_of::<Zero>() == 0;
```



https://godbolt.org/z/GnTY9WEo9
