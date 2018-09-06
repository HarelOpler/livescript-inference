class Unary < Node
  def parseNextNode(ast_json)
    #TODO: fix Unary
    @it = parseAstFromJsonToNodes(ast_json["it"])
  end
  def get_vars()
    @it.get_vars
    @type = @it.type
  end

end
