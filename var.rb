require './var_utils'
class Var < Node

  attr_accessor :value, :real_name
  def parseNextNode(ast_json)
    @value = ast_json["value"]
    @real_name = @value
    @newed = ast_json["newed"]
  end

  def get_vars()
    if @newed.nil?
      @type = VarUtils.getInstance.getVariableTypeOrCreateIfNotExisting(@@scope,@value)
    else
      @type = Constant.new(@value)
      @@scope.add_var_unifier(@type)
    end
  end
end