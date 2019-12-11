INPUT = {{ read_file "#{__DIR__}/input" }}.strip

class Planet
  # Name of the planet
  getter name : String

  # The planet I am orbiting around.
  #
  # `nil` for the Center of Mass.
  getter direct_orbit : Planet?

  # The planets orbiting around me
  protected getter planets_around = [] of Planet

  def initialize(@name)
  end

  def orbits_around(other_planet)
    @direct_orbit = other_planet
    other_planet.planets_around << self
  end

  def num_of_indirect_orbits
    planet = @direct_orbit || return 0
    num = 0
    while parent = planet.direct_orbit
      num += 1
      planet = parent
    end
    num
  end

  def total_direct_indirect_orbit
    (@direct_orbit ? 1 : 0) + num_of_indirect_orbits
  end

  def planets_in_direct_or_indirect_orbit
    planets = [] of Planet
    planet = @direct_orbit || return planets
    planets << planet

    while parent = planet.direct_orbit
      planets = parent
      planet = parent
    end
  end
end

class OrbitMap
  @planets_by_name = {} of String => Planet
  @center : Planet?

  def center
    @center || raise "Error: This OrbitMap does not have a Center of Mass"
  end

  def register_planet(name)
    planet = @planets_by_name[name] ||= Planet.new name

    if name == "COM"
      @center = planet
    end

    planet
  end

  def find_planet?(name)
    @planets_by_name[name]?
  end

  def find_planet!(name)
    @planets_by_name[name]? || raise "Error: Planet #{name} is not in the map"
  end

  def planets
    @planets_by_name.values
  end
end


def load_orbit_map(input)
  orbit_map = OrbitMap.new

  input.each_line do |line|
    name1, name2_around_1 = line.split(')', limit: 2)

    planet1 = orbit_map.register_planet(name1)
    planet2_around_1 = orbit_map.register_planet(name2_around_1)

    planet2_around_1.orbits_around planet1
  end

  orbit_map
end

# ------------

def part1(input)
  orbit_map = load_orbit_map(input)
  orbit_map.planets.map(&.total_direct_indirect_orbit).sum
end

def part2(input)
  orbit_map = load_orbit_map(input)

  # find a common direct / indirect orbit

  you = orbit_map.find_planet!("YOU")
  san = orbit_map.find_planet!("SAN")


end

test_input = <<-ORBIT_MAP.strip
  COM)B
  B)C
  C)D
  D)E
  E)F
  B)G
  G)H
  D)I
  E)J
  J)K
  K)L
  ORBIT_MAP

result = part1 test_input
puts "Result for test_input: #{result}"
puts "Should be 42"
puts

result = part1 INPUT
puts "Result for part1: #{result}"
puts "Should be 241064"
puts

# test_input +=

part2 test_input
