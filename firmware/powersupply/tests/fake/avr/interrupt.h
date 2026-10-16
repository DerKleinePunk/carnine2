#include "../host_avr.h"
#define SIGNAL(vector) void vector(void)
#define sei()
#define cli() host_cli()
