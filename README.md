## Universal Constructions for D

This module defines universal products (Tuple) and coproducts (Union), with related utility functions and data structures.

Tuples are straight from Phobos, but std.functional.adjoin is reimplemented to support named fields.

Union is a custom implementation, and radically different from Phobos' Algebraic. It is equally simple to use and has greater expressive power than Algebraic (which I attempt to justify in the comments of the same module).

Some extras are built on top of them, like error handling contexts, enum switches, and nullable types.

Use examples are included as documented unittests in almost all modules.

core.coproduct and core.apply are probably the best places to start. Everything else is fairly straightforward, except for core.match, which performs type-level pattern matching in a variety of ways.
