class  Index < Node
  attr_accessor :prototype, :key, :is_paren, :inner_type, :is_array
  def parseNextNode(ast_json)
    @key = parseAstFromJsonToNodes(ast_json, "key")
    @is_paren = false
  end
  def get_vars()
    @key.get_vars()
    if @key.class == Key
      if @key.name == "prototype"
        @prototype = true
      end
    elsif @key.class == Parens
      @is_paren = true
      @inner_type = @key.inner_type
    end
  end
  def head
    self
  end
  def value
    @key.name
  end
end