{ pkgs ? import <nixpkgs> {} }:

let
  toolchain = import ./nix/msp430-toolchain.nix { inherit pkgs; };

in pkgs.mkShell {
  packages = [
    toolchain.binutils
    toolchain.gccStage1
    toolchain.newlib
    toolchain.gcc
    toolchain.libstdcxx
  ];
  
  shellHook = ''
    echo "To build the tarball, run: nix-build -A tarball ./nix/msp430-toolchain.nix"
  '';
}

