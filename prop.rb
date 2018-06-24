class Prop < Node
  def parseNextNode(ast_json)
    @key = parseAstFromJsonToNodes(ast_json, "key")
    @val = parseAstFromJsonToNodes(ast_json, "val")
  end

  def get_vars()
    @key.get_vars()
    @val.get_vars()
    @@scope.add_var(@key.name,@key.name)
    @@scope.update_type(@key.name,@val.type)
  end
end