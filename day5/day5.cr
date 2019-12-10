require "../common/intcode_vm"

INPUT = {{ read_file "#{__DIR__}/input" }}.strip

vm = IntCodeVM.from_program INPUT
vm.debug = true

spawn do
  vm.inputs_channel.send 1
end

spawn do
  while val = vm.outputs_channel.receive
    puts "OUTPUT: #{val}"
  end
end

puts "Running VM"
vm.run
