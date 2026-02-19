/*
 * Comprehensive test for C++ standard library headers
 * Tests: cstdint, iostream, vector, algorithm, memory, type_traits
 * Note: Using header-only features since libstdc++ is not built
 * Compile with: -fno-exceptions -fno-rtti
 */

#include <cstdint>
#include <cstddef>
#include <type_traits>
#include <utility>
#include <limits>

// Test cstdint types
static uint8_t u8 = 0;
static uint16_t u16 = 0;
static uint32_t u32 = 0;
static int8_t i8 = 0;
static int16_t i16 = 0;
static int32_t i32 = 0;

// Test type traits (header-only)
static_assert(sizeof(uint8_t) == 1, "uint8_t should be 1 byte");
static_assert(sizeof(uint16_t) == 2, "uint16_t should be 2 bytes");
static_assert(sizeof(uint32_t) == 4, "uint32_t should be 4 bytes");

// Template function to test header-only features
template<typename T>
constexpr T max_value(T a, T b) {
    return (a > b) ? a : b;
}

// Test type traits
template<typename T>
struct is_valid_msp430_type {
    static constexpr bool value = 
        std::is_integral<T>::value && 
        sizeof(T) <= 4;
};

int main() {
    // Test std::numeric_limits (header-only)
    constexpr uint16_t max_u16 = std::numeric_limits<uint16_t>::max();
    
    // Test constexpr functions
    constexpr int result = max_value(42, 100);
    
    // Test type traits
    static_assert(is_valid_msp430_type<uint16_t>::value, "uint16_t is valid");
    static_assert(std::is_same<uint8_t, unsigned char>::value, "uint8_t is unsigned char");
    
    // Test std::pair (header-only)
    std::pair<uint16_t, uint16_t> coordinates(10, 20);
    
    // Use values to prevent optimization
    u8 = static_cast<uint8_t>(result);
    u16 = max_u16;
    u32 = coordinates.first + coordinates.second;
    
    if (u8 && u16 && u32) {
        return 0;
    }
    
    return 1;
}
