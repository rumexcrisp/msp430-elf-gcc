/*
 * Test for multilib support
 * This file is compiled multiple times with different flags to test
 * that the compiler supports different MSP430 variants:
 * - Standard MSP430 (16-bit pointers)
 * - MSP430X large memory model (20-bit pointers)
 * 
 * The test script will compile this with different -mmcu flags
 */

#include <msp430.h>
#include <stdint.h>

// Test pointer sizes based on memory model
void test_pointer_size(void) {
    void* ptr = (void*)0x1234;
    
    // In standard 430 mode: sizeof(void*) == 2
    // In large mode (430X): sizeof(void*) can be 4 for __data20 pointers
    volatile size_t ptr_size = sizeof(void*);
    
    // Use the value
    if (ptr && ptr_size) {
        __no_operation();
    }
}

// Test that code works across variants
void blink_led(void) {
    WDTCTL = WDTPW | WDTHOLD;
    
    // These registers exist on most MSP430 variants
    P1DIR |= 0x01;
    P1OUT ^= 0x01;
}

int main(void) {
    test_pointer_size();
    blink_led();
    
    while(1) {
        __no_operation();
    }
    
    return 0;
}
