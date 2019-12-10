# Use a VM module?

abstract struct Error; end
record InvalidMemoryAccess(T) < Error, idx : T

class Memory
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
      if debug?
        {% for arg in args %}
          print "DEBUG: "
          p!({{ arg }})
        {% end %}
      end
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
  property inputs_channel = Channel(Int32).new
  property outputs_channel = Channel(Int32).new

  class State # TODO: use this!
    property? running = false
    getter? memory : Memory
    getter ip : Int32
    getter error : Error?
    getter io : IOChannels

    record IOChannels,
      inputs_channel : Channel(Int32),
      outputs_channel : Channel(Int32)

    def initialize(@memory, in_channel, out_channel)
      @ip = 0
      @error = nil
      @io = IOChannels.new(in_channel, out_channel)
    end

    def self.new(memory)
      new memory, Channel(Int32).new, Channel(Int32).new
    end
  end

  struct Instruction
    alias Proc = (Memory, Int32, OpcodeField) -> (Error | Int32)

    getter opcode : Int32
    getter name : String
    @handler : Proc

    def initialize(@opcode, @name, @handler)
    end

    def call(*args)
      @handler.call *args
    end
  end

  @instructions : Hash(Int32, Instruction)

  def initialize(@memory)
    @ip = 0
    @instructions = gather_instructions
  end

  private macro __fetch_args(opcode_field_var, *arg_mode_specs)
    {% arg_count = arg_mode_specs.size %}

    __debug
    __debug "--- fetching args...."

    {% for idx in 0...arg_count %}
      __debug "Arg index {{idx}}"

      %arg_mode_spec{idx} = ArgModeSpec.new({{ arg_mode_specs[idx] }})

      __debug "  arg_mode_specs: #{%arg_mode_spec{idx}}"

      # case %arg_mode_spec{idx}
      # when .opcode_mode?
        %mode{idx} = {{ opcode_field_var }}.mode_for_arg({{ idx }})
      # when .raw_addr?
      #   %mode{idx} = ArgMode::Addr
      # else
      #   raise "BUG: Unknown ArgModeSpec: #{ %arg_mode_spec{idx} }"
      # end

      __debug "  mode: #{%mode{idx}}"

      case %mode{idx}
      when .address?
        if %arg_mode_spec{idx}.opcode_mode?
          %arg_addr{idx} = err_guard @memory[@ip + {{ idx }}]
          %arg{idx} = err_guard @memory[%arg_addr{idx}]
          __debug "  addr: #{%arg_addr{idx}} | resolved_addr: #{%arg{idx}}"
        else
          %arg{idx} = err_guard @memory[@ip + {{ idx }}]
          __debug "  raw_addr: #{%arg{idx}}"
        end

        # %arg_addr{idx} = err_guard @memory[@ip + {{ idx }}]
        # %arg{idx} = err_guard @memory[%arg_addr{idx}]
      when .immediate?
        %arg{idx} = err_guard @memory[@ip + {{ idx }}]
        __debug "  immediate: #{%arg{idx}}"

      else raise "BUG: Unknown ArgMode: #{%mode{idx}}"
      end

    {% end %}

    Tuple.new(
      {% for idx in 0...arg_count %}
        %arg{idx},
      {% end %}
    )
  end

  private def gather_instructions
    all_instr = {} of Int32 => Instruction
    {% for op_def in @type.methods.select { |m| !!m.annotation(Opcode) } %}
      {% ann = op_def.annotation(Opcode) %}
      {% opcode = ann.args.first %}
      {% arg_mode_specs = ann[:arg_modes] || ([] of Nil) %}
      {% arg_count = arg_mode_specs.size %}

      {% if arg_count != op_def.args.size %}
        {% ann.raise "Number of arguments mismatch between annotation and def (#{arg_count} != #{op_def.args.size})" %}
      {% end %}

      # ---- For opcode {{ opcode }}

      handler_proc = Instruction::Proc.new do |mem, ip, opcode_field|
        args_or_err = __fetch_args(opcode_field, {{ arg_mode_specs.splat }})
        decoded_args = err_guard args_or_err
        __debug! decoded_args
        err_guard({{ op_def.name }}(*decoded_args))

        ip + {{ arg_count }}
      end

      instr = Instruction.new({{ opcode }}, {{ op_def.name.stringify }}, handler_proc)
      all_instr[{{ opcode }}] = instr
    {% end %}

    all_instr
  end

  def run
    @running = true
    __debug "INIT partial mem: #{@memory[..15]}"
    while @running
      err = exec_next_instruction
      if err.is_a? Error
        stop_vm(err)
      end
    end
    stop_vm

    @error.nil?
  end

  def stop_vm(error : Error? = nil)
    @running = false
    @error = error
    @inputs_channel.close
    @outputs_channel.close
  end

  def exec_next_instruction
    return false unless @running

    opcode_field = OpcodeField.new err_guard @memory[@ip]
    opcode = opcode_field.opcode
    @ip += 1

    if instr = @instructions[opcode]?
      @ip = err_guard instr.call(@memory, @ip, opcode_field)
      __debug " \\=> partial mem: #{@memory[..15]}"
    else
      puts "/!\\ WARNING: Unknown opcode #{opcode} at IP:#{@ip}, skipping"
      @ip += 1
    end
  end

  enum ArgModeSpec # FIXME: rename? move?
    OpcodeMode

    RawAddr

    OutAddr = RawAddr

    def self.new(mode : self)
      mode
    end
  end

  enum ArgMode # FIXME: rename? move? ArgKind ?
    Address # `Position` in the challenge's statement
    Immediate

    Addr = Address

    def self.new(mode : self)
      mode
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
  struct OpcodeField # FIXME: rename?
    getter opcode : Int32
    @arg_mode_flags : Int32

    def initialize(raw_opcode : Int32)
      @opcode = raw_opcode % 100 # extract first 2 digit
      @arg_mode_flags = raw_opcode // 100
    end

    def mode_for_arg(arg_idx)
      mode = (@arg_mode_flags // (10 ** arg_idx) % 10)
      mode == 1 ? ArgMode::Immediate : ArgMode::Address
    end
  end

  @[Opcode(1, arg_modes: [:opcode_mode, :opcode_mode, :out_addr])]
  def op_add(val1, val2, to_addr)
    __debug "[IP:#{@ip}] mem[#{to_addr}] = #{val1} + #{val2}"

    err_guard @memory[to_addr] = val1 + val2
  end

  @[Opcode(2, arg_modes: [:opcode_mode, :opcode_mode, :out_addr])]
  def op_mul(val1, val2, to_addr)
    __debug "[IP:#{@ip}] Opcode mul : mem[#{to_addr}] = #{val1} * #{val2}"

    err_guard @memory[to_addr] = val1 * val2
  end

  @[Opcode(3, arg_modes: [:out_addr])]
  def op_input(to_addr)
    value = inputs_channel.receive

    __debug "[IP:#{@ip}] Opcode input : mem[#{to_addr}] = input (got #{value})"

    err_guard @memory[to_addr] = value
  end

  @[Opcode(4, arg_modes: [:out_addr])]
  def op_output(from_addr)
    value = err_guard @memory[from_addr]

    __debug "[IP:#{@ip}] Opcode output : output << mem[#{from_addr}] (got #{value})"
    outputs_channel.send value
    Fiber.yield # give a chance to the other end of the output channel to do something
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
