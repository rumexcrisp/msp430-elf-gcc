/*
 * Test C++ compilation with -fno-exceptions -fno-rtti
 * Since libstdc++ library is not built, we need to ensure
 * the compiler works in header-only mode without exceptions/RTTI
 */

#include <cstdint>
#include <type_traits>

// Classes without RTTI
class Device {
public:
    constexpr Device() : state_(0) {}
    
    void setState(uint8_t s) { state_ = s; }
    uint8_t getState() const { return state_; }
    
private:
    uint8_t state_;
};

class LED : public Device {
public:
    constexpr LED() : Device(), brightness_(0) {}
    
    void setBrightness(uint8_t b) { brightness_ = b; }
    uint8_t getBrightness() const { return brightness_; }
    
private:
    uint8_t brightness_;
};

// Template metaprogramming (header-only)
template<typename T>
struct Limits {
    static constexpr T min() { return T(0); }
    static constexpr T max() { return T(-1); }  // Works for unsigned types
};

// Constexpr function (no runtime overhead)
constexpr uint16_t calculate_delay(uint16_t frequency) {
    return 1000000 / frequency;
}

int main() {
    // Test classes without RTTI
    LED led;
    led.setState(1);
    led.setBrightness(128);
    
    // Test templates
    constexpr uint8_t max_u8 = Limits<uint8_t>::max();
    constexpr uint16_t delay = calculate_delay(1000);
    
    // Test type traits (no exceptions needed)
    static_assert(std::is_class<LED>::value, "LED should be a class");
    static_assert(!std::is_polymorphic<LED>::value, "LED should not be polymorphic without virtual functions");
    
    // Use values
    volatile uint8_t result = led.getState() + max_u8;
    volatile uint16_t timing = delay;
    
    if (result && timing) {
        return 0;
    }
    
    return 1;
}
