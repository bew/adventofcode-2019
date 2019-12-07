INPUT = {{ read_file "./input" }}

def memory_from_str(str)
  str.split(',').map &.to_i
end

def run_computer(memory, restore)

  if restore
    puts "Restoring state before fire..."
    memory[1] = 12
    memory[2] = 2
  end

  # todo: protect memory access!!
  running = true
  ip = 0
  while running
    opcode = memory[ip]
    case opcode
    when 1
      from_addr1 = memory[ip + 1]
      from_addr2 = memory[ip + 2]
      to_addr = memory[ip + 3]
      result = memory[from_addr1] + memory[from_addr2]
      puts "[IP:#{ip}] Opcode add : mem[#{to_addr}] <- mem[#{from_addr1}] + mem[#{from_addr2}]"
      memory[to_addr] = result
      ip += 4
    when 2
      from_addr1 = memory[ip + 1]
      from_addr2 = memory[ip + 2]
      to_addr = memory[ip + 3]
      result = memory[from_addr1] * memory[from_addr2]
      puts "[IP:#{ip}] Opcode mul : mem[#{to_addr}] <- mem[#{from_addr1}] * mem[#{from_addr2}]"
      memory[to_addr] = result
      ip += 4
    when 99
      running = false
    end
  end

  memory[0]
end

def test_program(program, restore = false)
  memory = memory_from_str(program)
  puts "Memory before: #{memory}"
  result_value = run_computer(memory, restore)
  puts "Memory after: #{memory}"
  puts "Result: #{result_value}"
end

test_program "1,1,1,4,99,5,6,0,99"
puts
test_program INPUT, restore: true
