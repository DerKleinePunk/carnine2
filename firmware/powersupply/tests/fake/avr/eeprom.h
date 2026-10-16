#include "../host_avr.h"
#define EEMEM
static inline uint8_t eeprom_read_byte(const uint8_t* address) { return *address; }
static inline void eeprom_write_byte(uint8_t* address, uint8_t value) { *address = value; }
static inline void eeprom_update_byte(uint8_t* address, uint8_t value) { *address = value; }
