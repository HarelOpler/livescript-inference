class Binary < Node
  BOOL_OP = ["===", "<", ">", "<=", "=>" , "!=="]
  def parseNextNode(ast_json)
    @first = parseAstFromJsonToNodes(ast_json["first"])
    @second = parseAstFromJsonToNodes(ast_json["second"])
    @op = ast_json["op"]

  end
  def get_vars
    @first.get_vars
    @second.get_vars
    ## CHANGES-HAREL-1 - When a binary operation is used (x op y), an equation constraint is not good (will not accept
    # operations between int and float for example). should use the complex constraint that looks for the satisfaction
    # of atleast one of [x <: y, y <: x].
    # as for now, i dont have the infrastructure to create such a constraint so i will only use the constraint x <: y.
    # TODO: add symetric constraint
    createConstraintsForBinaryOp
    # x = Equation.new(@first.type, @second.type)
    # @@scope.add_equation(x)

    if BOOL_OP.include?(@op)
      @type = Constant.new("bool")
    else
      @type = @first.type
    end
    @value = @first

  end

  def createConstraintsForBinaryOp()
    @@scope.add_subtype(SubType.new(@first.type, @second.type))
  end
end