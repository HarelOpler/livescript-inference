class Parens < Node
  attr_accessor :inner_type, :it
  def parseNextNode(ast_json)
    # TODO: fix parens
    @it = parseAstFromJsonToNodes(ast_json["it"])
  end
  def get_vars
    @it.get_vars
    @@scope.add_subtype(SubType.new(@it.type, Constant.new("int")))
    @inner_type = VarUtils.gen_type
    @@scope.add_var_unifier(@inner_type)
    @type  = Compound.new(Constant.new("Array"),[@inner_type],[@inner_type])
    @@scope.add_var_unifier(@type)
  end
  def name
    return "aaa"
  end
end