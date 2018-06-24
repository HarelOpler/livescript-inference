class Key < Node
  attr_accessor :name
  def parseNextNode(ast_json)
    @name = ast_json["name"]
  end
  def get_vars()
  end
end