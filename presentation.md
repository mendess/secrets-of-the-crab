---
title: The secrets of the 🦀
subtitle: A tour of free rustc optimizations
author: Pedro Mendes
---

# Who am I?

<ul>
<li class="fragment">Ex estudante da Eng. Informática</li>
<li class="fragment">Ávido programador de rust</li>
<li class="fragment">Brinco com nuvens na cloudflare</li>
</ul>

# Enums and their niches

## Enums são `sum types`

```rs
enum MaybeNumbers {
    Just(Vec<i32>),
    Nothing,
}

fn main() {
    let has_numbers = MaybeNumbers::Just(vec![1, 2, 3]);
    let no_numbers = MaybeNumbers::Nothing;
}
```
