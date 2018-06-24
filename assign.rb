class Assign < Node
  def parseNextNode(ast_json)
    @left = parseAstFromJsonToNodes(ast_json, "left")
    @right = parseAstFromJsonToNodes(ast_json, "right")
  end

  def get_vars()
    @left.get_vars()
    @right.get_vars()
    @type = @left.type
    if @right.type.class == Compound
      # 	#if right side is a function than propogate.. not sure if correct to do so
      # 	# ASK SHACHAR
      @@scope.update_type(@left.value,@right.type)
    else
      # @@scope.add_equation(Equation.new(@left.type,@right.type))
      @@scope.add_subtype(SubType.new(@right.type, @left.type))
    end

  end
  def value()
    @right.value()
  end
end