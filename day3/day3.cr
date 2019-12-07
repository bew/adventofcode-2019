INPUT = {{ read_file "#{__DIR__}/input" }}

# debug helper

module G
  class_property? debug = false
end

def __debug(*args)
  return unless G.debug?
  args.each do |arg|
    print "DEBUG: "
    puts arg
  end
  puts if args.size == 0
end
macro __debug!(*args)
  {% for arg in args %}
    if G.debug?
      print "DEBUG: "
      p!({{ arg }})
    end
  {% end %}
end

# puzzle!

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
      __debug "UP    | Y + #{value}"
      advance_to(@current_x, @current_y + value)
    when 'D'
      __debug "DOWN  | Y - #{value}"
      advance_to(@current_x, @current_y - value)
    when 'R'
      __debug "RIGHT | X + #{value}"
      advance_to(@current_x + value, @current_y)
    when 'L'
      __debug "LEFT  | X - #{value}"
      advance_to(@current_x - value, @current_y)
    end
  end

  def advance_to(target_x, target_y)
    base_x, base_y = @current_x, @current_y
    # save the real target coords
    real_target_x, real_target_y = target_x, target_y

    __debug "X: #{base_x} -> #{target_x}" if base_x != target_x
    __debug "Y: #{base_y} -> #{target_y}" if base_y != target_y

    # keep base < target because it is required by crystal's ranges
    if target_x < base_x
      base_x, target_x = target_x, base_x
    end
    if target_y < base_y
      base_y, target_y = target_y, base_y
    end

    __debug "after flip X: #{base_x} -> #{target_x}" if base_x != target_x
    __debug "after flip Y: #{base_y} -> #{target_y}" if base_y != target_y

    (base_x..target_x).each do |x|
      occupied_cells << {x, @current_y}
    end

    (base_y..target_y).each do |y|
      occupied_cells << {@current_x, y}
    end

    @current_x, @current_y = real_target_x, real_target_y
    __debug "New end pos: #{ {@current_x, @current_y} }"
  end
end

def dist_to_closer_intersection(wire1, wire2)
  __debug! wire1.occupied_cells, wire2.occupied_cells

  common_cells = wire1.occupied_cells & wire2.occupied_cells
  common_cells.delete({0, 0}) # pos {0, 0} does not count
  sorted_common_cells = common_cells.to_a.sort_by! { |(x, y)| x.abs + y.abs }
  __debug "sorted_common_cells: #{sorted_common_cells}"

  unless sorted_common_cells.size >= 1
    puts "ERROR: No intersection found between the wires"
    return 0
  end

  pos = sorted_common_cells.first
  pos[0].abs + pos[1].abs
end

# -------------------------------------

def part1_test_instructions(input, assert_result = nil, debug = false)
  input_lines = input.strip.lines

  if debug
    dbg = G.debug?
    G.debug = true
    puts
  end

  wire1 = Wire.from_instructions input_lines[0]
  wire2 = Wire.from_instructions input_lines[1]

  result = dist_to_closer_intersection(wire1, wire2)

  if assert_result
    if result == assert_result
      puts "OK! Distance #{result} is right for this input"
    else
      puts "!!! Got distance #{result} but expected #{assert_result}"
    end
  end
  result
ensure
  G.debug = dbg unless dbg.nil?
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

part1_test_instructions(test_input1, assert_result: 6, debug: true)

part1_test_instructions(test_input2, assert_result: 159)
part1_test_instructions(test_input3, assert_result: 135)

result = part1_test_instructions(INPUT)
puts "Part1 result: #{result}"
puts

# -------------------------------------


