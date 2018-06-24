require './nodes'
class VarUtils

  def self.getInstance
    if @instance == nil
      @instance = VarUtils.new
    end
    return @instance
  end

  def getVariableType(scope,name)
    return scope.search(name)
  end

  def getVariableTypeOrCreateIfNotExisting(scope,name)
    type = getVariableType(scope,name)
    if type == nil
      name_with_scope = name + SEPERATOR +  scope.name
      return scope.add_var(name_with_scope,name)
    end
    return type
  end

  def addVariable(scope,name)
    name_with_scope = name + SEPERATOR + scope.name
    return scope.add_var(name_with_scope,name)
  end
end