require './array_utils'
class Chain < Node
  attr_accessor :head, :tails
  def parseNextNode(ast_json)
    @head = parseAstFromJsonToNodes(ast_json, "head")

    @tails = ast_json["tails"].map{ |node_json|
      n = parseAstFromJsonToNodes(node_json)
      n.prev = self
      n
    }
  end

  def get_vars
    @head.get_vars()
    @tails.each { |e|
      if e.class != Call
        e.get_vars
      end
    }
    last_index = @@scope.search(@head.value)
    name_index = @head.value
    @tails.each_with_index { |e,i|
      if e.class == Index
        if e.prototype
          after_index = @tails[i+1].key.name
          update_head_type(after_index)
        else
          # t1 = last_index
          # name_index = name_index.split(SEPERATOR).first + "." + e.key.name + SEPERATOR + @@scope.name
          # last_index = @@scope.add_var(name_index)
          # e.type = last_index
          # @@scope.add_property_of(t1,last_index,name_index.split(SEPERATOR).first)
          e.type = ArrayUtils.getInstance.getTypeOfArrayElements(@@scope, name_index)
        end
      elsif e.class == Call
        e.prev =  i > 0 ? @tails[i-1] : @head
        e.get_vars
      end

    }
    @type = @tails[-1].type

  end


  def update_head_type(after_index)
    c = Constant.new(after_index)
    @@scope.add_var_unifier(c)
    @@scope.update_type(@head.value, c)
    @head.type = c
    pp "#{@head.value} is now #{c.name}"
  end
end