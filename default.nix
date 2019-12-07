with import <nixpkgs> {};

let
  mkDayDrv = src: main_src: stdenv.mkDerivation {
    name = "adventofcode-2019--${baseNameOf src}";

    buildInputs = [
      crystal
    ];

    inherit src;

    buildPhase = ''
      ${crystal}/bin/crystal build "${main_src}" -o compiled-day
    '';

    installPhase = ''
      cp compiled-day $out
    '';
  };

in {
  day1 = mkDayDrv ./day1 "day1.cr";
  day2 = mkDayDrv ./day2 "day2.cr";
}
