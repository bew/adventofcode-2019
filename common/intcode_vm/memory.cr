class IntCodeVM::Memory
  def initialize(@raw : Array(Int32))
  end

  def [](idx : Int32)
    return InvalidMemoryAccess.new(idx) unless check_idx(idx)
    @raw[idx]
  end

  def [](range : Range)
    index, count = Indexable.range_to_index_and_count(range, size)
    unless check_idx(index) || check_idx(index + count)
      return InvalidMemoryAccess.new(range)
    end

    @raw[range]
  end

  def []=(idx : Int32, value : Int32)
    return InvalidMemoryAccess.new(idx) unless check_idx(idx)
    @raw[idx] = value
  end

  delegate to_s, size, to: @raw

  private def check_idx(idx)
    0 <= idx < @raw.size
  end
end

module IntCodeVM::ErrorGuardian
  macro included
    {% verbatim do %}
      # Returns the error from the current method if the result of *node* is an error.
      macro err_guard(node)
        %value = ({{ node }})
        return %value if %value.is_a?(Error)
        %value
      end
    {% end %} # verbatim
  end
end
