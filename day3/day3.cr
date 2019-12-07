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

  def do_instruction(instr)
    direction_chr, value = instr[0], instr[1..].to_i
    case direction_chr
    when 'U'
      advance_to(@current_x, @current_y + value)
    when 'D'
      advance_to(@current_x, @current_y - value)
    when 'R'
      advance_to(@current_x + value, @current_y)
    when 'L'
      advance_to(@current_x - value, @current_y)
    end
  end

  # TODO: This should probably be in the stdlib!
  private struct EmptyIterator(T)
    include Iterator(T)

    def next
      stop
    end
  end

  private def iterator_for_advance(base, target) : Iterator(Int32)
    if base < target
      base.upto(target)
    elsif base > target
      base.downto(target)
    else
      return EmptyIterator(Int32).new
    end
  end

  def advance_to(target_x, target_y)
    base_x, base_y = @current_x, @current_y

    iterator_x = iterator_for_advance(base_x, target_x)
    iterator_y = iterator_for_advance(base_y, target_y)

    iterator_x.each do |x|
      occupied_cells << {x, @current_y}
    end

    iterator_y.each do |y|
      occupied_cells << {@current_x, y}
    end

    @current_x, @current_y = target_x, target_y
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
end

# -------------------------------------

def parse_then_do_then_check(input, assert_result = nil)
  input_lines = input.lines

  wire1 = Wire.from_instructions input_lines[0]
  wire2 = Wire.from_instructions input_lines[1]

  result = yield wire1, wire2

  if assert_result
    if result == assert_result
      puts "OK! Distance #{result} is right for this input"
    else
      puts "!!! Got distance #{result} but expected #{assert_result}"
    end
  end

  result
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
# Part 1-2 logic

puts "----- Part 1"

def dist_to_closest_intersection(wire1, wire2)
  common_cells = wire1.occupied_cells & wire2.occupied_cells
  common_cells.delete({0, 0}) # pos {0, 0} does not count
  distances_to_common_cells = common_cells.map { |(x, y)| x.abs + y.abs }

  unless distances_to_common_cells.size >= 1
    puts "ERROR: No intersection found between the wires"
    return nil
  end

  distances_to_common_cells.sort.first
end

def part1(input, assert_result = nil)
  parse_then_do_then_check(input, assert_result) do |wire1, wire2|
    dist_to_closest_intersection(wire1, wire2)
  end
end

tests.each do |test|
  part1(test[:input], assert_result: test[:part1])
end

result = part1(INPUT)
puts "Part1 result: #{result}" # Should be 386

# -------------------------------------
puts
puts "----- Part 2"

def part2_do_the_thing(wire1, wire2)
  common_cells = wire1.occupied_cells & wire2.occupied_cells
  common_cells.delete({0, 0}) # pos {0, 0} does not count

  common_cells.map do |cell_pos|
    wire1.distance_to_cell(*cell_pos) + wire2.distance_to_cell(*cell_pos)
  end.min
end

def part2(input, assert_result = nil)
  parse_then_do_then_check(input, assert_result) do |wire1, wire2|
    part2_do_the_thing(wire1, wire2)
  end
end

tests.each do |test|
  part2(test[:input], assert_result: test[:part2])
end

result = part2(INPUT)
puts "Part2 result: #{result}" # Should be 6484
