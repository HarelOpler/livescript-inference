class If < Node
  def parseNextNode(ast_json)
    @if = parseAstFromJsonToNodes(ast_json["if"])
    @else = parseAstFromJsonToNodes(ast_json["else"])
    @then = parseAstFromJsonToNodes(ast_json["then"])
  end
  def get_vars()
    @if.get_vars
    @else&.get_vars
    @then.get_vars
    @type = @then.type
  end
end