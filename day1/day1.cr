INPUT = {{ read_file "./input" }}

def mass_to_fuel(mass)
  mass // 3 - 2
end

def part1(modules_masses)
  fuel_sum = modules_masses.sum { |mass| mass_to_fuel(mass) }

  puts "Part1: Sum of fuel needed for all #{modules_masses.size} modules: #{fuel_sum}"
end

# -------------------------------

def mass_to_total_fuel(mass)
  total = 0
  while (fuel = mass_to_fuel(mass)) > 0
    total += fuel
    mass = fuel
  end
  total
end

def part2(modules_masses)
  fuel_total_sum = modules_masses.sum { |mass| mass_to_total_fuel(mass) }

  puts "Part2: Total sum of all fuel for all modules: #{fuel_total_sum}"
end

# -------------------------------

modules_masses = INPUT.split('\n', remove_empty: true).map &.to_i

part1(modules_masses)
part2(modules_masses)
