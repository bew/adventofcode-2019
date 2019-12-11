# Use a VM module?

require "./utils"
require "./intcode_vm/*"

module IntCodeVM
  abstract struct Error; end
  record InvalidMemoryAccess(T) < Error, idx : T
end

class IntCodeVM::Core
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
    alias ProcT = (OpcodeFlags) -> (Error | Int32)

    getter opcode : Int32
    getter name : String
    @handler : ProcT

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

  private def __fetch_arg(idx, opcode_flags, param_name)
    # __debug "Arg index #{idx}"

    mode = opcode_flags.mode_for_arg(idx)
    # __debug "  mode: #{mode}"

    case mode
    when .address?
      if /addr/.match(param_name)
        value = err_guard @memory[@ip + idx]
        # __debug "  raw_addr: #{value}"
      else
        arg_addr = err_guard @memory[@ip + idx]
        value = err_guard @memory[arg_addr]
        # __debug "  addr: #{arg_addr} | resolved_addr: #{value}"
      end
    when .immediate?
      value = err_guard @memory[@ip + idx]
      # __debug "  immediate: #{value}"

    else raise "BUG: Unknown ArgMode: #{mode}"
    end

    value
  end

  private def gather_instructions
    {% begin %}
      all_instr = {} of Int32 => Instruction
      {% all_methods = @type.methods %}
      {% for ancestor in @type.ancestors %}
        {% all_methods = all_methods + ancestor.methods %}
      {% end %}
      # note: would be nice to have a `@type.all_methods`......
      {% opcode_methods = all_methods.select { |m| !!m.annotation(Opcode) } %}

      {% for def_node in opcode_methods %}
        {% ann = def_node.annotation(Opcode) %}
        {% opcode = ann.args.first %}
        {% arg_count = def_node.args.size %}
        {% instr_name = ann.args[1].id.stringify %}

        # ---- BEGIN opcode {{ opcode }} ({{ instr_name }})
        handler_proc = Instruction::ProcT.new do |opcode_flags|

          # __debug "--- fetching args for opcode {{ instr_name.id }}"

          decoded_args = Tuple.new(
            {% for idx in 0...arg_count %}
              err_guard(__fetch_arg({{ idx }}, opcode_flags, param_name: ({{ def_node.args[idx].name.stringify }}))),
          {% end %}
          )

          err_guard({{ def_node.name }}(*decoded_args))

          @ip + {{ arg_count }}
        end

        instr = Instruction.new({{ opcode }}, {{ instr_name }}, handler_proc)
        all_instr[{{ opcode }}] = instr
        # ---- END opcode {{ opcode }} ({{ instr_name }})
      {% end %}

      all_instr
    {% end %}
  end

  def run
    @running = true
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

    __debug
    __debug "/=> partial mem (from IP:#{@ip}): #{@memory[@ip..@ip + 6]}"

    opcode, flags = OpcodeFlags.from_opcode_field(err_guard @memory[@ip])
    @ip += 1

    if instr = @instructions[opcode]?
      @ip = err_guard instr.call(flags)
    else
      puts "/!\\ WARNING: Unknown opcode #{opcode} at IP:#{@ip}, skipping"
      @ip += 1
    end
  end

  enum ArgMode # FIXME: rename? move? ArgKind ?
    Address # `Position` in the challenge's statement
    Immediate

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
  struct OpcodeFlags # FIXME: rename?
    def self.from_opcode_field(opcode_field)
      opcode = opcode_field % 100 # extract first 2 digit
      flags = opcode_field // 100

      {opcode, new(flags)}
    end

    private def initialize(@arg_flags : Int32)
    end

    def mode_for_arg(arg_idx)
      mode = (@arg_flags // (10 ** arg_idx) % 10)
      case mode
      when 0
        ArgMode::Address
      when 1
        ArgMode::Immediate
      else
        raise "BUG: Unknown arg flag #{mode}"
      end
    end
  end

  # Returns the result of the program
  def result
    @memory[0]
  end
end

class IntCodeVM::Day2 < IntCodeVM::Core
  @[Opcode(1, :add)]
  def op_add(val1, val2, to_addr)
    __debug "[IP:#{@ip}] mem[#{to_addr}] = #{val1} + #{val2}"

    err_guard @memory[to_addr] = val1 + val2
  end

  @[Opcode(2, :mul)]
  def op_mul(val1, val2, to_addr)
    __debug "[IP:#{@ip}] Opcode mul : mem[#{to_addr}] = #{val1} * #{val2}"

    err_guard @memory[to_addr] = val1 * val2
  end

  @[Opcode(99, :quit)]
  def op_quit
    __debug "[IP:#{@ip}] Opcode quit!"
    @running = false
  end
end

class IntCodeVM::Day5 < IntCodeVM::Day2
  @[Opcode(3, :input)]
  def op_input(to_addr)
    value = inputs_channel.receive

    __debug "[IP:#{@ip}] Opcode input : mem[#{to_addr}] = input (got #{value})"

    err_guard @memory[to_addr] = value
  end

  @[Opcode(4, :output)]
  def op_output(value)
    __debug "[IP:#{@ip}] Opcode output : output << #{value}"
    outputs_channel.send value
    Fiber.yield # give a chance to the other end of the output channel to do something
  end
end
