/*
 * Comprehensive test for C standard library headers
 * Tests: stdio.h, stdlib.h, string.h, math.h, stdint.h
 * Target: msp430g2553
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <stdint.h>
#include <stdbool.h>

// Test string operations
static char buffer[64];

// Test math functions
static float calculate(float x) {
    return sqrt(x) * 2.0f;
}

int main(void) {
    // Test stdint types
    uint8_t u8 = 255;
    int16_t i16 = -1000;
    uint32_t u32 = 0xFFFFFFFF;
    
    // Test bool
    bool flag = true;
    
    // Test string operations
    strcpy(buffer, "MSP430");
    size_t len = strlen(buffer);
    
    // Test memory operations
    memset(buffer, 0, sizeof(buffer));
    
    // Test math
    float result = calculate(16.0f);
    
    // Test stdlib
    int value = abs(-42);
    
    // Prevent optimization
    if (u8 && i16 && u32 && flag && len && result && value) {
        return EXIT_SUCCESS;
    }
    
    return EXIT_FAILURE;
}
