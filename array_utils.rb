require './var_utils'
ARRAY_ELEMENT_POSTFIX = ".ArrayElement"
class ArrayUtils


  def initialize
    @arraysCounter = 0
  end

  def self.getInstance
    if @instance == nil
      @instance = ArrayUtils.new
    end
    return @instance
  end

  def getTypeOfArrayElements(scope, name)
    arr = scope.search(name)
    if arr == nil
      return nil
    end
    return arr.elements_type
  end

  def getOrCreateTypeForArrayElements(scope,name)
    type = getTypeOfArrayElements(scope,name)
    if type == nil
      VarUtils.getInstance.addVariable(scope,name)
    end
  end

  def getNameForArrayElementsType()
    @arraysCounter += 1
    "ArrayType_"+@arraysCounter.to_s
  end
end