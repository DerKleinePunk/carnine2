#include "../host_avr.h"
#define ATOMIC_FORCEON
#define ATOMIC_BLOCK(type) for(int atomic_once = 1; atomic_once; atomic_once = 0)
