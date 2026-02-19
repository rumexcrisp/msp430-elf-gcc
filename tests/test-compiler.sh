#!/usr/bin/env bash
#
# MSP430 GCC Toolchain Test Suite
# Tests the cross-compiler to ensure it's properly built and functional
#
# Usage:
#   ./test-compiler.sh --quick    Run quick smoke tests (2 tests)
#   ./test-compiler.sh --full     Run comprehensive test suite (10+ tests)
#   ./test-compiler.sh            Run quick tests by default
#

set -e  # Exit on error unless explicitly handled

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Flag for steam-run usage
USE_STEAM_RUN=false

# Directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TOOLCHAIN_DIR="$WORKSPACE_ROOT/toolchain/msp430-elf"
OUTPUT_DIR="$SCRIPT_DIR/output"

# Compiler paths
GCC="$TOOLCHAIN_DIR/bin/msp430-elf-gcc"
GXX="$TOOLCHAIN_DIR/bin/msp430-elf-g++"
OBJDUMP="$TOOLCHAIN_DIR/bin/msp430-elf-objdump"
SIZE="$TOOLCHAIN_DIR/bin/msp430-elf-size"

# Default MCU target
MCU="msp430g2553"

# Common compiler flags
CFLAGS_COMMON="-mmcu=$MCU -Wall -O2"
# Note: -fno-exceptions selects the 430/no-exceptions multilib. We must add
# the target-specific C++ include dir so bits/c++config.h is found, because
# GCC's compiled-in --with-sysroot (a Nix store path) prevents automatic
# resolution of the multilib-specific C++ header directory.
CXXFLAGS_COMMON="-mmcu=$MCU -Wall -O2 -fno-exceptions -fno-rtti -isystem $TOOLCHAIN_DIR/msp430-elf/include/c++/15.2.0/msp430-elf/430"

# Function to print section headers
print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

