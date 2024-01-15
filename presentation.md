---
title: The secrets of the 🦀
subtitle: A tour of free rust optimizations
author: Pedro Mendes
---

# Who am I?

<ul>
<li class="fragment">Ex estudante da Eng. Informática</li>
<li class="fragment">Escrevo rust nos meus tempos livres</li>
<li class="fragment">Pagam me para escrever Rust nos meus tempos não livres</li>
</ul>

## __Disclaimers__

- Vai haver um bocadinho de assembly nesta talk 👀. Espero que tenham prestado
atenção ao Proença.

- Esta talk também assume algum conhecimento de rust, se não sabem **perguntem**.

# Enums and their niches

## Enums são "sum types"

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

<div class="r-stack">
<div class="fragment">
Na verdade não precisamos de uma tag porque há estados inválidos para um `Vec`!

<div class="fragment">
**O pointer interior nunca pode ser null!**
</div>

<div class="fragment">
```
+-----------------------+
| Nothing:              |  Para Nothing basta inicilizar os
|   0   |   x   |   x   |  primeiros 8 bytes a 0.
|                       |
| Just:                 |  Para Just basta o `ptr` não ser 0
|   ptr |  len  |  cap  |  e já se sabe que não é Nothing.
+-----------------------+

< ----- 24 bytes ------ >
```

<p class="fragment">Mas será que `Vec` é especial?</p>
</div>
</div>
<img class="fragment" src="./assets/bye-alice-rabbit-hole.gif" style="min-height:30vh"/>
</div>

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

## And it recurses!

<div class="fragment">
```rust
enum Option<T> {
    Some(T)
    None
}
```
</div>
<div class="fragment">
```rust
struct Foo { i: i32, bar: Bar }
struct Bar { f: f32, baz: Baz }
struct Baz { s: String }

size_of::<Foo>() == size_of::<Option<Foo>>()
```
</div>

## It's zero cost abstraction ™️

<div class="fragment">
```rust
/**
  Opens a file.
  Upon  successful  completion return a FILE pointer.
  Otherwise, NULL is returned.
*/
FILE* fopen(char const* path, char const* mode);
```
</div>
<div class="fragment">
```rust
/// Opens a file.
/// Upon  successful  completion return a boxed File.
/// Otherwise, None is returned.
fn fopen(path: &str, mode: &str) -> Option<Box<File>>;
```
</div>
<div class="fragment">
Ambos os valores de retorno tem o mesmo tamanho, um pointer. E um NULL check em
C vai gerar assembly praticamente igual ao None check em rust.
</div>


# Zero Sized Types

## O tamanho de uma struct

```rust
struct Foo { a: i32, b: i32 }

size_of::<i32>() == 4;
size_of::<Foo>() == 8;
```

## E o tamanho de uma struct com zero membros?

```rust
struct Zero;

size_of::<Zero>() == 0;
```

## Some assembly

<p class="fragment">ASM necessário para instanciar um tipo destes:</p>
<div class="fragment">
```asm
 
```
</div>
<p class="fragment">ASM necessário para o passar a uma função:</p>
<div class="fragment">
```asm
 
```
</div>
<p class="fragment">ASM necessário para fazer uma copia:</p>
<div class="fragment">
```asm
 
```
</div>


## Muito lindo, mas para que serve?

<div class="fragment">
```rust
pub trait Logger {
    fn log(&self, s: &str);
}

fn handle_request<L: Logger>(logger: L, req: Request) { ... }
```
</div>
<div class="r-stack">
<div class="fragment fade-in-then-out">
```rust
struct FileLogger(File);
impl Logger for StdoutLogger {
    fn log(&self, s: &str) { self.0.write(s) }
}

// compiler generates
fn handle_request_FileLogger(logger: FileLogger, req: Request) { ... }          
```
</div>
<div class="fragment">
```rust
struct StdoutLogger;
impl Logger for StdoutLogger {
    fn log(&self, s: &str) { println!("{s}") }
}

// compiler generates
fn handle_request_StdoutLogger(req: Request) { ... }                            
```
</div>
</div>

## Alocações dinâmicas de ZST's

<table>
<tr>
<td>
```rust
Box::new(Zero)
```
</td>
<td>
```asm
mov  eax, 1
ret
```
</td>
</tr>
<tr>
<td>
```rust
vec![Zero; u32::MAX as _]   
```
</td>
<td>
```asm
mov  rax, rdi
mov  qword ptr [rdi], 1
mov  qword ptr [rdi + 8], 0
mov  rcx, 4294967295
mov  qword ptr [rdi + 16], rcx    
```
</td>
</tr>
</table>

[godbolt](https://godbolt.org/z/z9Gr5GWhs)


# Free Simd

![](./assets/free-real-estate.gif)

