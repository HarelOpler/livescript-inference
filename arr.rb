require './array_utils'
class Arr < Node
  ## CHANGES-HAREL-2 - list should have a type nameholder T for its type, in order to apply the constraint T <: e for each
  # element e in the list.
  # also changed the way constraints are generated - from requiring equality between all list elements, to requiring
  # subtyping T <: e as mentioned above.
  def parseNextNode(ast_json)
    @items = ast_json["items"].map { |item| parseAstFromJsonToNodes(item) }
  end

  def get_vars

    ### Temporary code, just to register array as an identifier for subtyping
    # @type =
    # @value = "ArrayType"
    # prev_type = @@scope.search(@value)
    # @value = @value + SEPERATOR +  @@scope.name
    # @type = prev_type.nil? ? @@scope.add_var(@value,@real_name) : prev_type
    ######

    array_utils = ArrayUtils.getInstance
    elementsType = array_utils.getOrCreateTypeForArrayElements(@@scope, array_utils.getNameForArrayElementsType)

    @items.each { |item| item.get_vars }
    vars = @items.each { |item| item.type     }
    arr_type = Constant.new("Array")
    @@scope.add_var_unifier(arr_type)
    # @items.each_cons(2) { |l,r| @@scope.add_equation(Equation.new(l.type,r.type))}
    @items.each {|element| @@scope.add_subtype(SubType.new(element.type,elementsType))}
    @type = Compound.new(arr_type,[elementsType],vars)
    @type.elements_type = elementsType
    @@scope.add_var_unifier(@type)
  end
end