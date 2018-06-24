class Obj < Node
  def parseNextNode(ast_json)
    @items = []
    ast_json["items"].each { |inner_prop|
      @items << parseAstFromJsonToNodes(inner_prop)
    }
  end

  def get_vars()
    @items.each { |item| item.get_vars() }
  end
end