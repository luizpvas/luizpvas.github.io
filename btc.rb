module Expression
  LiteralInt = Data.define(:value)
  LiteralString = Data.define(:value)
  Variable = Data.define(:name)
  Annotation = Data.define(:expression, :type)
end

module Type
  Int = Data.define
  String = Data.define
end

class Context
  module Element
    TypedVariable = Data.define(:name, :type)
  end

  def initialize
    @elements = []
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
    raise "type mismatch"
  end
end

puts synthesize(
  Expression::LiteralInt.new(42),
  Context.new
) # => #<data Type::Int>

puts synthesize(
  Expression::Annotation.new(
    Expression::LiteralString.new("hello"),
    Type::String.new
  ),
  Context.new
) # => #<data Type::String>
