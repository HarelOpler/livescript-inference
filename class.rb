class Class_ < Node

  def parseNextNode(ast_json)
    @name = ast_json["title"]["value"]
    @body = parseAstFromJsonToNodes(ast_json, "fun") # mark Fun as class body
    @body.is_class_function = true
    @sup = ast_json["sup"]
    if @sup.nil?
      @sup = Constant.new("Any")
    else
      @sup = Constant.new(@sup["value"])
    end
  end

  def get_vars()
    @@scope = @@scope.scope(ClassScope.new(@name))
    @body.get_vars()
    @@scope = @@scope.unscope
    @@scope.add_coercion(Constant.new(@name),@sup)
  end
  def value()
    @name
  end
end