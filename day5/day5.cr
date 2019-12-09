require "../common/intcode_vm"

INPUT = {{ read_file "#{__DIR__}/input" }}.strip

vm = IntCodeVM.from_program INPUT


