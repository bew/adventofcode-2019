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

input_lines = INPUT.lines
wire1 = Wire.from_instructions input_lines[0]
wire2 = Wire.from_instructions input_lines[1]

result = part1(wire1, wire2)
puts "Part1 result: #{result}" # Should be 386

result = part2(wire1, wire2)
puts "Part2 result: #{result}" # Should be 6484
