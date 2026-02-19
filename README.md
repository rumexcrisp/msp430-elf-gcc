# msp430-elf-gcc 15.2

> [!NOTE]  
> This is a work-in-progress conversion of the original GCC 9.3.1.x based msp430 toolchain to a modern GCC variant heavily leveraging AI assistance as I dont have the time to do everything by hand.

A Nix-based build system for GCC 15.2.0 cross-compiler targeting MSP430 microcontrollers.

Credits to [msp430-elf-gcc AUR](https://aur.archlinux.org/packages/msp430-elf-gcc).

## Building

Build the toolchain using Nix:
```bash
nix-build nix/msp430-toolchain.nix -A tarball
```