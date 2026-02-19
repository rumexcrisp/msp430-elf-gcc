{ pkgs ? import <nixpkgs> {} }:

let
  toolchain = import ./nix/msp430-toolchain.nix { inherit pkgs; };

in pkgs.mkShell {
  packages = [
    toolchain.binutils
    # Note: gccStage1 is internal bootstrap compiler, not included
    # Only the final gcc with newlib and libstdc++ headers is provided
    toolchain.newlib
    toolchain.gcc
    toolchain.libstdcxx
    toolchain.tiSupportFiles
  ];
  
  shellHook = ''
    echo "To build the tarball, run: nix-build -A tarball ./nix/msp430-toolchain.nix -o build/result"
  '';
}

