# MSP430 GCC Toolchain Test Suite

This directory contains tests to validate the MSP430 GCC cross-compiler toolchain after building.

## Quick Start

### On Ubuntu/Generic Linux

Extract and test:
```bash
mkdir -p toolchain
tar -xzf result/msp430-elf-gcc-15.2.0-ubuntu.tar.gz -C toolchain
./tests/test-compiler.sh --quick
```

### On NixOS

Test in Ubuntu container after fixing:
```bash
# Example with podman
podman run -it --rm -v $(pwd):/work ubuntu:24.04 bash
cd /work && apt update && apt install -y build-essential file
mkdir toolchain && tar -xzf result/msp430-elf-gcc-15.2.0-ubuntu.tar.gz -C toolchain
./tests/test-compiler.sh --quick
```

### Test Options

Quick smoke tests (2 tests, ~10 seconds):
```bash
./tests/test-compiler.sh --quick
```

Comprehensive test suite (11+ tests, ~30 seconds):
```bash
./tests/test-compiler.sh --full
```

## What Gets Tested

### Quick Tests (~2 tests, <10 seconds)

Fast validation to catch common build issues:

1. **hello.c** - Basic C compilation
   - Tests: `stdio.h`, `stdlib.h`, basic C features
   - Verifies: C compiler works, standard headers found

2. **blink.cpp** - C++ with cstdint
   - Tests: `<cstdint>` header (previously reported as failing)
   - Verifies: C++ compiler works, stdint types available
   - This catches the specific issue you reported!

### Full Test Suite (~11 tests, ~30 seconds)

Comprehensive validation of all toolchain features:

#### C Standard Library Tests
- **test_c_stdlib.c** - C standard library headers
  - Tests: `stdio.h`, `stdlib.h`, `string.h`, `math.h`, `stdint.h`
  - Verifies: Complete C99/C11 standard library support

#### C++ Standard Library Tests
- **test_cpp_headers.cpp** - C++ STL headers (header-only)
  - Tests: `<cstdint>`, `<type_traits>`, `<limits>`, `<utility>`
  - Verifies: C++ standard library headers work in header-only mode
  
- **test_exceptions.cpp** - C++ without exceptions/RTTI
  - Tests: Classes, templates, constexpr with `-fno-exceptions -fno-rtti`
  - Verifies: Header-only C++ works (no libstdc++ libraries needed)

#### MSP430-Specific Tests
- **test_msp430_headers.c** - MSP430 device support
  - Tests: `msp430.h`, `in430.h`, interrupt vectors, intrinsics
  - Verifies: TI device headers and MSP430-specific features

#### Multilib Tests
- **test_multilib.c** - Different MCU targets
  - Tests compilation for: msp430g2553, msp430f5529, msp430fr5969
  - Verifies: Support for standard MSP430, MSP430X, and FRAM devices

#### Optimization Tests
- Tests different optimization levels: `-O0`, `-O2`, `-Os`
- Verifies: Code generation works at all optimization levels

## Understanding Test Results

### Success Output
```
========================================
Test Summary
========================================
Total tests run: 2
Passed: 2
Failed: 0

All tests passed! ✓
The MSP430 GCC toolchain is working correctly.
```

### Failure Output
```
[✗] C++ compilation with cstdint (blink.cpp)
  Compilation failed. See output/blink.elf.log for details
  First few errors:
    blink.cpp:7:10: fatal error: cstdint: No such file or directory
```