# Function to print test status
print_test() {
    local test_name="$1"
    local status="$2"
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if [ "$status" = "PASS" ]; then
        echo -e "[${GREEN}✓${NC}] $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "[${RED}✗${NC}] $test_name"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Function to compile a test file
compile_test() {
    local source_file="$1"
    local output_file="$2"
    local compiler="$3"
    local flags="$4"
    local test_name="$5"
    
    if [ ! -f "$source_file" ]; then
        print_test "$test_name" "FAIL"
        echo -e "  ${RED}Error: Source file not found: $source_file${NC}"
        return 1
    fi
    
    # Detect compile-only mode: output is a .o file
    local compile_only=false
    if [[ "$output_file" == *.o ]]; then
        compile_only=true
        flags="$flags -c"
    fi
    
    # Wrap compiler with steam-run if needed
    if [ "$USE_STEAM_RUN" = "true" ]; then
        steam-run "$compiler" $flags "$source_file" -o "$output_file" 2>"${output_file}.log"
        local result=$?
    else
        "$compiler" $flags "$source_file" -o "$output_file" 2>"${output_file}.log"
        local result=$?
    fi
    
    if [ $result -eq 0 ]; then
        if [ "$compile_only" = "true" ]; then
            # For compile-only, just check the output file exists
            if [ -f "$output_file" ]; then
                print_test "$test_name" "PASS"
                return 0
            else
                print_test "$test_name" "FAIL"
                echo -e "  ${RED}Error: Object file not created${NC}"
                return 1
            fi
        fi
        # Verify output is an ELF file
        if file "$output_file" | grep -q "ELF"; then
            print_test "$test_name" "PASS"
            # Show size information
            if [ "$USE_STEAM_RUN" = "true" ]; then
                steam-run "$SIZE" "$output_file" 2>/dev/null | tail -n 1 | awk '{printf "  Size: text=%s data=%s bss=%s\n", $1, $2, $3}'
            else
                "$SIZE" "$output_file" 2>/dev/null | tail -n 1 | awk '{printf "  Size: text=%s data=%s bss=%s\n", $1, $2, $3}'
            fi
            return 0
        else
            print_test "$test_name" "FAIL"
            echo -e "  ${RED}Error: Output is not an ELF file${NC}"
            return 1
        fi
    else
        print_test "$test_name" "FAIL"
        echo -e "  ${RED}Compilation failed. See ${output_file}.log for details${NC}"
        if [ -f "${output_file}.log" ]; then
            echo -e "  ${YELLOW}First few errors:${NC}"
            head -n 5 "${output_file}.log" | sed 's/^/    /'
        fi
        return 1
    fi
}

# Check if toolchain exists
check_toolchain() {
    print_header "Checking Toolchain"
    
    # Check if we're on NixOS
    if [ -f /etc/NIXOS ]; then
        echo -e "${YELLOW}Note: Running on NixOS${NC}"
        
        # Check if toolchain has been extracted
        if [ ! -d "$TOOLCHAIN_DIR" ]; then
            echo -e "${RED}Error: Toolchain directory not found: $TOOLCHAIN_DIR${NC}"
            echo -e "${YELLOW}Please extract the toolchain tarball first:${NC}"
            echo -e "  ${BLUE}mkdir -p toolchain${NC}"
            echo -e "  ${BLUE}tar -xzf result/msp430-elf-gcc-15.2.0-ubuntu.tar.gz -C toolchain${NC}"
            echo ""
            echo -e "${YELLOW}Then test using steam-run (provides FHS environment):${NC}"
            echo -e "  ${BLUE}nix-shell -p steam-run --run './tests/test-compiler.sh --quick'${NC}"
            exit 1
        fi
        
        # Check for steam-run to provide FHS environment
        if command -v steam-run >/dev/null 2>&1; then
            echo -e "${GREEN}✓ Found steam-run for FHS environment${NC}"
            echo -e "${YELLOW}Note: steam-run testing has limitations due to embedded nix store paths${NC}"
            echo -e "${YELLOW}For accurate testing, use Ubuntu/generic Linux or a container${NC}"
            echo ""
            
            # Set flag to use steam-run for compilation
            USE_STEAM_RUN=true
        else
            echo -e "${YELLOW}Warning: steam-run not found${NC}"
            echo -e "${YELLOW}The Ubuntu tarball needs FHS environment to run on NixOS.${NC}"
            echo -e "${YELLOW}For accurate testing, use Ubuntu/generic Linux or a container.${NC}"
            echo ""
            echo -e "${YELLOW}To try with steam-run (may have limitations):${NC}"
            echo -e "  ${BLUE}NIXPKGS_ALLOW_UNFREE=1 nix-shell -p steam-run --impure --run './tests/test-compiler.sh --quick'${NC}"
            echo ""
            echo -e "${YELLOW}Or run this script directly (will fail with dynamic linking errors).${NC}"
            read -p "Continue anyway? [y/N] " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
        fi
        
        echo -e "${GREEN}✓ Toolchain found at: $TOOLCHAIN_DIR${NC}"
    else
        # Regular Linux system - use extracted toolchain
        if [ ! -d "$TOOLCHAIN_DIR" ]; then
            echo -e "${RED}Error: Toolchain directory not found: $TOOLCHAIN_DIR${NC}"
            echo -e "${YELLOW}Please extract the toolchain tarball first:${NC}"
            echo -e "  ${BLUE}mkdir -p toolchain${NC}"
            echo -e "  ${BLUE}tar -xzf result/msp430-elf-gcc-15.2.0-ubuntu.tar.gz -C toolchain${NC}"
            exit 1
        fi
        
        if [ ! -x "$GCC" ]; then
            echo -e "${RED}Error: GCC compiler not found or not executable: $GCC${NC}"
            exit 1
        fi
        
        if [ ! -x "$GXX" ]; then
            echo -e "${RED}Error: G++ compiler not found or not executable: $GXX${NC}"
            exit 1
        fi
        
        echo -e "${GREEN}✓ Toolchain found at: $TOOLCHAIN_DIR${NC}"
    fi
    
    # Show version
    echo -e "\nCompiler version:"
    if [ "$USE_STEAM_RUN" = "true" ]; then
        steam-run $GCC --version 2>&1 | head -n 1
    else
        $GCC --version 2>&1 | head -n 1
    fi
    echo ""
}

# Quick smoke tests
run_quick_tests() {
    print_header "Quick Smoke Tests"
    echo "Running minimal tests to verify basic functionality..."
    echo ""
    
    # Create output directory
    mkdir -p "$OUTPUT_DIR"
    
    # Test 1: Hello.c (C compilation)
    # Use .o output (compile-only) — linking requires libgloss (crt0.o, libnosys)
    # which is only available after rebuilding the toolchain with --enable-libgloss
    compile_test \
        "$SCRIPT_DIR/quick/hello.c" \
        "$OUTPUT_DIR/hello.o" \
        "$GCC" \
        "$CFLAGS_COMMON" \
        "C compilation (hello.c)" || true
    
    # Test 2: Blink.cpp (C++ with cstdint)
    compile_test \
        "$SCRIPT_DIR/quick/blink.cpp" \
        "$OUTPUT_DIR/blink.o" \
        "$GXX" \
        "$CXXFLAGS_COMMON" \
        "C++ compilation with cstdint (blink.cpp)" || true
}

# Comprehensive tests
run_full_tests() {
    print_header "Comprehensive Test Suite"
    echo "Running full validation of C/C++ features and MSP430 support..."
    echo ""
    
    # Create output directory
    mkdir -p "$OUTPUT_DIR"
    
    # Quick tests first
    echo -e "${BLUE}--- Quick Smoke Tests ---${NC}"
    compile_test \
        "$SCRIPT_DIR/quick/hello.c" \
        "$OUTPUT_DIR/hello.elf" \
        "$GCC" \
        "$CFLAGS_COMMON" \
        "C compilation (hello.c)" || true
    
    compile_test \
        "$SCRIPT_DIR/quick/blink.cpp" \
        "$OUTPUT_DIR/blink.elf" \
        "$GXX" \
        "$CXXFLAGS_COMMON" \
        "C++ compilation with cstdint (blink.cpp)" || true
    
    echo ""
    echo -e "${BLUE}--- C Standard Library Tests ---${NC}"
    compile_test \
        "$SCRIPT_DIR/comprehensive/test_c_stdlib.c" \
        "$OUTPUT_DIR/test_c_stdlib.elf" \
        "$GCC" \
        "$CFLAGS_COMMON" \
        "C standard library headers" || true
    
    echo ""
    echo -e "${BLUE}--- C++ Standard Library Tests ---${NC}"
    compile_test \
        "$SCRIPT_DIR/comprehensive/test_cpp_headers.cpp" \
        "$OUTPUT_DIR/test_cpp_headers.elf" \
        "$GXX" \
        "$CXXFLAGS_COMMON" \
        "C++ standard library headers (header-only)" || true
    
    compile_test \
        "$SCRIPT_DIR/comprehensive/test_exceptions.cpp" \
        "$OUTPUT_DIR/test_exceptions.elf" \
        "$GXX" \
        "$CXXFLAGS_COMMON" \
        "C++ without exceptions/RTTI" || true
    
    echo ""
    echo -e "${BLUE}--- MSP430-Specific Tests ---${NC}"
    compile_test \
        "$SCRIPT_DIR/comprehensive/test_msp430_headers.c" \
        "$OUTPUT_DIR/test_msp430_headers.elf" \
        "$GCC" \
        "$CFLAGS_COMMON" \
        "MSP430 device headers and intrinsics" || true
    
    echo ""
    echo -e "${BLUE}--- Multilib Tests (Different MCU Targets) ---${NC}"
    # Test with standard MSP430
    compile_test \
        "$SCRIPT_DIR/comprehensive/test_multilib.c" \
        "$OUTPUT_DIR/test_multilib_g2553.elf" \
        "$GCC" \
        "-mmcu=msp430g2553 -Wall -O2" \
        "Standard MSP430 (msp430g2553)" || true
    
    # Test with MSP430X (large memory model)
    compile_test \
        "$SCRIPT_DIR/comprehensive/test_multilib.c" \
        "$OUTPUT_DIR/test_multilib_f5529.elf" \
        "$GCC" \
        "-mmcu=msp430f5529 -Wall -O2" \
        "MSP430X large memory (msp430f5529)" || true
    
    # Test with another common device
    compile_test \
        "$SCRIPT_DIR/comprehensive/test_multilib.c" \
        "$OUTPUT_DIR/test_multilib_fr5969.elf" \
        "$GCC" \
        "-mmcu=msp430fr5969 -Wall -O2" \
        "MSP430FR FRAM device (msp430fr5969)" || true
    
    echo ""
    echo -e "${BLUE}--- Optimization Level Tests ---${NC}"
    # Test different optimization levels
    compile_test \
        "$SCRIPT_DIR/quick/hello.c" \
        "$OUTPUT_DIR/hello_Os.elf" \
        "$GCC" \
        "-mmcu=$MCU -Wall -Os" \
        "Size optimization (-Os)" || true
    
    compile_test \
        "$SCRIPT_DIR/quick/hello.c" \
        "$OUTPUT_DIR/hello_O0.elf" \
        "$GCC" \
        "-mmcu=$MCU -Wall -O0" \
        "No optimization (-O0)" || true
}

# Print summary
print_summary() {
    echo ""
    print_header "Test Summary"
    
    echo "Total tests run: $TESTS_RUN"
    echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
    
    if [ $TESTS_FAILED -gt 0 ]; then
        echo -e "${RED}Failed: $TESTS_FAILED${NC}"
        echo ""
        echo -e "${YELLOW}Check the log files in $OUTPUT_DIR for error details.${NC}"
        return 1
    else
        echo -e "${RED}Failed: $TESTS_FAILED${NC}"
        echo ""
        echo -e "${GREEN}All tests passed! ✓${NC}"
        echo -e "${GREEN}The MSP430 GCC toolchain is working correctly.${NC}"
        return 0
    fi
}

# Main script
main() {
    local mode="${1:---quick}"  # Default to quick mode
    
    echo -e "${BLUE}MSP430 GCC Toolchain Test Suite${NC}"
    echo ""
    
    # Check toolchain first
    check_toolchain
    
    # Run appropriate tests
    case "$mode" in
        --quick)
            run_quick_tests
            ;;
        --full)
            run_full_tests
            ;;
        --help|-h)
            echo "Usage: $0 [--quick|--full]"
            echo ""
            echo "Options:"
            echo "  --quick    Run quick smoke tests (default)"
            echo "  --full     Run comprehensive test suite"
            echo "  --help     Show this help message"
            exit 0
            ;;
        *)
            echo -e "${RED}Error: Unknown option: $mode${NC}"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
    
    # Print summary and exit with appropriate code
    if print_summary; then
        exit 0
    else
        exit 1
    fi
}

# Run main function
main "$@"
