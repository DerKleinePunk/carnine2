// set bit
static inline void BIT_SET(volatile uint8_t* target, uint8_t bit) __attribute__((always_inline));
static inline void BIT_SET(volatile uint8_t* target, uint8_t bit)
{
    *target |= (1 << bit);
};

// set clear
static inline void BIT_CLEAR(volatile uint8_t* target, uint8_t bit) __attribute__((always_inline));
static inline void BIT_CLEAR(volatile uint8_t* target, uint8_t bit)
{
    *target &= ~(1 << bit);
};
