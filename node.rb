class Node
  @@scope = nil
  attr_accessor :type, :value, :prev
  def parseNextNode(ast_jsno)
    @error = "unidentified node"
  end

  def self.scope
    @@scope
  end
  def self.scope=(scope)
    @@scope=scope
  end

  def get_vars()
    raise NotImplementedError
  end

  def value
    raise NotImplementedError
  end
end