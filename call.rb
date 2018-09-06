class Call < Node
  attr_accessor :args
@@return_var = 0
def parseNextNode(ast_json)
  @args = []
  ast_json["args"].each { |e|
    @args << parseAstFromJsonToNodes(e)
  }
end
def get_vars()
  type = @prev.type
  # if type.nil?
  # 	type = @@scope.search(@prev.head.value)
  # end
  if type.nil?
    pp @prev
    raise "#{@prev.head.value} not found"
  end

  @args.each { |argument|
    argument.get_vars()
  }

  args = @args.map {|argument| argument.type }
  if type.class == TypeVar
    alpha,beta,ftype = Compound.create_function_type(@@scope)
    @@scope.add_equation(Equation.new(ftype,type))
    type = ftype
  end
  @type = generate_constraints(args,type)
end

def generate_constraints(args,function_type)
  # args include return var
  # pp args.map { |e| e.name }
  # pp function_type.name
  # pp args
  if args.length <= 0
    return function_type
  end

  if function_type.class == TypeVar
    #If function_type is T-x and there are still args then T-x := alpha -> beta
    _,_,ftype = Compound.create_function_type(@@scope)
    @@scope.add_equation(Equation.new(function_type,ftype))
    function_type = ftype
  end

  tau = function_type
  sigma = args.first
  alpha,beta,ftype = Compound.create_function_type(@@scope)
  # pp "tau: #{tau.name}, sigma: #{sigma.name}"
  # pp "alpha: #{alpha.name}, beta: #{beta.name}"
  # pp "^^^^^"

  @@scope.add_equation(Equation.new(tau,ftype))
  @@scope.add_subtype(SubType.new(sigma,alpha))
  if function_type.class == Compound
    return generate_constraints(args[1..-1],function_type.tail.first)
  end


  return function_type


end
end