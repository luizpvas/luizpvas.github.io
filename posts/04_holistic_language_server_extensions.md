-- title: Holistic Language Server - Extensions
-- publication_date: 2023-08-03
-- summary: The code needs lots of conditionals spread across parsing and type solving to deal with every quirk of the Ruby language and libraries I wish to support.

### What problem am I trying to solve?

The code needs lots of conditionals spread across parsing and type solving to deal with every quirk of the Ruby language and libraries
I wish to support.

The parser should not know about RSpec-specific DSL. The parser should not know about Rails-specific DSL.

### What can I do about it?

#### 1. Nothing

Fine for a while, bad after that while.

#### 2. Move conditionals to a module with a descriptive name (increase greppability)

Worse than doing nothing. It still has the same problems but more with indirection.

#### 3. Decouple core from lib specific behaviour

Move all lib specific code closed together. Core broadcasts events (`reference_added`, `scope_defined`, `type_solved`, etc.) that each extension can listen and do something about. The dependency happens in one direction: extensions knows about core, core does not know about extensions.

A consequence of this design is exposing core's types (`Reference::Record`, `Scope::Record`, `TypeInference::Clue::*`, `TypeInference::Conclusion`, etc.). All of those things that were private before becomes then a public contract. I'm OK with that.

By the way, this approach is known as microkernel architecture or plugin architecture. There are lots of good stuff about it on Google.

### How can I know I've chosen the best solution?

* If I need to change the support for a library because their API changed, the changes are closed together.
* If I need to add support for a new library, code gets added, no changed.
* There should be no regression in existing libraries when adding a new one.
