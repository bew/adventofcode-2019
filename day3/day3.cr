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

  def advance_to(target_x, target_y)
    base_x, base_y = @current_x, @current_y
    # save the real target coords
    real_target_x, real_target_y = target_x, target_y

    # keep base < target because it is required for crystal's ranges
    if target_x < base_x
      base_x, target_x = target_x, base_x
    end
    if target_y < base_y
      base_y, target_y = target_y, base_y
    end

    (base_x..target_x).each do |x|
      occupied_cells << {x, @current_y}
    end

    (base_y..target_y).each do |y|
      occupied_cells << {@current_x, y}
    end

    @current_x, @current_y = real_target_x, real_target_y
  end
end

def dist_to_closest_intersection(wire1, wire2)
  common_cells = wire1.occupied_cells & wire2.occupied_cells
  common_cells.delete({0, 0}) # pos {0, 0} does not count
  distances_to_common_cells = common_cells.map { |(x, y)| x.abs + y.abs }

  unless distances_to_common_cells.size >= 1
    puts "ERROR: No intersection found between the wires"
    return 0
  end

  distances_to_common_cells.sort.first
end

# -------------------------------------

def part1_test_instructions(input, assert_result = nil)
  input_lines = input.strip.lines

  wire1 = Wire.from_instructions input_lines[0]
  wire2 = Wire.from_instructions input_lines[1]

  result = dist_to_closest_intersection(wire1, wire2)

  if assert_result
    if result == assert_result
      puts "OK! Distance #{result} is right for this input"
    else
      puts "!!! Got distance #{result} but expected #{assert_result}"
    end
  end
  result
end

test_input1 = %(
  R8,U5,L5,D3
  U7,R6,D4,L4
) # distance 6

test_input2 = %(
  R75,D30,R83,U83,L12,D49,R71,U7,L72
  U62,R66,U55,R34,D71,R55,D58,R83
) # distance 159

test_input3 = %(
  R98,U47,R26,D63,R33,U87,L62,D20,R33,U53,R51
  U98,R91,D20,R16,D67,R40,U7,R15,U6,R7
) # distance 135

part1_test_instructions(test_input1, assert_result: 6)

part1_test_instructions(test_input2, assert_result: 159)
part1_test_instructions(test_input3, assert_result: 135)

result = part1_test_instructions(INPUT)
puts "Part1 result: #{result}" # Should be 386
puts

# -------------------------------------


