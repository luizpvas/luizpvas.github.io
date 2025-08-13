-- title: Bidirectional type checking breakdown
-- publication_date: 2025-08-13
-- summary:

Context: I promised myself that I would write an article once I understood how
bidirectional type checking works. The paper opens with a claim that the
algorithm is extraordinarily simple, which immediately hit the ego. I had no
idea what anything meant because I just couldn't read the notation used in
typing rules and typing judgments. I powered through it and learned a lot.
It has been three months since.

This article is intended for people interested in building their own programming
language with little math and type theory background who are struggling with
papers telling you their algorithm is extraordinarily simple and then giving you
this:

![image](/images/11_01.png)

After fighting with [Complete and Easy Bidirectional Typechecking for
Higher-Rank Polymorphism](https://arxiv.org/abs/1306.6032) for a while, I
think I agree that it is actually simple, especially compared with
algorithms that require constraint solving and unification. It is simple, but
definitely not easy. We have some work ahead of us.

### Type checking

Type checking is the process that verifies if an expression is well typed. It
also produces annotations in the process that you may be interested in carrying
forwards for later compiler passes.

Expressions are usually obtained from parsing, which is the process of converting
text, the source code, into a data structure that is better suited for inspection
and manipulation. The data structure is usually a tree, where each node represents
an expression and its children represent its subexpressions.

### The `type_check` function

Just so we have a clear target, we're interested in implementing a function that
receives an expression and a type, and returns true if the expression matches
the type (it type checks) or false (it doesn't type check).

For example, in pseudo-ruby code:

```
type_check("1", :int) # => true
type_check("String.reverse", :string -> :string) # => true
type_check("1 + 'foo'", :int) # => false
```

In a real programming language

### Synthesizing unit

* Described at Figure 11. 1I=>
* For clarity, I'll use `:unit_value` and `:unit_type` instead of the Haskell
  syntax `()` for both value and type.
* Our goal is to implement a `synthesize` function such that
  `synthesize(:unit_value, Context.empty())` returns `:unit_type`.


### Synthesizing abstractions

* Described at Figure 11. ->I=>
*
