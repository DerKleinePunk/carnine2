/*
 * Stand-ins for the AVR registers and avr-libc calls the firmware uses, so it
 * compiles unchanged with the host's gcc (tests/firmware_test.c). Registers
 * are plain variables; the test reads and sets them. Calls that matter for a
 * test (watchdog, delay, cli) go to hooks in firmware_test.c.
 */
#ifndef HOST_AVR_H_
#define HOST_AVR_H_

#include <stdint.h>
#include <stdio.h>

static volatile uint8_t PORTB, DDRB, PINB, PORTC, DDRC, PINC, PORTD, DDRD, PIND;
static volatile uint8_t ADMUX, ADCSRA, ADCL, ADCH, WDTCSR;
static volatile uint8_t TCCR0A, TCCR0B, OCR0A, TIMSK0;
static volatile uint8_t UCSR0A, UCSR0B, UCSR0C, UBRR0H, UBRR0L, UDR0;

#define PD4 4
#define PD5 5
#define TXEN0 3
#define UDRIE0 5
#define bit_is_clear(reg, bit) (!((reg) & (1 << (bit))))

void host_wdt_reset(void);
void host_delay_ms(double ms);
void host_cli(void);

/* asm("WDR") feeds the watchdog. */
#define asm(instruction) host_wdt_reset()

/* avr-libc has itoa, glibc does not. */
static char* itoa(int value, char* text, int radix)
{
    (void)radix;
    sprintf(text, "%d", value);
    return text;
}

#endif
