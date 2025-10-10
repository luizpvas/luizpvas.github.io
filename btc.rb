module Expression
  LiteralInt = Data.define(:value)
  LiteralString = Data.define(:value)
  Variable = Data.define(:name)
  Annotation = Data.define(:expression, :type)
  Lambda = Data.define(:arg_name, :body_expr)
  Application = Data.define(:lambda, :arg)
end

module Type
  Int = Data.define
  String = Data.define
  Variable = Data.define(:name)
  Existential = Data.define(:name)
  Lambda = Data.define(:arg_type, :body_type)
  Quantification = Data.define(:name, :subtype)
end

class Context
  module Element
    Variable = Data.define(:name)
    TypedVariable = Data.define(:name, :type)
    UnsolvedExistential = Data.define(:name)
    SolvedExistential = Data.define(:name, :type)
    Marker = Data.define(:name)
  end

  def self.empty = new([])

  def initialize(elements = [])
    @elements = elements
  end

  def lookup(name)
    typed_var =
      @elements.find do |element|
        case element
        in Element::TypedVariable(varname, _) then varname == name
        else false
        end
      end

    typed_var&.then { it.type }
  end

  def replace(element_old, element_new)
    elements = @elements.flat_map { |element| element == element_old ? Array(element_new) : element }

    Context.new(elements)
  end

  # Figure 8.
  def apply(type)
    case type
    # [Γ]1 = 1
    in Type::Int
      type

    # [Γ]1 = 1
    in Type::String
      type

    # [Γ]a = a
    in Type::Variable
      type

    # [Γ[â]]â = â
    # [Γ[â = t]]â = [Γ[â = t]]t
    in Type::Existential(name)
      solved_type = find_solved_existential(name)
      solved_type ? apply(solved_type) : type

    # [Γ](A -> B) = ([Γ]A) -> ([Γ]B)
    in Type::Lambda(arg_type, body_type)
      type.with(arg_type: apply(arg_type), body_type: apply(body_type))

    # [Γ](∀a.A) = ∀a.[Γ]A
    in Type::Quantification(name, subtype)
      type.with(subtype: apply(subtype))

    else
      raise "unknown type: #{type}"
    end
  end

  def find_solved_existential(name)
    solved_existential =
      @elements.find do |element|
        case element
        in Element::SolvedExistential(existential_name, existential_type)
          existential_name == name
        else
          false
        end
      end

    solved_existential&.then { it.type }
  end

  def has?(element)
    @elements.include?(element)
  end

  def index(element)
    @elements.index(element)
  end

  def push(elements)
    Context.new(@elements + Array(elements))
  end

  def split(element)
    left, right = @elements.partition { it == element }
    [Context.new(left), Context.new(right)]
  end
end

def monotype?(type)
  case type
  in Type::Quantification
    false

  in Type::Lambda(arg_type, body_type)
    monotype?(arg_type) && monotype?(body_type)

  else
    true
  end
end

def type_well_formed?(type, context)
  case type
  # Figure 7. UnitWF
  #
  # Γ ⊢ 1
  in Type::Int
    true

  # Figure 7. UnitWF
  #
  # Γ ⊢ 1
  in Type::String
    true

  # Figure 7. UvarWF
  #
  # Γ[a] ⊢ a
  in Type::Variable(name)
    context.has?(Context::Element::Variable.new(name))

  # Figure 7. EvarWF and SolvedEvarWF
  #
  # Γ[â] ⊢ â
  # Γ[â=t] ⊢ â
  in Type::Existential(name)
    context.has?(Context::Element::UnsolvedExistential.new(name)) ||
      context.find_solved_existential(name).present?

  # Figure 7. ArrowWF
  #
  # Γ ⊢ A    Γ ⊢ B
  # --------------
  # Γ ⊢ A -> B
  in Type::Lambda(arg_type, body_type)
    type_well_formed?(arg_type, context) && type_well_formed?(body_type, context)

  # Figure 7. ForallWF
  #
  # Γ, a ⊢ A
  # ---------
  # Γ ⊢ ∀a.A
  in Type::Quantification(name, type)
    type_well_formed?(type, context.push(Context::Element::Variable.new(name)))

  else
    raise "unknown type: #{type}"
  end
end

$fresh_name_counter = 0
def fresh_name
  $fresh_name_counter += 1
  "x#{$fresh_name_counter}"
end

