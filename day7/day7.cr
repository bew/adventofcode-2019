INPUT = {{ read_file "#{__DIR__}/input" }}

require "../common/intcode_vm"

macro setup_vm_pipe(vm1_var, vm2_var)
  spawn do
    puts "Link {{ vm1_var }} <-> {{ vm2_var }} started!" if debug
    while value = {{ vm1_var }}.outputs_channel.receive?
      puts "Link {{ vm1_var }} <-> {{ vm2_var }} : passing value #{value}" if debug
      {{ vm2_var }}.inputs_channel.send value
    end
    puts "Link {{ vm1_var }} <-> {{ vm2_var }} ended!" if debug
  end
end

alias PhaseSequence = Tuple(Int32, Int32, Int32, Int32, Int32)

def test_amplifier_chain(program, phase_setting_sequence : PhaseSequence, *, vm_debug = false, debug = false)
  #     +-------+  +-------+  +-------+  +-------+  +-------+
  # 0 ->| Amp A |->| Amp B |->| Amp C |->| Amp D |->| Amp E |-> (to thrusters)
  #     +-------+  +-------+  +-------+  +-------+  +-------+

  vm1 = IntCodeVM::Day5.from_program program, name: "Amp A"
  vm1.debug = vm_debug

  vm2 = IntCodeVM::Day5.from_program program, name: "Amp B"
  vm2.debug = vm_debug

  vm3 = IntCodeVM::Day5.from_program program, name: "Amp C"
  vm3.debug = vm_debug

  vm4 = IntCodeVM::Day5.from_program program, name: "Amp D"
  vm4.debug = vm_debug

  vm5 = IntCodeVM::Day5.from_program program, name: "Amp E"
  vm5.debug = vm_debug

  spawn do
    puts "Sending phase settings to all amplifiers.." if debug
    vm1.inputs_channel.send phase_setting_sequence[0]
    vm2.inputs_channel.send phase_setting_sequence[1]
    vm3.inputs_channel.send phase_setting_sequence[2]
    vm4.inputs_channel.send phase_setting_sequence[3]
    vm5.inputs_channel.send phase_setting_sequence[4]

    initial_input = 0
    puts "Sending initial input (#{initial_input}) to vm1" if debug
    vm1.inputs_channel.send initial_input
    puts "Initial input sent!" if debug
  end

  setup_vm_pipe vm1, vm2
  setup_vm_pipe vm2, vm3
  setup_vm_pipe vm3, vm4
  setup_vm_pipe vm4, vm5

  final_output_channel = Channel(Int32).new
  spawn do
    value = vm5.outputs_channel.receive
    final_output_channel.send(value)
  end

  spawn { vm1.run }
  spawn { vm2.run }
  spawn { vm3.run }
  spawn { vm4.run }
  spawn { vm5.run }

  final_output = final_output_channel.receive?

  Fiber.yield # let the VMs properly shutdown!

  final_output
end

def phase_sequence_to_tuple(sequence : String)
  PhaseSequence.from(sequence.split(',').map(&.to_i))
end

tests = {
  {
    program: "3,15,3,16,1002,16,10,16,1,16,15,15,4,15,99,0,0",
    expected_result: 43210,
    phase_sequence: phase_sequence_to_tuple "4,3,2,1,0"
  },
  {
    program: "3,23,3,24,1002,24,10,24,1002,23,-1,23,101,5,23,23,1,24,23,23,4,23,99,0,0",
    expected_result: 54321,
    phase_sequence: phase_sequence_to_tuple "0,1,2,3,4"
  },
  {
    program: "3,31,3,32,1002,32,10,32,1001,31,-2,31,1007,31,0,33,1002,33,7,33,1,33,31,31,1,32,31,31,4,31,99,0,0,0",
    expected_result: 65210,
    phase_sequence: phase_sequence_to_tuple "1,0,4,3,2"
  },
}

# --- tests

puts
puts "--- Tests with everything known to verify the amplifiers chain setup"

tests.each do |test|
  puts
  puts test[:program]
  puts
  result = test_amplifier_chain(test[:program], test[:phase_sequence])
  if result == test[:expected_result]
    puts "Success!!!!! result: #{result}"
  else
    puts "!!! Failed... result: #{result} | expected: #{test[:expected_result]}"
  end
end

def part1_each_phase_sequence(range)
  range.to_a.each_permutation(size: 5, reuse: true) do |permu|
    yield PhaseSequence.from permu
  end
end

def part1(program)
  # brute force the phase sequence

  puts
  puts program
  puts

  max_output = nil
  phase_sequence_for_max_output = {0, 0, 0, 0, 0}

  part1_each_phase_sequence(0..4) do |phase_sequence|

    output = test_amplifier_chain(program, phase_sequence)
    if output.nil?
      puts "!!! There was an error using the sequence #{phase_sequence}, skipping..."
      next
    end

    if max_output.nil? || output > max_output
      # puts "--> output (#{output}) > max_output (#{max_output}) : phase_sequence is #{phase_sequence}"

      max_output = output
      phase_sequence_for_max_output = phase_sequence
    end
  end

  {max_output.not_nil!, phase_sequence_for_max_output}
end

puts
puts "--- Tests using brute force to find the phase sequence"

test = tests[0]
result = part1 test[:program]
puts "Result for test: #{result}"

puts
puts "--- Part1"

result = part1 INPUT
puts "Result for test: #{result}"
puts "Should be 567045"
