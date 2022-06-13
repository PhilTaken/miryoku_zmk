{
  description = "Flake for the miryoku zmk firmware";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    zmk-src = {
      url = "github:zmkfirmware/zmk";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, flake-utils, zmk-src, ... }@inputs:
  flake-utils.lib.eachDefaultSystem (system: let
    pkgs = import nixpkgs { inherit system; };
    pypacks = ps: with ps; [
      west
      pyelftools
      pyyaml
      pykwalify
      canopen
      packaging
      progress
      psutil
      #pylink-square
      anytree
      intelhex
    ];

    pyenv = pkgs.python39.withPackages pypacks;

    # TODO: cache dependencies, build firmware using fixed
    # need to recursively parse west.yamls...
    buildscript = pkgs.writeShellScript "build" ''
      set -e

      origdir=$PWD
      builddir=$origdir/build
      mkdir -p $builddir
      cd $builddir

      if [ ! -d zmk/ ]; then
        mkdir zmk/
        cp -r ${zmk-src}/* zmk
        chmod -R +w zmk
        cd zmk

        ${pyenv}/bin/west init -l app
      else
        cd zmk
      fi

      ${pyenv}/bin/west update
      cd app

      export ZEPHYR_TOOLCHAIN_VARIANT=gnuarmemb
      export GNUARMEMB_TOOLCHAIN_PATH=${pkgs.gcc-arm-embedded}

      cmake_config="-DZMK_CONFIG=${./.}/config -DCMAKE_MAKE_PROGRAM:PATH=${pkgs.ninja}/bin/ninja"

      ${pyenv}/bin/west build -b nice_nano_v2 -- -DSHIELD=corne_left $cmake_config
      cp build/zephyr/zmk.uf2 $origdir/left.uf2

      ${pyenv}/bin/west build -b nice_nano_v2 -- -DSHIELD=corne_right $cmake_config
      cp build/zephyr/zmk.uf2 $origdir/right.uf2

      cd $origdir
    '';
  in rec {
    devShell = pkgs.mkShell {
      nativeBuildInputs = [ pkgs.bashInteractive ];
      buildInputs = with pkgs; [
        buildscript
      ];
    };

    apps = rec {
      firmware = flake-utils.lib.mkApp {
        drv = buildscript;
        exePath = "";
      };

      default = firmware;
    };
  });
}