def synthesize(expr, context)
  case expr
  # Figure 11. 1I=>
  #
  # Γ ⊢ () => 1 ⊣ Γ
  in Expression::LiteralInt
    [Type::Int.new, context]

  # Figure 11. 1I=>
  #
  # Γ ⊢ () => 1 ⊣ Γ
  in Expression::LiteralString
    [Type::String.new, context]

  # Figure 11. Var
  #
  # (x : A) ∈ Γ
  # --------------
  # Γ ⊢ x => A ⊣ Γ
  in Expression::Variable(varname)
    vartype = context.lookup(varname)
    return [vartype, context] if vartype
    raise "unknown variable"

  # Figure 11. Anno
  #
  # Γ ⊢ A    Γ ⊢ e <= A ⊣ Δ
  # -----------------------
  # Γ ⊢ (e : A) => A ⊣ Δ
  in Expression::Annotation(e, type)
    raise "invalid type" if !type_well_formed?(type, context)
    delta = check(e, type, context)
    [type, delta]

  # Figure 11. ->I=>
  #
  # Γ, â, b̂, x : â ⊢ e <= b̂ ⊣ Δ, x : â, Θ
  # -------------------------------------
  # Γ ⊢ λx.e => â -> b̂ ⊣ Δ
  in Expression::Lambda(arg_name, body_expr)
    alpha_name = fresh_name
    beta_name = fresh_name

    alpha_type = Type::Existential.new(alpha_name)
    beta_type = Type::Existential.new(beta_name)
    lambda_type = Type::Lambda.new(alpha_type, beta_type)

    arg_has_type_alpha = Context::Element::TypedVariable.new(arg_name, alpha_type)

    gamma = context.push([
      Context::Element::UnsolvedExistential.new(alpha_name),
      Context::Element::UnsolvedExistential.new(beta_name),
      arg_has_type_alpha
    ])

    output_context = check(body_expr, beta_type, gamma)
    delta, _theta = output_context.split(arg_has_type_alpha)
    [lambda_type, delta]

  # Figure 10. ->E
  #
  # Γ ⊢ e1 => A ⊣ Θ    Θ ⊢ [Θ]A·e2 =>=> C ⊣ Δ
  # ------------------------------------------
  # Γ ⊢ e1 e2 => C ⊣ Δ
  in Expression::Application(e1, e2)
    a, theta = synthesize(e1, context)
    c, delta = synthesize_application(theta.apply(a), e2, theta)
    [c, delta]

  else
    raise "unknown expression"
  end
end

def synthesize_application(lambda_type, arg_expr, context)
  case lambda_type

  # Figure 10. ∀App
  #
  # Γ, â ⊢ [â/a]A·e =>=> C ⊣ Δ
  # --------------------------
  # Γ ⊢ ∀a.A·e =>=> C ⊣ Δ
  in Type::Quantification(alpha, a)
    â_name = fresh_name
    â_unsolved = Context::Element::UnsolvedExistential.new(â_name)
    â_type = Type::Existential.new(â_name)
    gamma = context.push(â_unsolved)
    substituted_a = substitute(â_type, alpha, a)
    synthesize_application(substituted_a, arg_expr, gamma)

  # Figure 10. âApp
  #
  # Γ[â2, â1, â = â1 -> â2] ⊢ e <= â1 ⊣ Δ
  # -------------------------------------
  # Γ[â] ⊢ â·e =>=> â2 ⊣ Δ
  in Type::Existential(â)
    â1_name = fresh_name
    â2_name = fresh_name
    â1 = Context::Element::UnsolvedExistential.new(â1_name)
    â2 = Context::Element::UnsolvedExistential.new(â2_name)
    â_solved = Context::Element::SolvedExistential.new(â, Type::Lambda.new(Type::Existential.new(â1_name), Type::Existential.new(â2_name)))
    gamma = context.replace(Context::Element::UnsolvedExistential.new(â), [â2, â1, â_solved])
    delta = check(arg_expr, Type::Existential.new(â1_name), gamma)
    [Type::Existential.new(â2_name), delta]

  # Figure 10. ->App
  #
  # Γ ⊢ e <= A ⊣ Δ
  # -----------------------
  # Γ ⊢ A -> C·e =>=> C ⊣ Δ
  in Type::Lambda(arg_type, body_type)
    delta = check(arg_expr, arg_type, context)
    [body_type, delta]

  else
    raise "unexpected application: #{lambda_type}"
  end
end

