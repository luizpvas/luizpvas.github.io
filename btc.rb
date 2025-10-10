module Expression
  LiteralInt = Data.define(:value)
  LiteralString = Data.define(:value)
  Variable = Data.define(:name)
  Annotation = Data.define(:expression, :type)
  Lambda = Data.define(:arg_name, :body_expr)
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
  end

  def self.empty = new([])

  def initialize(elements = [])
    @elements = elements
  end

  def lookup(name)
    typedvar =
      @elements.find do |element|
        case element
        in Element::TypedVariable(varname, _) then varname == name
        else false
        end
      end

    typedvar&.then { it.type }
  end

  def replace(element_old, element_new)
    elements = @elements.map { |element| element == element_old ? element_new : element }

    Context.new(elements)
  end

  def apply(type)
    case type
    in Type::Int
      type

    in Type::String
      type

    in Type::Variable
      type

    in Type::Existential(name)
      solved_type = find_solved_existential(name)
      solved_type ? apply(solved_type) : type

    in Type::Lambda(arg_type, body_type)
      type.with(arg_type: apply(arg_type), body_type: apply(body_type))

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

def type_well_formed?(type, context)
  case type
  in Type::Int
    true

  in Type::String
    true

  in Type::Variable(name)
    context.has?(Context::Element::Variable.new(name))

  in Type::Existential(name)
    context.has?(Context::Element::UnsolvedExistential.new(name)) ||
      context.find_solved_existential(name).present?

  in Type::Lambda(arg_type, body_type)
    puts "how about here?"
    type_well_formed?(arg_type, context) && type_well_formed?(body_type, context)

  # ForallWF
  #
  # Γ, α ⊢ A
  # ---------
  # Γ ⊢ ∀α.A
  in Type::Quantification(name, type)
    puts "got here?"
    puts name
    puts type
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
  in Expression::LiteralInt
    [Type::Int.new, context]

  in Expression::LiteralString
    [Type::String.new, context]

  in Expression::Variable(varname)
    vartype = context.lookup(varname)
    return [vartype, context] if vartype
    raise "unknown variable"

  in Expression::Annotation(e, type)
    raise "invalid type" if !type_well_formed?(type, context)
    delta = check(e, type, context)
    [type, delta]

  in Expression::Lambda(arg_name, body_expr)
    alpha_name = fresh_name
    beta_name = fresh_name

    alpha_type = Type::Existential.new(alpha_name)
    beta_type = Type::Existential.new(beta_name)
    lambda_type = Type::Lambda.new(alpha_type, beta_type)

    arg_has_type_alpha = Context::Element::TypedVariable.new(arg_name, alpha_type)

    gamma = context.push([
      Context::Element::UnsolvedExistential.new(alpha_name),
      Context::Element::UnsolvedExistential.new(alpha_name),
      arg_has_type_alpha
    ])

    output_context = check(body_expr, beta_type, gamma)
    delta, _theta = output_context.split(arg_has_type_alpha)
    [lambda_type, delta]

  else
    raise "unknown expression"
  end
end

def check(expr, type, context)
  case [expr, type]

  in [Expression::LiteralInt, Type::Int]
    context

  in [Expression::LiteralString, Type::String]
    context

  else
    synthesized_type, theta = synthesize(expr, context)
    subtype(theta.apply(synthesized_type), theta.apply(type), theta)
  end
end

def subtype(type_a, type_b, context)
  case [type_a, type_b]

  in [Type::Int, Type::Int]
    context

  in [Type::String, Type::String]
    context

  in [Type::Variable(name_a), Type::Variable(name_b)]
    raise "subtype mismatch: #{name_a} #{name_b}" if name_a != name_b
    context

  in [Type::Existential(name_a), Type::Existential(name_b)]
    return context if name_a == name_b
    instantiate_right(type_a, name_b, context)

  in [_, Type::Existential(existential_name)]
    raise "circular instantiation: #{type_a} #{type_b}" if occurs?(existential_name, type_a)
    instantiate_right(type_a, existential_name, context)

  else
    raise "subtype mismatch: #{type_a} #{type_b}"
  end
end

def instantiate_right(type, existential_name, context)
  if type_well_formed?(type, context)
    return context.replace(
      Context::Element::UnsolvedExistential.new(existential_name),
      Context::Element::SolvedExistential.new(existential_name, type)
    )
  end

  case type
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

  else
    raise "invalid right instantiation: #{type} #{existential_name}"
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
) # subtype mismatch: #<data Type::Lambda arg_type=#<data Type::Existential name="x1">, body_type=#<data Type::Existential name="x2">> #<data Type::Quantification name="a", subtype=#<data Type::Lambda arg_type=#<data Type::Variable name="a">, body_type=#<data Type::Variable name="a">>> (RuntimeError)
