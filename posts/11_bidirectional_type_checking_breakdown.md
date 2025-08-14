-- title: Learning bidirectional type checking
-- publication_date: 2025-08-13
-- summary:

> Note: I promised myself that I would write an article once I understood how
bidirectional type checking works. [The paper](https://arxiv.org/abs/1306.6032)
opens with a claim that the algorithm is extraordinarily simple, which immediately
hit the ego because I had no idea what I was reading. I just couldn't wrap my head
around what any of the typing rules and typing judgments meant. I powered through
it and eventually understood it. So here I am, 3 months later, writing this article
as promised.

This article is intended for people interested in building their own programming
language with little programming language theory and type theory background who
are struggling with papers telling you their algorithm is extraordinarily simple
and then giving you this:

![image](/images/11_01.png)

After fighting with [Complete and Easy Bidirectional Typechecking for
Higher-Rank Polymorphism](https://arxiv.org/abs/1306.6032) for a while, I
think I agree that it is actually simple, especially compared with
algorithms that require constraint solving and unification. It is simple, but
definitely not easy. We have some work ahead of us.

> Note: I do think you'll eventually need to learn proper programming language
> theory and type theory to complete your language, but you can definitely
> build a proof of concept without deep background in those subjects.

### Type checking

Type checking is the process that verifies if an expression is well typed. Type
checking might also produce annotations that you can carry forwards for later compiler passes.

Expressions are usually obtained from parsing, which is the process that converts
text, the source code, into a data structure that is better suited for inspection
and manipulation. The data structure is usually a tree, where each node represents
an expression and its children represent its subexpressions.

For the rest of this article, we'll talk about a made up programming language
with primitives (integers, bools, strings, etc.) and functions.
At the end of this article we'll look at array literals and sum types.

### The `synthesize` function

There are two distinct functions at the core of the bidirectional type checking algorithm
that call each other, recursively, in order to resolve the type of an expression.
Those functions are `synthesize`, which infers the type of an expression, and
`check`, which checks if the expression has the expected type. For learning
purposes, it is sufficient to think of their signatures as:

```haskell
synthesize :: Expression -> Type
check :: Expression -> Type -> Bool
```

At this moment, we have no expressions nor types to work with, so let's
draw a starting line.

```haskell
data Expression
  = LiteralInt Int
  | LiteralString String

data Type
  = TInt
  | TString
```

The implementation of the `synthesize` function is pretty straight forward for
this set of expressions and types.

```haskell
synthesize :: Expression -> Type
synthesize expression =
  case expression of
    LiteralInt _ -> TInt
    LiteralString _ -> TString
```

In fact, the `synthesize` implementation is the same for all literal primitive
types. If we added support for booleans, dates and datetimes, they would
be just as simple.

The typing rule for literals is described as follows:

![](/images/11_02.png)

"1I=>" is the name of the typing rule. "1" means unit, "I" means introduction,
and "=>" means synthesis. You can read the name as "the typing rule for synthesizing unit",
or "the typing rule for synthesizing literals".

Notice there is a line with nothing above it. The fact that there is nothing above
the line means that the typing rule has no premises, that is, it is always true
in all contexts. For example, the literal 2 always synthesizes the type `Int`
no matter which program you are type checking. Contrast this to synthesizing,
let's say, a variable named `email`. Which type should it synthesize? Depends,
right? Depends on the program you are type checking. The fact that it depends on
a context means that the typing rule will have a premise, that is, a typing
judgment above the line.

You can read the conclusion, what is underneath the line, as "under context gamma,
the unit literal synthesizes the type `Unit`, and produces the same context gamma".

### Contexts

For the unit/literal typing rule, the context does not matter. Whatever we receive
as input we return the same value as output. But this will not be the case for
all typing rules. In fact, the context does not matter only for the unit/literal
typing rule.

The context is a container that holds symbols and their types currently in scope
(and some other stuff we'll talk about later). The paper calls it an algorithmic
context. The data structure behind it is a list, where the order of the elements
in the list is the order they appeared in the code. For example if we have
the code

```
let id = 10
let email = "person@example.org"
```

We would push `id` and `email`, in that order, into the context.
