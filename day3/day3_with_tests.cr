# Wire, part1 & part2 are copied from ./day3.cr
# I can't require that file since it would run the top-level code, and I want to
# be able to run that file on its own...

INPUT = {{ read_file "#{__DIR__}/input" }}

class Wire
  def self.from_instructions(instructions_str)
    instructions = instructions_str.split(',').map!(&.strip)

    wire = new
    instructions.each do |instr|
      wire.do_instruction instr
    end
    wire
  end

  getter occupied_cells = Set({Int32, Int32}).new
  @current_x = 0
  @current_y = 0

  OFFSETS_BY_DIRECTIONS = {
    'U' => { 0,  1},
    'D' => { 0, -1},
    'R' => { 1,  0},
    'L' => {-1,  0},
  }

  def do_instruction(instr)
    direction_chr, move_count = instr[0], instr[1..].to_i

    offset_x, offset_y = OFFSETS_BY_DIRECTIONS[direction_chr]
    move_count.times do
      @current_x, @current_y = @current_x + offset_x, @current_y + offset_y
      occupied_cells << {@current_x, @current_y}
    end
  end

  def distance_to_cell(x, y)
    # Here we use a property of Crystal's Set, where the values are stored in
    # order of insertion. And since a Set does not duplicate values, the first
    # time we find a given position we can be sure it is the first time the wire
    # enters this cell.
    cells = occupied_cells.to_a
    cells.delete({0, 0}) # pos {0, 0} does not count in the calculation
    pos_idx = cells.index({x, y}).not_nil!
    pos_idx + 1
  end

  def common_cells_with(wire : self)
    common_cells = occupied_cells & wire.occupied_cells
    common_cells.delete({0, 0}) # pos {0, 0} does not count

    if common_cells.size == 0
      puts "!!! No common cells between these wires"
      return nil
    end

    common_cells
  end
end

def part1(wire1, wire2)
  common_cells = wire1.common_cells_with(wire2) || return nil
  distances_to_common_cells = common_cells.map { |(x, y)| x.abs + y.abs }
  distances_to_common_cells.sort.first
end

def part2(wire1, wire2)
  common_cells = wire1.common_cells_with(wire2) || return nil
  common_cells.map do |cell_pos|
    wire1.distance_to_cell(*cell_pos) + wire2.distance_to_cell(*cell_pos)
  end.min
end

# -------------------------------------

def wires_from_input(input)
  input_lines = input.lines
  wire1 = Wire.from_instructions(input_lines[0])
  wire2 = Wire.from_instructions(input_lines[1])
  {wire1, wire2}
end

def assert_result(value, *, expected)
  if value == expected
    puts "OK! Distance #{value} is right for this input"
  else
    puts "!!! Got distance #{value} but expected #{expected}"
  end
end

tests = {
  {
    input: %(
      R8,U5,L5,D3
      U7,R6,D4,L4
    ).strip,
    part1: 6,
    part2: 30,
  },
  {
    input: %(
      R75,D30,R83,U83,L12,D49,R71,U7,L72
      U62,R66,U55,R34,D71,R55,D58,R83
    ).strip,
    part1: 159,
    part2: 610,
  },
  {
    input: %(
      R98,U47,R26,D63,R33,U87,L62,D20,R33,U53,R51
      U98,R91,D20,R16,D67,R40,U7,R15,U6,R7
    ).strip,
    part1: 135,
    part2: 410,
  },
}

# -------------------------------------

puts "----- Part 1"

tests.each do |test|
  result = part1(*wires_from_input(test[:input]))
  assert_result result, expected: test[:part1]
end

result = part1(*wires_from_input(INPUT))
puts "Part1 result: #{result}" # Should be 386

puts
puts "----- Part 2"

tests.each do |test|
  result = part2(*wires_from_input(test[:input]))
  assert_result result, expected: test[:part2]
end

result = part2(*wires_from_input(INPUT))
puts "Part2 result: #{result}" # Should be 6484
