class Literal < Node
  def parseNextNode(ast_json)
    @value = ast_json["value"]
  end
  def get_vars()
    # Temporary for simple literals and naive checks
    if @value == "true" || @value =="false"
      @type = "bool"
    elsif @value.to_i.to_s == @value
      @type = "int"
    elsif @value.to_f.to_s == @value
      @type = "float"
    elsif @value == "null"
      @type = "null"
    else
      @type = "string"
    end
    @type = Constant.new(@type)
  end
  def value
    @value
  end
end