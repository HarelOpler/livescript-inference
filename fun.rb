class Fun < Node
  attr_accessor :is_class_function, :name
  def initialize
    @is_class_function = false
  end
  def parseNextNode(ast_json)
    @body = parseAstFromJsonToNodes(ast_json["body"])
    @params = ast_json["params"].map { |param|
      parseAstFromJsonToNodes(param)
    }
  end
  def get_vars()
    if !@is_class_function
      @name = new_fun()
      @@scope.add_var(@name)
      alpha,beta,ftype = Compound.create_function_type(@@scope)
      @@scope.update_type(@name,ftype)
      @@scope = @@scope.scope(FunctionScope.new())
    end

    @params.each { |p|
      p.get_vars
    }

    @body.get_vars
    c = @body.type

    if @is_class_function
      return
    end

    if (@params.size > 0)
      @params.reverse.map { |p|
        c = Compound.new(p.type,[c],[p.type,c])
        @@scope.add_var_unifier(p.type,c)
      } #folding right over params
    else
      c = Compound.new(Constant.new("unit"),[c],[c])
    end

    @@scope = @@scope.unscope
    @type = @@scope.update_type(@name,c)

  end
  def value
    @type
  end


  @@counter = 0
  def new_fun()
    @@counter+=1
    "->"+ @@counter.to_s
  end
end