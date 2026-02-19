/*
 * Quick smoke test for C compilation
 * Tests: basic C standard library headers, main function
 * Target: msp430g2553
 */

#include <stdio.h>
#include <stdlib.h>

int main(void) {
    // Minimal C program to verify compilation
    volatile int result = 42;
    
    // These won't actually execute on embedded target,
    // but should compile successfully
    if (result > 0) {
        return EXIT_SUCCESS;
    }
    
    return EXIT_FAILURE;
}
