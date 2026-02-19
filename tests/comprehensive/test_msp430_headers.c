/*
 * Comprehensive test for MSP430-specific headers
 * Tests: msp430.h, in430.h, device-specific headers, interrupt macros
 * Target: msp430g2553
 */

#include <msp430.h>
#include <in430.h>

// Test interrupt vector definitions
#pragma RETAIN(timerA_isr)
#pragma INTERRUPT(timerA_isr, TIMER0_A0_VECTOR)
void timerA_isr(void) {
    // Simple interrupt handler
    volatile unsigned int dummy = TA0CCR0;
    dummy++;
}

// Test device-specific register access
void configure_watchdog(void) {
    WDTCTL = WDTPW | WDTHOLD;  // Stop watchdog timer
}

void configure_clock(void) {
    // Basic clock configuration
    BCSCTL1 = CALBC1_1MHZ;
    DCOCTL = CALDCO_1MHZ;
}

void configure_gpio(void) {
    // GPIO configuration
    P1DIR |= BIT0;   // Set P1.0 as output
    P1OUT &= ~BIT0;  // Clear P1.0
}

// Test intrinsics
void test_intrinsics(void) {
    __enable_interrupt();
    __no_operation();
    __disable_interrupt();
}

int main(void) {
    configure_watchdog();
    configure_clock();
    configure_gpio();
    test_intrinsics();
    
    // Infinite loop (typical for embedded)
    while(1) {
        P1OUT ^= BIT0;  // Toggle LED
        
        // Delay
        volatile unsigned int i;
        for(i = 0; i < 10000; i++) {
            __no_operation();
        }
    }
    
    return 0;
}
