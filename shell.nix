with import <nixpkgs> {};

stdenv.mkDerivation {
  name = "adventofcode-2019--dev";
  buildInputs = [
    crystal
    icr
  ];
}
