# Use a VM module?

abstract struct Error; end
record InvalidMemoryAccess < Error, idx : Int32

class Memory
  def initialize(@raw : Array(Int32))
  end

  def [](idx)
    return InvalidMemoryAccess.new(idx) unless check_idx(idx)
    @raw[idx]
  end

  def []=(idx, value)
    return InvalidMemoryAccess.new(idx) unless check_idx(idx)
    @raw[idx] = value
  end

  delegate to_s, size, to: @raw

  private def check_idx(idx)
    0 <= idx < @raw.size
  end
end

module Utils::Debuggable
  macro included
    property? debug = false

    private def __debug(*args)
      return unless debug?
      args.each do |arg|
        print "DEBUG: "
        puts arg
      end
      puts if args.size == 0
    end

    {% verbatim do %}
    private macro __debug!(*args) # Cannot be protected because of some crystal design decision
      return unless debug?
      {% for arg in args %}
        print "DEBUG: "
        p!({{ arg }})
      {% end %}
    end
    {% end %}
  end
end

class IntCodeVM
  include Utils::Debuggable

  annotation Opcode; end

  def self.from_program(prog_str)
    raw_memory = prog_str.split(',').map &.to_i
    new Memory.new raw_memory
  end

  getter? running = false
  getter memory : Memory
  getter error : Error? = nil

  alias InstructionHandler = -> # TODO: args & return ?
  @instructions : Hash(Int32, InstructionHandler)

  def initialize(@memory)
    @ip = 0
    @instructions = gather_instructions
  end

  def gather_instructions
    all_instr = {} of Int32 => InstructionHandler
    {% for op_def in @type.methods.select { |m| !!m.annotation(Opcode) } %}
      {% op_ann = op_def.annotation(Opcode) %}
      {% opcode = op_ann.args.first %}
      {% op_arg_kinds = op_ann.args[1..-1] %}

      instr_handler = ->do
        {% if op_def.args.size == 0 %}
          decoded_args = Tuple.new
        {% else %}
          decoded_args = {
            {% for arg, idx in op_def.args %}
              err_guard(@memory[@ip + 1 + {{ idx }}]),
            {% end %}
          }
        {% end %}

        err_guard({{ op_def.name }}(*decoded_args))

        {{ op_def.args.size }}
      end

      all_instr[{{ opcode }}] = instr_handler
      {% debug %}
    {% end %}

    all_instr
  end

  def run
    @running = true
    while @running
      err = exec_next_instruction
      if err.is_a? Error
        @running = false
        @error = err
      end
    end

    @error.nil?
  end

  def exec_next_instruction
    return false unless @running

    opcode = err_guard @memory[@ip]
    if instr_handler = @instructions[opcode]?
      nb_args = err_guard instr_handler.call # FIXME: give some args?
      @ip += 1 + nb_args # opcode + args
    else
      puts "/!\\/!\\ WARNING: Unknown opcode #{opcode} at IP:#{@ip}, skipping"
      @ip += 1
    end

    # case opcode = err_guard @memory[@ip]
    # when 1
    #   from_addr1 = err_guard @memory[@ip + 1]
    #   from_addr2 = err_guard @memory[@ip + 2]
    #   to_addr = err_guard @memory[@ip + 3]
    #   result = err_guard(@memory[from_addr1]) + err_guard(@memory[from_addr2])

    #   __debug "[IP:#{@ip}] Opcode add : mem[#{to_addr}] <- mem[#{from_addr1}] + mem[#{from_addr2}]"

    #   err_guard @memory[to_addr] = result
    #   @ip += 4

    # when 2
    #   from_addr1 = err_guard @memory[@ip + 1]
    #   from_addr2 = err_guard @memory[@ip + 2]
    #   to_addr = err_guard @memory[@ip + 3]
    #   result = err_guard(@memory[from_addr1]) * err_guard(@memory[from_addr2])

    #   __debug "[IP:#{@ip}] Opcode mul : mem[#{to_addr}] <- mem[#{from_addr1}] * mem[#{from_addr2}]"

    #   err_guard @memory[to_addr] = result
    #   @ip += 4

    # when 99
    #   __debug "[IP:#{@ip}] Opcode quit!"
    #   @running = false

    # else
    #   puts "/!\\/!\\ WARNING: Unknown opcode #{opcode} at IP:#{@ip}, skipping"
    #   @ip += 1

    # end
  end

  def decode_instruction(instr, &)
    # TODO?
  end

  @[Opcode(1, :addr, :addr, :addr)]
  def op_add(from_addr1, from_addr2, to_addr)
    from_addr1 = err_guard @memory[@ip + 1]
    from_addr2 = err_guard @memory[@ip + 2]
    to_addr = err_guard @memory[@ip + 3]
    result = err_guard(@memory[from_addr1]) + err_guard(@memory[from_addr2])

    __debug "[IP:#{@ip}] Opcode add : mem[#{to_addr}] <- mem[#{from_addr1}] + mem[#{from_addr2}]"

    err_guard @memory[to_addr] = result

    # @ip += 4 # Should be done by the caller
  end

  @[Opcode(2, :addr, :addr, :addr)]
  def op_mul(from_addr1, from_addr2, to_addr)
    from_addr1 = err_guard @memory[@ip + 1]
    from_addr2 = err_guard @memory[@ip + 2]
    to_addr = err_guard @memory[@ip + 3]
    result = err_guard(@memory[from_addr1]) * err_guard(@memory[from_addr2])

    __debug "[IP:#{@ip}] Opcode mul : mem[#{to_addr}] <- mem[#{from_addr1}] * mem[#{from_addr2}]"

    err_guard @memory[to_addr] = result
  end

  @[Opcode(99)]
  def op_quit
    __debug "[IP:#{@ip}] Opcode quit!"
    @running = false
  end

  # Returns the result of the program
  def result
    @memory[0]
  end

  protected def method_name(*args)

  end


  # Returns the error from the current method if the result of *node* is an error.
  macro err_guard(node) # Should be protected... but macro can't be protected
    %value = ({{ node }})
    return %value if %value.is_a?(Error)
    %value
  end
end