def check(expr, type, context)
  case [expr, type]

  # Figure 11. 1I
  #
  # Γ ⊢ () <= 1  ⊣ Γ
  in [Expression::LiteralInt, Type::Int]
    context

  # Figure 11. 1I
  #
  # Γ ⊢ () <= 1  ⊣ Γ
  in [Expression::LiteralString, Type::String]
    context

  # Figure 11. ->I
  #
  # Γ, x : A ⊢ e <= B ⊣ Δ, x : A, Θ
  # -------------------------------
  # Γ ⊢ λx.e <= A -> B ⊣ Δ
  in [Expression::Lambda(x, e), Type::Lambda(a, b)]
    arg_annotation = Context::Element::TypedVariable.new(x, a)
    gamma = context.push(arg_annotation)
    result = check(e, b, gamma)
    delta, _thteta = result.split(arg_annotation)
    delta

  # Figure 11. ∀I
  #
  # Γ, a ⊢ e <= A ⊣ Δ, a, Θ
  # -----------------------
  # Γ ⊢ e <= ∀α.A ⊣ Δ
  in [e, Type::Quantification(alpha, a)]
    alpha_var = Context::Element::Variable.new(alpha)
    gamma = context.push(alpha_var)
    result = check(e, a, gamma)
    delta, _theta = result.split(alpha_var)
    delta

  # Figure 11. Sub
  #
  # Γ ⊢ e => A ⊣ Θ    Θ ⊢ [Θ]A <: [Θ]B ⊣ Δ
  # --------------------------------------
  # Γ ⊢ e <= B ⊣ Δ
  else
    synthesized_type, theta = synthesize(expr, context)
    subtype(theta.apply(synthesized_type), theta.apply(type), theta)
  end
end

def subtype(type_a, type_b, context)
  case [type_a, type_b]

  # Figure 9. Unit
  #
  # Γ ⊢ 1 <: 1 ⊣ Γ
  in [Type::Int, Type::Int]
    context

  # Figure 9. Unit
  #
  # Γ ⊢ 1 <: 1 ⊣ Γ
  in [Type::String, Type::String]
    context

  # Figure 9. Var
  #
  # Γ[a] ⊢ a <: a ⊣ Γ[a]
  in [Type::Variable(name_a), Type::Variable(name_b)]
    raise "subtype mismatch: #{name_a} #{name_b}" if name_a != name_b
    context

  # Figure 9. Exvar (+ fallback to right instantiation)
  #
  # Γ[â] ⊢ â <: â ⊣ Γ[â]
  in [Type::Existential(name_a), Type::Existential(name_b)]
    return context if name_a == name_b
    instantiate_right(type_a, name_b, context)

  # Figure 9. <:->
  #
  # Γ ⊢ B1 <: A1 ⊣ Θ   Θ ⊢ [Θ]A2 <: [Θ]B2 ⊣ Δ
  # -----------------------------------------
  # Γ ⊢ A1 -> A2 <: B1 -> B2 ⊣ Δ
  in [Type::Lambda(a1, a2), Type::Lambda(b1, b2)]
    theta = subtype(b1, a1, context)
    delta = subtype(theta.apply(a2), theta.apply(b2), theta)
    delta

  # Figure 9. <:∀L
  #
  # Γ, ▶â, â ⊢ [â/a]A <: B ⊣ Δ, ▶â, Θ
  # ---------------------------------
  # Γ ⊢ ∀a.A <: B ⊣ Δ
  in [Type::Quantification(alpha, a), _]
    â_name = fresh_name
    â_marker = Context::Element::Marker.new(â_name)
    â_unsolved = Context::Element::UnsolvedExistential.new(â_name)
    â_type = Type::Existential.new(â_name)
    substituted_a = substitute(â_type, alpha, a)
    gamma = context.push(â_marker).push(â_unsolved)
    result = subtype(substituted_a, type_b, gamma)
    delta, _theta = result.split(â_marker)
    delta

  # Figure 9. <: ∀R
  #
  # Γ, a ⊢ A <: B ⊣ Δ, a, Θ
  # -----------------------
  # Γ ⊢ A <: ∀a.B ⊣ Δ
  in [a, Type::Quantification(alpha, b)]
    alpha_var = Context::Element::Variable.new(alpha)
    gamma = context.push(alpha_var)
    result = subtype(a, b, gamma)
    delta, _theta = result.split(alpha_var)
    delta

  # Figure 9. <:∀R
  #
  # Γ, a ⊢ A <: B ⊣ Δ, a, Θ
  # ------------------------
  # Γ ⊢ A <: ∀a.B ⊣ Δ
  in [_, Type::Quantification(name, subtype)]
    alpha_var = Context::Element::Variable.new(name)
    gamma = context.push(alpha_var)
    result = subtype(type_a, subtype, gamma)
    delta, _theta = result.split(alpha_var)
    delta

  # Figure 9. <:InstantiateL
  #
  # â ∉ FV(A)    Γ[â] ⊢ â <=: A ⊣ Δ
  # --------------------------------
  # Γ[â] ⊢ â <: A ⊣ Δ
  in [Type::Existential(existential_name), _]
    raise "circular instantiation: #{type_a} #{type_b}" if occurs?(existential_name, type_b)
    instantiate_left(type_b, existential_name, context)

  # Figure 9. <:InstantiateR
  #
  # â ∉ FV(A)    Γ[â] ⊢ A <=: â ⊣ Δ
  # --------------------------------
  # Γ[â] ⊢ A <: â ⊣ Δ
  in [_, Type::Existential(existential_name)]
    raise "circular instantiation: #{type_a} #{type_b}" if occurs?(existential_name, type_a)
    instantiate_right(type_a, existential_name, context)

  else
    raise "subtype mismatch: #{type_a} #{type_b}"
  end
