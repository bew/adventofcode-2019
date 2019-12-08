INPUT = {{ read_file "#{__DIR__}/input" }}

def has_adjacent?(passwd, *, min)
  groups = groups_of_chars(passwd)
  groups.any? { |gr| gr[:count] >= min }
end

def has_adjacent?(passwd, *, has_one_exact)
  groups = groups_of_chars(passwd)
  groups.any? { |gr| gr[:count] == has_one_exact }
end

def groups_of_chars(passwd)
  groups = Array({char: Char, count: Int32}).new

  group_char = nil
  group_count = 1
  passwd.each_char_with_index do |char, index|
    if index == 0
      group_char = char
      group_count = 1
      next
    end

    if char == group_char
      group_count += 1
    else
      # add group on char change
      groups << {char: group_char.not_nil!, count: group_count}
      group_char = char
      group_count = 1
    end
  end
  groups << {char: group_char.not_nil!, count: group_count} # add the last group

  groups
end

def digits_increase_only?(passwd)
  last_digit = nil
  passwd.each_char do |char|
    if last_digit.nil?
      last_digit = char.to_i
      next
    end

    digit = char.to_i

    return false if last_digit > digit
    last_digit = digit
  end
  true
end

def part1_valid_passwd?(passwd : String, allowed_range : Range) : Bool
  # - It is a six-digit number.
  return false unless passwd.size == 6

  # - The value is within the range given in your puzzle input.
  return false unless allowed_range.includes? passwd.to_i

  # - Two adjacent digits are the same (like 22 in 122345).
  return false unless has_adjacent?(passwd, min: 2)

  # - Going from left to right, the digits never decrease; they only ever
  #   increase or stay the same (like 111123 or 135679).
  return false unless digits_increase_only?(passwd)

  true
end

def part2_valid_passwd?(passwd : String, allowed_range : Range) : Bool
  return false unless part1_valid_passwd?(passwd, allowed_range)

  # the two adjacent matching digits are not part of a larger group of
  # matching digits.
  return false unless has_adjacent?(passwd, has_one_exact: 2)

  true
end


min_passwd, max_passwd = INPUT.strip.split('-').map &.to_i
allowed_range = min_passwd..max_passwd

def part1(allowed_range)
  allowed_range.count { |passwd| part1_valid_passwd?(passwd.to_s, allowed_range) }
end

def part2(allowed_range)
  allowed_range.count { |passwd| part2_valid_passwd?(passwd.to_s, allowed_range) }
end

puts "Part1 result: #{part1(allowed_range)}" # Should be 2050
puts "Part2 result: #{part2(allowed_range)}" # Should be 1390
