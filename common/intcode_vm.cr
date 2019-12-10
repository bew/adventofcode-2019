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

module ErrorGuardian
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

class IntCodeVM
  include Utils::Debuggable
  include ErrorGuardian

  annotation Opcode; end

  def self.from_program(prog_str)
    raw_memory = prog_str.split(',').map &.to_i
    new Memory.new raw_memory
  end

  getter? running = false
  getter memory : Memory
  getter error : Error? = nil
  property input_chan = Channel(Int32).new
  property output_chan = Channel(Int32).new

  record Context,
    mem : Memory,
    ip : Int32

  alias InstructionHandler = (Memory, Int32, OpcodeField) -> (Error | Int32)
  @instructions : Hash(Int32, InstructionHandler)

  def initialize(@memory)
    @ip = 0
    @instructions = gather_instructions
  end

  def gather_instructions
    all_instr = {} of Int32 => InstructionHandler
    {% for op_def in @type.methods.select { |m| !!m.annotation(Opcode) } %}
      {% ann = op_def.annotation(Opcode) %}
      {% opcode = ann.args.first %}
      {% arg_mode_specs = ann[:arg_modes] || ([] of _) %}
      {% arg_count = arg_mode_specs.size %}

      {% if arg_count != op_def.args.size %}
        {% ann.raise "Number of arguments mismatch between annotation and def (#{arg_count} != #{op_def.args.size})" %}
      {% end %}

      # ---- For opcode {{ opcode }}

      instr_handler = InstructionHandler.new do |mem, ip, opcode_field|
        instr_decoder = ArgsDecoder({{ arg_count }}).new(mem, ip)

        arg_modes =
          {% if arg_count == 0 %}
            Tuple.new # empty tuple
          {% else %}
            {
              {% for idx in 0...arg_count %}
                opcode_field.mode_for_arg({{ idx }}, mode_spec: {{ arg_mode_specs[idx] }}),
              {% end %}
            }
          {% end %}

        decoded_args = err_guard instr_decoder.parse_args(*arg_modes)
        err_guard({{ op_def.name }}(*decoded_args))

        instr_decoder.new_ip
      end

      all_instr[{{ opcode }}] = instr_handler
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

    opcode_field = OpcodeField.new err_guard @memory[@ip]
    opcode = opcode_field.opcode
    @ip += 1

    if instr_handler = @instructions[opcode]?
      nb_args = err_guard instr_handler.call(@memory, @ip, opcode_field) # FIXME: give some args?
      @ip += 1 + nb_args # opcode + args
    else
      puts "/!\\/!\\ WARNING: Unknown opcode #{opcode} at IP:#{@ip}, skipping"
      @ip += 1
    end
  end

  enum ArgMode # FIXME: rename?
    Dynamic
    Position
    Immediate

    # shortcuts

    Dyn = Dynamic
    Addr = Position
  end

  struct ArgsDecoder(NbArgs)
    include ErrorGuardian

    def initialize(@mem : Memory, @ip : Int32)
    end

    def new_ip
      @ip
    end

    # TODO: doc!
    def parse_args(*arg_modes)
      {% if NbArgs == 0 %}
        Tuple.new
      {% else %}
        {% for idx in 0...NbArgs %}
          case arg_modes[{{ idx }}]
          when .position?
            %arg_addr{idx} = err_guard @mem[@ip + {{ idx }}]
            %arg{idx} = err_guard @mem[%arg_addr{idx}]
          when .immediate?
            %arg{idx} = err_guard @mem[@ip + {{ idx }}]
          else raise "BUG: unreachable!"
          end
        {% end %}

        {
          {% for idx in 0...NbArgs %}
            %arg{idx},
          {% end %}
        }
      {% end %}
    end
  end

  struct OpcodeField # FIXME: rename?
    def initialize(@raw_opcode : Int32)
    end

    def opcode
      @raw_opcode % 100 # extract first 2 digit
    end

    def mode_for_arg(arg_idx, mode_spec : ArgMode)
      mode = (@raw_opcode // (10 ** arg_idx) % 10)
      mode == 1 ? ArgMode::Immediate : ArgMode::Position
    end
  end

  # ABCDE
  #  1002
  #
  # DE - two-digit opcode,      02 == opcode 2
  #  C - mode of 1st parameter,  0 == position mode
  #  B - mode of 2nd parameter,  1 == immediate mode
  #  A - mode of 3rd parameter,  0 == position mode,
  #                                   omitted due to being a leading zero
  def parse_opcode
  end

  def draft_do_instruction
    instr_decoder = ArgsDecoder(3).new(@memory, @ip)

    opcode, arg_modes = err_guard instr_decoder.read_opcode

    decoded_args = instr_decoder.read_args(arg_modes)
    op_some_instr(*decoded_args)
  end

  def instr_read_args(*arg_modes : *ArgMode)
    opcode_field = err_guard @memory[@ip]
    @ip += 1

    opcode = opcode_field % 100 # extract first 2 digit

    args = arg_modes.map_with_index do |arg_mode, idx|
      case arg_mode
      when :addr
        # read the addr at @ip + idx
      when :dyn
        # ask the mode to the opcode's flags
        # when :addr
        #   read the addr at @ip + idx
        # when :immediate
        #   read the value from memory
        # end
      end
    end

    # OR yield ? so we can return an error in case of mem error (for example)
    {opcode, {arg1, ar2, arg3}}
  end

  @[Opcode(1, arg_modes: [:dyn, :dyn, :addr])]
  def op_add(val1, val2, to_addr)
    # from_addr1 = err_guard @memory[@ip + 1]
    # from_addr2 = err_guard @memory[@ip + 2]
    to_addr = err_guard @memory[@ip + 3]
    # result = err_guard(@memory[from_addr1]) + err_guard(@memory[from_addr2])

    __debug "[IP:#{@ip}] mem[#{to_addr}] = #{val1} + #{val2}"

    err_guard @memory[to_addr] = val1 + val2

    # @ip += 4 # Should be done by the caller
  end

  @[Opcode(2, arg_modes: [:dyn, :dyn, :addr])]
  def op_mul(from_addr1, from_addr2, to_addr)
    from_addr1 = err_guard @memory[@ip + 1]
    from_addr2 = err_guard @memory[@ip + 2]
    to_addr = err_guard @memory[@ip + 3]
    result = err_guard(@memory[from_addr1]) * err_guard(@memory[from_addr2])

    __debug "[IP:#{@ip}] Opcode mul : mem[#{to_addr}] <- mem[#{from_addr1}] * mem[#{from_addr2}]"

    err_guard @memory[to_addr] = result
  end

  @[Opcode(3, arg_modes: [:addr])]
  def op_input(to_addr)
  end

  @[Opcode(4, arg_modes: [:dyn])]
  def op_output(from_addr)
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
end
