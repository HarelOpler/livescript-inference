class Return < Node
  def parseNextNode(ast_json)
    @it = parseAstFromJsonToNodes(ast_json["it"])
  end
  def get_vars()
    @it.get_vars
    @type = @it.type
  end
end