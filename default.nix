with import <nixpkgs> {};

let
  mkDayDrv = main_src: stdenv.mkDerivation {
    name = "adventofcode-2019--${baseNameOf main_src}-bin";

    buildInputs = [
      crystal
    ];

    src = ./.;

    buildPhase = ''
      ${crystal}/bin/crystal build "${main_src}" -o compiled-day
    '';

    installPhase = ''
      cp compiled-day $out
    '';
  };

in {
  day1 = mkDayDrv "./day1/day1.cr";
  day2 = mkDayDrv "./day2/day2.cr";
  day3 = mkDayDrv "./day3/day3.cr";
  day3_with_tests = mkDayDrv "./day3/day3_with_tests.cr";
  day4 = mkDayDrv "./day4/day4.cr";
  day5 = mkDayDrv "./day5/day5.cr";
  day6 = mkDayDrv "./day6/day6.cr";
}
