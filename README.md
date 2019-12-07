# Advent of Code 2019

This is my attempt at the 2019 edition of [AdventOfCode](https://adventofcode.com/2019), using the [Crystal](https://crystal-lang.org) programming language.

This project is also my first time using the [Nix](https://nixos.org/nix/) package manager :tada:.

### Build & run using Nix

Build all puzzles using `nix-build` or specific day using `nix-build -A day2`.

Then the built puzzles are symlinked by `nix-build` in the current directory.

### Run using crystal directly

Each day puzzle can be run using: `crystal run ./day2/day2.cr`
