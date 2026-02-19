/*
 * Quick smoke test for C++ compilation
 * Tests: cstdint header (previously reported as failing), basic C++ features
 * Target: msp430g2553
 */

#include <cstdint>

// Test that cstdint types are available
volatile uint8_t counter = 0;
volatile uint16_t timer = 0;
volatile uint32_t ticks = 0;

int main(void) {
    // Simple LED blink logic (conceptual - no actual hardware access)
    counter = 1;
    timer = 1000;
    ticks = 0xDEADBEEF;
    
    // Use the types to ensure they're properly defined
    uint8_t state = counter;
    uint16_t delay = timer;
    uint32_t timestamp = ticks;
    
    // Prevent optimization
    if (state && delay && timestamp) {
        return 0;
    }
    
    return 1;
}