end

def instantiate_left(type, existential_name, context)
  # Figure 10. InstLSolve
  #
  # Γ ⊢ t
  # -------------------------------
  # Γ, a, Γ' ⊢ â <=: t ⊣ Γ, â=t, Γ'
  if monotype?(type) && type_well_formed?(type, context)
    return context.replace(
      Context::Element::UnsolvedExistential.new(existential_name),
      Context::Element::SolvedExistential.new(existential_name, type)
    )
  end

  case type
  # Figure 10. InstLReach
  #
  # Γ[â][b̂] ⊢ â <=: b̂ ⊣ Γ[â][b̂ = â]
  in Type::Existential(beta_name)
    alpha_name = existential_name
    alpha = Context::Element::UnsolvedExistential(alpha_name)
    beta = Context::Element::UnsolvedExistential(beta_name)
    if context.index(alpha) < context.index(beta)
      solved = Context::Element::SolvedExistential.new(beta_name, Type::Existential.new(alpha_name))
      context.replace(beta, solved)
    else
      solved = Context::Element::SolvedExistential.new(alpha_name, Type::Existential.new(beta_name))
      context.replace(alpha, solved)
    end

  # Figure 10. InstLArr
  #
  # Γ[â2, â1, â = â1 -> â2] ⊢ A1 <=: â1 ⊣ Θ    Θ ⊢ â2 <=: [Θ]A2 ⊣ Δ
  # ---------------------------------------------------------------
  # Γ[â] ⊢ â <=: A1 -> A2 ⊣ Δ
  in Type::Lambda(a1, a2)
    â_name = existential_name
    â1_name = fresh_name
    â2_name = fresh_name
    â1 = Context::Element::UnsolvedExistential.new(â1_name)
    â2 = Context::Element::UnsolvedExistential.new(â2_name)
    â_solved = Context::Element::SolvedExistential.new(â_name, Type::Lambda.new(Type::Existential.new(â1_name), Type::Existential.new(â2_name)))
    gamma = context.replace(Context::Element::UnsolvedExistential.new(â_name), [â2, â1, â_solved])
    theta = instantiate_right(a1, â1_name, gamma)
    delta = instantiate_left(theta.apply(a2), â2_name, theta)
    delta

  # Figure 10: InstLAIIR
  #
  # Γ[â], b ⊢ â <=: B ⊣ Δ, b, Δ'
  # ----------------------------
  # Γ[â] ⊢ â <=: ∀b.B ⊣ Δ
  in Type::Quantification(beta, b)
    beta_var = Context::Element::Variable.new(beta)
    gamma = context.push(beta_var)
    result = instantiate_left(b, existential_name, gamma)
    delta, _other = result.split(beta_var)
    delta

  else
    raise "invalid left instantiation: #{type} #{existential_name}"
  end
end

