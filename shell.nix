with import <nixpkgs> {};

stdenv.mkDerivation {
  name = "adventofcode-2019--dev";
  buildInputs = [
    crystal_0_31
    icr
    just
    watchexec
  ];
}
