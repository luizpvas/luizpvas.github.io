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
  Lambda = Data.define(:argtype, :bodytype)
end

class Context
  module Element
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

    in Type::Existential(name)
      solved_type = find_solved_existential(name)
      solved_type ? apply(solved_type) : type

    in Type::Lambda(arg_type, body_expr)
      Type::Lambda(apply(arg_type), apply(body_expr))

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
  in Type::Int then true # UnitWF rule
  in Type::String then true # UnitWF rule
  else raise "unknown type: #{type}"
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
    raise "subtype mismatch: #{name_a} #{name_b}" if name_a != name_b
    context

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

  raise "invalid right instantiation: #{type} #{existential_name}"
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
  Expression::Lambda.new("x", Expression::LiteralInt.new(1)),
  Context.empty
) # => #<data Type::Lambda argtype=#<data Type::Existential name="x1">, bodytype=#<data Type::Existential name="x2">>