def instantiate_right(type, existential_name, context)
  # Figure 10. InstRSolve
  #
  # Γ ⊢ t
  # --------------------------------
  # Γ, â, Γ' ⊢ t <=: â ⊣ Γ, â = t, Γ'
  if monotype?(type) && type_well_formed?(type, context)
    return context.replace(
      Context::Element::UnsolvedExistential.new(existential_name),
      Context::Element::SolvedExistential.new(existential_name, type)
    )
  end

  case type
  # Figure 10. InstRReach
  #
  # Γ[â][b̂] ⊢ â <=: b̂ ⊣ Γ[â][b̂ = â]
  in Type::Existential(beta_name)
    alpha_name = existential_name
    alpha = Context::Element::UnsolvedExistential(alpha_name)
    beta = Context::Element::UnsolvedExistential(beta_name)
    if context.index(alpha) < context.index(beta)
      solved = Context::Element::SolvedExistential.new(beta_name, Type::Existential.new(alpha_name))
      context.replace(beta, solved)
    else
      solved = Context::Element::SolvedExistential.new(alpha_name, Type::Existential.new(beta_name))
      context.replace(alpha, solved)
    end

  # Figure 10. InstRArr
  #
  # Γ[â2, â1, â = â1 -> â2] ⊢ â1 <=: A1 ⊣ Θ    Θ ⊢ [Θ]A2 <=: â2 ⊣ Δ
  # ---------------------------------------------------------------
  # Γ[â] ⊢ A1 -> A2 <=: â ⊣ Δ
  in Type::Lambda(a1, a2)
    â_name  = existential_name
    â1_name = fresh_name
    â2_name = fresh_name
    â1 = Context::Element::UnsolvedExistential.new(â1_name)
    â2 = Context::Element::UnsolvedExistential.new(â2_name)
    â_solved = Context::Element::SolvedExistential.new(â_name, Type::Lambda.new(Type::Existential.new(â1_name), Type::Existential.new(â2_name)))
    gamma = context.replace(Context::Element::UnsolvedExistential.new(â_name), [â2, â1, â_solved])
    theta = instantiate_left(a1, â1_name, gamma)
    delta = instantiate_right(theta.apply(a2), â2_name, theta)
    delta

  # Figure 10. InstRAIIL
  #
  # Γ[â], ▶b̂, b̂ ⊢ [b̂/b]B <=: â ⊣ Δ, ▶b̂, Δ'
  # ---------------------------------------------------------------
  # Γ[â] ⊢ ∀b.B <=: â ⊣ Δ
  in Type::Quantification(beta, b)
    b̂_name = fresh_name
    b̂_marker = Context::Element::Marker.new(b̂_name)
    b̂_unsolved = Context::Element::UnsolvedExistential.new(b̂_name)
    substituted_b = substitute(Type::Existential.new(b̂_name), b̂_name, b)
    gamma = context.push(b̂_marker).push(b̂_unsolved)
    result = instantiate_right(substituted_b, existential_name, gamma)
    delta, _other = result.split(b̂_marker)
    delta

  else
    raise "invalid right instantiation: #{type} #{existential_name}"
  end
end

def substitute(substitution_type, alpha, original_type)
  case original_type
  in Type::Variable(name)
    name == alpha ? substitution_type : original_type

  in Type::Existential(name)
    name == alpha ? substitution_type : original_type

  in Type::Lambda(arg_type, body_type)
    original_type.with(
      arg_type: substitute(substitution_type, alpha, arg_type),
      body_type: substitute(substitution_type, alpha, body_type)
    )

  in Type::Quantification(name, subtype)
    if name == alpha
      original_type.with(subtype: substitution)
    else
      original_type.with(subtype: substitute(substitution_type, alpha, subtype))
    end

  else
    original_type
  end
end

def occurs?(name, type)
  case type
  in Type::Int
    false

  in Type::String
    false

  in Type::Variable(var_name)
    var_name == name

  in Type::Existential(existential_name)
    existential_name == name

  in Type::Lambda(arg_type, return_type)
    occurs?(name, arg_type) || occurs?(name, return_type)

  in Type::Quantification(alpha, subtype)
    name == alpha || occurs?(name, subtype)

  else
    raise "unknown type: #{type}"
  end
end

def infer(expr)
  type, context = synthesize(expr, Context.empty)
  context.apply(type)
end

puts synthesize(
  Expression::LiteralInt.new(42),
  Context.empty
) # => #<data Type::Int>

puts synthesize(
  Expression::Annotation.new(
    Expression::LiteralString.new("hello"),
    Type::String.new
  ),
  Context.empty
) # => #<data Type::String>

puts synthesize(
  Expression::Annotation.new(
    Expression::Lambda.new("x", Expression::Variable.new("x")),
    Type::Quantification.new("a", Type::Lambda.new(Type::Variable.new("a"), Type::Variable.new("a")))
  ),
  Context.empty
) # => #<data Type::Quantification name="a", subtype=#<data Type::Lambda arg_type=#<data Type::Variable name="a">, body_type=#<data Type::Variable name="a">>>

id = Expression::Annotation.new(
  Expression::Lambda.new("x", Expression::Variable.new("x")),
  Type::Quantification.new("a", Type::Lambda.new(Type::Variable.new("a"), Type::Variable.new("a")))
)

call42 = Expression::Annotation.new(
  Expression::Lambda.new(
    "f",
    Expression::Application.new(Expression::Variable.new("f"), Expression::LiteralInt.new(42))
  ),
  Type::Lambda.new(
    Type::Lambda.new(Type::Int.new, Type::Int.new),
    Type::Int.new
  )
)

puts infer(Expression::Application.new(call42, id)) # => #<data Type::Int>
