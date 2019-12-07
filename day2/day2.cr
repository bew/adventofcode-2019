INPUT = {{ read_file "#{__DIR__}/input" }}

class Computer
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

  def self.from_program(prog_str)
    raw_memory = prog_str.split(',').map &.to_i
    new Memory.new raw_memory
  end

  property? debug = false
  getter? running = false
  getter memory : Memory
  getter error : Error? = nil

  def initialize(@memory)
    @ip = 0
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

    case opcode = guard @memory[@ip]
    when 1
      from_addr1 = guard @memory[@ip + 1]
      from_addr2 = guard @memory[@ip + 2]
      to_addr = guard @memory[@ip + 3]
      result = guard(@memory[from_addr1]) + guard(@memory[from_addr2])

      __debug "[IP:#{@ip}] Opcode add : mem[#{to_addr}] <- mem[#{from_addr1}] + mem[#{from_addr2}]"

      guard @memory[to_addr] = result
      @ip += 4

    when 2
      from_addr1 = guard @memory[@ip + 1]
      from_addr2 = guard @memory[@ip + 2]
      to_addr = guard @memory[@ip + 3]
      result = guard(@memory[from_addr1]) * guard(@memory[from_addr2])

      __debug "[IP:#{@ip}] Opcode mul : mem[#{to_addr}] <- mem[#{from_addr1}] * mem[#{from_addr2}]"

      guard @memory[to_addr] = result
      @ip += 4

    when 99
      __debug "[IP:#{@ip}] Opcode quit!"
      @running = false

    else
      puts "/!\\/!\\ WARNING: Unknown opcode #{opcode} at IP:#{@ip}, skipping"
      @ip += 1

    end
  end

  # Returns the result of the program
  def result
    @memory[0]
  end

  private def __debug(message)
    return unless debug?
    puts "DEBUG: #{message}"
  end

  # Returns the error from the current method if the result of *node* is an error.
  private macro guard(node)
    %value = ({{ node }})
    return %value if %value.is_a?(Error)
    %value
  end
end

# ----------------------------

def part1_run_program(program, restore = false, debug = false)
  puts "Program: #{program}" if debug
  computer = Computer.from_program program
  computer.debug = debug

  if restore
    puts "Restoring state before fire..."
    computer.memory[1] = 12
    computer.memory[2] = 2
  end

  unless computer.run
    puts "!!! Program failed with error: #{computer.error}"
  end
  puts "Memory dump: #{computer.memory}" if debug
  computer.result
end

puts "---- Given test program"
part1_run_program "1,1,1,4,99,5,6,0,99", debug: true
puts

puts "---- Test invalid memory access"
part1_run_program "1,1,1,999999,99"
puts

puts "---- Test unknown opcode"
part1_run_program "1,1,1,0,42,99", debug: true
puts

puts "---- Test without end"
part1_run_program "1,0,0,0"
puts

puts "---- Part1"
result = part1_run_program INPUT, restore: true, debug: false
# Result should be 2782414
puts "Part1 result: #{result}"

puts
puts "=" * 42
puts

# ----------------------------

def part2_try_noun_verb(program, noun, verb)
  computer = Computer.from_program program
  # computer.debug = true
  computer.memory[1] = noun
  computer.memory[2] = verb

  unless computer.run
    puts "!! Pair #{ {noun, verb} } failed with error: #{computer.error}"
  end

  computer.result
end

def part2
  target_output = 19690720
  noun = verb = 0

  (0..99).each do |noun_test|
    (0..99).each do |verb_test|
      result = part2_try_noun_verb(INPUT, noun_test, verb_test)
      if result == target_output
        noun = noun_test
        verb = verb_test
      end
    end
  end


  puts "Part2 result is: #{100 * noun + verb} (#{ {noun: noun, verb: verb} })"
  # Result should be 9820
end

part2
