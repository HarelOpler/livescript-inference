require './node.rb'

class Block < Node
  def parseNextNode(ast_json)
    @lines = []
    ast_json["lines"].each { |inner_ast|
      @lines << parseAstFromJsonToNodes(inner_ast)
    }
  end

  def get_vars()
    @lines.each { |line|
      line.get_vars()
    }
    # Ignore the dummy function after a block starts
    unless @lines[-1].class == Fun && @lines[-1].is_class_function
      @value = @lines[-1] #last line
      if @value.nil?
        @type = Constant.new("unit") #or undefined?
      else
        @type = @value.type
      end
    end
  end
end