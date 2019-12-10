require "../common/intcode_vm"

INPUT = {{ read_file "#{__DIR__}/input" }}.strip

def test_program(input)
  vm = IntCodeVM.from_program input
  vm.debug = true

  spawn do
    vm.inputs_channel.send 1
  end

  final_output_channel = Channel(Array(Int32)).new
  spawn do
    output_buffer = [] of Int32
    while value = vm.outputs_channel.receive?
      output_buffer << value
    end
    final_output_channel.send output_buffer
  end

  puts "--- Running VM"
  unless vm.run
    puts "!!! Program failed with error: #{vm.error}"
  end

  puts
  puts "--- Gathered output:"
  final_output = final_output_channel.receive
  puts "each: #{final_output}"
  puts "joined: #{final_output.join}"
end

# test_program "3,0,4,0,99"

puts
puts "--------------- REAL PROGRAM ----------------"
puts

test_program INPUT
