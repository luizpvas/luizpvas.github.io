-- title: Bidirectional type checking
-- publication_date: 2025-08-13
-- summary:

This article is intended for people struggling with papers telling you their
algorithm is extraordinarily simple and then giving you this:

![image](/images/11_01.png)

After fighting with [Complete and Easy Bidirectional Typechecking for
Higher-Rank Polymorphism](https://arxiv.org/abs/1306.6032) for a while, I
think I agree that it is actually simple, especially compared to
algorithms that require constraint solving and unification. It is simple, but
definitely not easy. We have some work ahead of us.

### Type checking

Type checking is a process that validates expressions against type rules.

Expressions are usually obtained from parsing, which is the process that converts
text, the source code, into a data structure that is better suited for inspection
and manipulation. The data structure is usually a tree, commonly referred to as
AST, where each node represents an expression pointing to its subexpressions.

For the rest of this article, we'll talk about a made up programming language
with literals for integers and strings, variables and functions.
We'll also look at array literals and sum types at the end.

### The `synthesize` function

There are two distinct functions at the core of bidirectional type checking
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

The implementation for `synthesize` is the following for this set of expressions
and types:

```haskell
synthesize :: Expression -> Type
synthesize expression =
  case expression of
    LiteralInt _ -> TInt
    LiteralString _ -> TString
```

All literal primitives follow this pattern. If we added
support for dates, datetimes, regexs, etc., they would all be new entries
to this pattern match.

The typing rule for unit (and literals) is described as follows:

![Typing rule for unit](/images/11_02.png)

The "1I=>" on the right hand side is the name of the typing rule. "1" means unit, "I" means introduction,
and "=>" means synthesis. You can read the name as "the typing rule for synthesizing unit",
or "the typing rule for synthesizing literals".

Notice there is a line in the middle with nothing above it. This means that the typing rule has
no premises, so it is always true in all contexts. The literal
`2` always synthesizes the type `Int` in all contexts.
Contrast this to synthesizing, let's say, a variable named `email`. Which type
should it synthesize? Probably `String`, but depends, right?
The fact that it depends means that the typing rule for variables
must have a premise.

You can read the conclusion, what is below the line, as "under context gamma,
the unit value synthesizes the type `Unit`, and produces the same context gamma".

### Contexts

For the unit type rule, the context does not matter. Whatever we receive
as input we return the same value as output. But this is not the case for
other typing rules.

The context is a container that holds symbols, like variable names, function names, module names, etc.,
and their types (and some other stuff we'll talk about later).
The data structure for context is a list, where the order of the elements
in the list is the order they appear in the code. For example, the
following pseudo-js-code

```js
let id = 10;
let email = "person@example.org";
```

would push `id :: Int` and `email :: String`, in that order, into the context.

### Variables

Before we can synthesize the type of a variable we need to add a new constructor
to our expression type.

```haskell
data Expression
  = LiteralInt Int
  | LiteralString String
  | Variable String
```

Then, let's update our `synthesize` function.

```haskell
synthesize :: Expression -> Type
synthesize expression =
  case expression of
    LiteralInt _ -> TInt
    LiteralString _ -> TString
    Variable varname -> undefined -- what do we do here?
```

To implement the variable case we need to lookup the name in a context. So let's
tweak our typing functions to take a context as an argument. The signature I
showed earlier was a simplified version, the real signatures of `synthesize` and
`check` are:

```haskell
synthesize :: Expression -> Context -> (Type, Context)
check :: Expression -> Type -> Context -> (Bool, Context)
```

The implementation of synthesize, considering the new variable case, is the
following:

```haskell
synthesize :: Expression -> Context -> (Type, Context)
synthesize expression context =
  case expression of
    LiteralInt _ ->
      (TInt, context)

    LiteralString _ ->
      (TString, context)

    Variable varname ->
      case Context.lookup varname context of
        Just vartype -> (vartype, context)
        Nothing -> error "unknown variable"
```

The literal cases now return the given context as-is. The
variable case defers to `Context.lookup` to retrieve the type of the variable
from the context. It then returns the same context without modifications because
synthesizing variables only needs to read the context.

We still haven't seen what `Context` is, and the implementation of `Context.lookup`, but
before we get there, let's learn the synthesize variable typing rule.

![Typing rule for variables](/images/11_03.png)

Here's how to read it: "The typing rule for synthesizing variables
states that, under context gamma, `x` synthesizes type `A` and produces
the same context gamma if, and only if, gamma contains the annotation `x : A`".

### Back to contexts

The typing context contains declarations of universal type variables, term
variable typings and existential type variables, both solved and unsolved.

```haskell
data Element
  = TypedVariable Name Type

type Context = [Element]

lookup :: Name -> Context -> Maybe Type
lookup name context =
  case context of
    [] -> Nothing
    (TypedVariable name' vartype : rest)
      | name == name' -> Just vartype
      | otherwise -> lookup name rest
    _ : rest -> lookup name rest
```
