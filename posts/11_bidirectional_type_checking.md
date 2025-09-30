-- title: Bidirectional type checking
-- publication_date: 2025-08-13
-- summary:

This article is intended for people struggling with papers telling you their
algorithm is extraordinarily simple and then giving you this:

![image](/images/11_01.png)

After fighting with [Complete and Easy Bidirectional Typechecking for
Higher-Rank Polymorphism](https://arxiv.org/abs/1306.6032) for a while, I
I agree that it is actually simple, especially compared to
algorithms that require constraint solving and unification. It is simple, but
definitely not easy. We have some work ahead of us.

### Type checking

Type checking is the process that validates expressions against type rules.

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
synthesize expr =
  case expr of
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
no premises, so it is always true in all contexts. For example, the literal
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
and their types (and some other stuff we're about to see).
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
showed earlier was a simplified version. The real signatures of `synthesize` and
`check` are:

```haskell
synthesize :: Expression -> Context -> (Type, Context)
check :: Expression -> Type -> Context -> Context
```

The implementation of synthesize, considering the new variable case, is the
following:

```haskell
synthesize :: Expression -> Context -> (Type, Context)
synthesize expr context =
  case expr of
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
from the context. It then returns the same context without modifications.

We still haven't seen what `Context` is, and the implementation of `Context.lookup`, but
before we get there, the typing rule for synthesizing variables is the following:

![Typing rule for variables](/images/11_03.png)

Here's how to read it: "The typing rule for synthesizing variables
states that, under context gamma, `x` synthesizes type `A` and produces
the same context gamma if gamma contains the annotation `x : A`".

### Back to contexts

Contexts contain declarations of quantifications (forall), term
variable typings and existentials, both solved and unsolved. The underlying
data structure is a list, where the order of the elements represent the order
of the facts we have gathered from the program we are type checking.

Let's define the `Context` type as a list of `Element` and implement the
`lookup` function we need.

```haskell
data Element
  = TypedVariable Name Type

type Context = [Element]

lookup :: String -> Context -> Maybe Type
lookup varname context =
  case context of
    [] ->
      Nothing

    (TypedVariable name vartype : rest) ->
      if varname == name
      then Just vartype
      else lookup varname rest

    (_ : rest) ->
      lookup name rest
```

Apart from the fact we cannot yet add definitions to the context, with the code
above we can successfully synthesize variables.

### Annotations

The next typing rule we're going to support is type annotations. It does not
matter if the language defines annotation as a separate construct (like Haskell)
from functions and values or if annotations are written next to the expressions
(like Typescript).

The rule synthesizing annotations is as follows:

![annotation_type_rule](/images/11_04.png)

This is a bit more complicated than we have seen so far, but we're not afraid.
The conclusion of this typing rule states that "under context gamma, `e has type A`
synthesizes type `A` and produces context delta".

Synthesizing type `A` for the annotation `e : A` seems kinda redundant,
but the premise of the rule provides interesting guarantees. First, `A` must
be well formed. This is denoted by the expression `Γ ⊢ A`. This ensures that
the annotation references a valid type in the program.

The second part of the premise, `Γ ⊢ e <= A ⊣ Δ`, adds an extra correctness
guarantee to the process. The compiler cannot simply trust the annotation
and assume `e` actually have type `A`. Doing so would make the type
system unsound. So instead of trusting, we need to check.

> Just to be clear we're on the same page about the notation, `e => A` is read
> as "e synthesizes type A" and `e <= A` is read as "e checks against type A".

This rule is our first encounter with the recursion between synthesizing
and checking. In order to synthesizse annotation expression we need to
check it, and during checking we might need to synthesize.

### Is the type well formed?

The first premise of synthesizing the annotation `e : A` ensures that the
type `A` is well formed. The following set of rules describe the well-formedness
of types:

![annotation_type_rule](/images/11_05.png)

Here's an explanation of the rules:

- **UvarWF**: A type variable is well formed if it exists in the context. Do not
  confuse type variables with expression variable.
- **UnitWF**: The unit type is always well formed. The same is true for all literal types.
- **ArrowWF**: The function type `A -> B` is well formed if `A` and `B` are well formed.
- **ForallWF**: The quantification `forall x.A` is well formed if `A` is well formed under
  context gamma with `x` added to gamma.
- **EvarWF**: The existential type `â` is well formed if it exists in the context.
- **SolvedEvarWF**: The solved existential type `â` is well formed if it exists in the context.

We haven't talked about type variables, quantification and existentials, but I
thought it was useful to provide the whole definition. The implementation of this
function would look the following for the types we already have:

```haskell
isTypeWellFormed :: Type -> Context -> Bool
isTypeWellFormed ty context =
  case ty of
    TInt    -> True -- UnitWF
    TString -> True -- UnitWF
```

### Checking

The second premise of synthesizing the annotation `e has type A` ensures that
the program is not lying to the compiler. It checks that the expression `e`
type checks against `A`.

In order to implement `check` we need at least one typing rule, so let's stash
the annotation synthesize rule and look at the simplest rule for checking
literals:

![type_rule_check_literal](/images/11_06.png)

This is very, very similar to the rule for synthesizing literals. The only
difference is that arrows are flipped. The implementation of check is as follows:

```haskell
check :: Expression -> Type -> Context -> Context
check expr ty context =
  case (expr, ty) of
   (LiteralInt _, TInt) ->
     context

    (LiteralString _, TString) ->
      context

    (_, _) ->
      error "Type mismatch"
```

### Back to synthesizing annotations

We now have enough structure in place to synthesize annotations.

```diff
data Expression
  = LiteralInt Int
  | LiteralString String
  | Variable String
+ | Annotation Expression Type


synthesize :: Expression -> Context -> (Type, Context)
synthesize expr context =
  case expr of
    LiteralInt _ ->
      (TInt, context)

    LiteralString _ ->
      (TString, context)

    Variable varname ->
      case Context.lookup varname context of
        Just vartype -> (vartype, context)
        Nothing -> error "unknown variable"

+   Annotation e ty ->
+     if isTypeWellFormed ty context then
+       let delta = check e ty context
+        in (ty, delta)
+     else
+       error "Invalid type"
```
