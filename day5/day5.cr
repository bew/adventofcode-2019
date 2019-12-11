require "../common/intcode_vm"

INPUT_PROGRAM = {{ read_file "#{__DIR__}/input" }}.strip

def test_program(program, input, debug = false)
  puts program if debug

  vm = IntCodeVM::Day5.from_program program
  vm.debug = debug

  spawn do
    vm.inputs_channel.send input
  end

  final_output_channel = Channel(Array(Int32)).new
  spawn do
    output_buffer = [] of Int32
    while value = vm.outputs_channel.receive?
      output_buffer << value
    end
    final_output_channel.send output_buffer
  end

  unless vm.run
    puts "!!! Program failed with error: #{vm.error}"
  end

  puts "--- Gathered output:"
  final_output = final_output_channel.receive
  puts "each: #{final_output}"
  puts "joined: #{final_output.join}"
end

def part1(program, debug = false)
  test_program(program, input: 1, debug: debug)
end

def part2(program, debug = false)
  test_program(program, input: 5, debug: debug)
end

puts
puts "--------------- REAL PROGRAM ----------------"
puts

puts "---- Part1"
part1 INPUT_PROGRAM
puts "Should be 13818007"

puts
puts "--- various tests"
puts
test_program "3,9,8,9,10,9,4,9,99,-1,8", input: 8
puts "Should be 1"
puts
test_program "3,9,7,9,10,9,4,9,99,-1,8", input: 3
puts "Should be 1"
puts
test_program "3,3,1108,-1,8,3,4,3,99", input: 8
puts "Should be 1"
puts
test_program "3,3,1107,-1,8,3,4,3,99", input: 3
puts "Should be 1"
puts
test_program "3,12,6,12,15,1,13,14,13,4,13,99,-1,0,1,9", input: 0
puts "Should be 0"
puts
test_program "3,3,1105,-1,9,1101,0,0,12,4,12,99,1", input: 0
puts "Should be 0"

# The below example program uses an input instruction to ask for a single number.
# The program will then output 999 if the input value is below 8, output 1000 if the
# input value is equal to 8, or output 1001 if the input value is greater than 8.
larger_example = %(
  3,21,1008,21,8,20,1005,20,22,107,8,21,20,1006,20,31,1106,0,36,98,0,0,1002,21,125,20,4,20,1105,1,46,104,999,1105,1,46,1101,1000,1,20,4,20,1105,1,46,98,99
).strip
test_program larger_example, input: 3
puts "Should be 999"
puts
test_program larger_example, input: 8
puts "Should be 1000"
puts
test_program larger_example, input: 42
puts "Should be 1001"


puts
puts "---- Part2"
part2 INPUT_PROGRAM
puts "Should be 3176266"
