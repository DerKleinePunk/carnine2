/*
 * Host tests for the power supply firmware: RaspberryPower.c and serial.c
 * compiled unchanged with the host's gcc against tests/fake/ (registers as
 * plain variables). Run with `make test` or `./build.sh test`.
 *
 * Time: each pass of MainLoop() gets one millisecond tick (Int1msCount), as
 * the 1 kHz timer interrupt gives it; second() is 1001 passes, which is what
 * the firmware counts as a second. Waiting inside the firmware (_delay_ms)
 * advances a clock
 * that models the hardware watchdog: more than WATCHDOG_MS without
 * wdt_reset() resets the chip, as does ResetTheChip() (it calls cli()). A
 * reset leaves the test through longjmp; on the board it clears PORTB, so
 * every relay drops and the Pi loses its power.
 */
#include <setjmp.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#define main firmware_main
#include "../RaspberryPower.c"
/* helper.h has no include guard; serial.c gets its own copy under other names. */
#define BIT_SET serial_BIT_SET
#define BIT_CLEAR serial_BIT_CLEAR
#include "../serial.c"
#undef BIT_SET
#undef BIT_CLEAR
#undef main

/* InitWDT(): WDP1|WDP0, about 125 ms. */
#define WATCHDOG_MS 125

#ifndef KL15_OFF_DEBOUNCE_MS
#define KL15_OFF_DEBOUNCE_MS 1000 /* V2.3.0 has none; the tests expect it */
#endif

#define KL15_PIN 0x10
#define USB_PIN 0x01
#define DIG3_PIN 0x10
#define DIG2_PIN 0x20

#define RELAY_DISPLAY 1
#define RELAY_PI 2
#define RELAY_AMPLIFIER 4

enum reset_cause { NO_RESET, RESET_BY_WATCHDOG, RESET_BY_CLI };

static jmp_buf chip_reset;
static bool expect_reset;
static double ms_since_wdt;

struct late_byte {
    double at_ms;
    uint8_t byte;
};
static struct late_byte late[4];
static int late_count;
static double clock_ms;

static uint8_t sent[512];
static int sent_count;

static int failures;
static int checks;

#define CHECK(condition)                                                                           \
    do {                                                                                           \
        checks++;                                                                                  \
        if(!(condition)) {                                                                         \
            failures++;                                                                            \
            printf("  FAILED %s:%d: %s\n", __FILE__, __LINE__, #condition);                         \
        }                                                                                          \
    } while(0)

void host_wdt_reset(void)
{
    ms_since_wdt = 0;
}

static void receive(uint8_t byte)
{
    UDR0 = byte;
    USART_RX_vect();
}

void host_delay_ms(double ms)
{
    clock_ms += ms;
    ms_since_wdt += ms;
    for(int i = 0; i < late_count; i++) {
        if(late[i].at_ms <= clock_ms) {
            receive(late[i].byte);
            late[i] = late[--late_count];
            i--;
        }
    }
    if(ms_since_wdt > WATCHDOG_MS) {
        if(expect_reset) {
            longjmp(chip_reset, RESET_BY_WATCHDOG);
        }
        printf("  hardware watchdog would reset the chip (%.0f ms without wdt_reset)\n",
               ms_since_wdt);
        failures++;
        longjmp(chip_reset, RESET_BY_WATCHDOG);
    }
}

void host_cli(void)
{
    longjmp(chip_reset, RESET_BY_CLI);
}

/* Moves what the firmware queued for the UART into sent[], as the
 * data-register-empty interrupt would. */
static void drain(void)
{
    if(!(UCSR0B & (1 << UDRIE0))) {
        return;
    }
    sent[sent_count++] = UDR0;
    while(UCSR0B & (1 << UDRIE0)) {
        uint8_t queued = _tx.cnt;
        USART_UDRE_vect();
        if(queued > 1 && sent_count < (int)sizeof sent) {
            sent[sent_count++] = UDR0;
        }
    }
}

/* The answer to the last command: ACK, NACK, or 0 when there was none. */
static uint8_t last_command_result(void)
{
    for(int i = sent_count - 4; i >= 0; i--) {
        if(sent[i] == STX && sent[i + 1] == COMMANDRESULT && sent[i + 3] == ETX) {
            return sent[i + 2];
        }
    }
    return 0;
}

/* Sets what the firmware reads as input voltage, in tenths of a volt. */
static void voltage(int tenths)
{
    ADCRes[6] = (uint16_t)((tenths * 100 + 34) / 35);
}

/* A freshly started board with the ignition off, as main() leaves it. */
static void power_up(void)
{
    memset((void*)&_tx, 0, sizeof _tx);
    memset((void*)&_rx, 0, sizeof _rx);
    PINC = USB_PIN;
    PIND = DIG3_PIN | DIG2_PIN; /* pull-ups: inputs inactive */
    Init();
    my_eeprom_array[0] = 0x00; /* no debug output */
    my_eeprom_array[1] = 0x03;
    sendDebugMessages = false;
    powerOnTime = 3;
    systemState = STATE_IDLE;
    bootTimer = 0;
    late_count = 0;
    clock_ms = 0;
    ms_since_wdt = 0;
    sent_count = 0;
    expect_reset = false;
    voltage(132);
#ifndef OLD_FIRMWARE
    my_eeprom_array[2] = EEPROM_LAYOUT;
    my_eeprom_array[3] = 118;
    LoadSettings();
#endif
}

static void pass_ms(int ms)
{
    for(int i = 0; i < ms; i++) {
        Int1msCount++;
        MainLoop();
        drain();
        if(sent_count > (int)sizeof sent - 64) {
            sent_count = 0;
        }
    }
}

static void second(void)
{
    pass_ms(1001);
}

static void ignition(bool on)
{
    if(on) {
        PINC |= KL15_PIN;
    } else {
        PINC &= (uint8_t)~KL15_PIN;
    }
}

/* Ignition on until PIBOOT: display on, the Pi powered, boot timer running. */
static void boot_to_piboot(void)
{
    ignition(true);
    MainLoop();
    while(systemState == STATE_POWERON) {
        second();
    }
}

static void boot_to_run(void)
{
    boot_to_piboot();
    while(systemState == STATE_PIBOOT) {
        receive('+');
        second();
    }
}

/* Sends one command byte and runs the main loop; returns how the chip
 * ended up. */
static enum reset_cause command(uint8_t byte)
{
    receive(byte);
    int cause = setjmp(chip_reset);
    if(cause == NO_RESET) {
        MainLoop();
        drain();
    }
    return (enum reset_cause)cause;
}

/* --- Fault A: ignition off during PIBOOT ------------------------------- */

static void ignition_off_in_piboot_gives_the_pi_its_15_s_to_shut_down(void)
{
    power_up();
    boot_to_piboot();
    CHECK(systemState == STATE_PIBOOT);
    ignition(false);

    /* PIBOOT runs to its end, so a booting Pi is never cut off. */
    for(int s = 1; s < PI_BOOT_TIME - 1; s++) {
        receive('+');
        second();
    }
    CHECK(systemState == STATE_PIBOOT);
    CHECK(PORTB & RELAY_PI);

    int seconds = 0;
    while(systemState == STATE_PIBOOT && seconds++ < 5) {
        second();
    }
    /* Then the Pi gets its 15 s to shut down, as after RUN. */
    CHECK(systemState == STATE_POWEROFF);
    CHECK(powerOffTimer >= 14);
    CHECK(PORTB & RELAY_PI);
    CHECK(!(PORTB & RELAY_AMPLIFIER));

    for(int s = 0; s < 13; s++) {
        second();
    }
    CHECK(systemState == STATE_POWEROFF);
    CHECK(PORTB & RELAY_PI);
    seconds = 0;
    while(systemState == STATE_POWEROFF && seconds++ < 3) {
        second();
    }
    CHECK(systemState == STATE_IDLE);
    CHECK((PORTB & 7) == 0);
}

static void the_pi_halted_signal_ends_that_poweroff_early(void)
{
    power_up();
    boot_to_piboot();
    ignition(false);
    while(systemState == STATE_PIBOOT) {
        second();
    }
    CHECK(systemState == STATE_POWEROFF);
    PIND &= (uint8_t)~DIG3_PIN; /* gpio-poweroff: the Pi has halted */
    pass_ms(2);
    CHECK(systemState == STATE_IDLE);
    CHECK((PORTB & 7) == 0);
}

static void ignition_back_on_before_piboot_ends_goes_to_run(void)
{
    power_up();
    boot_to_piboot();
    ignition(false);
    for(int s = 0; s < 10; s++) {
        receive('+');
        second();
    }
    ignition(true);
    while(systemState == STATE_PIBOOT) {
        receive('+');
        second();
    }
    CHECK(systemState == STATE_RUN);
    CHECK(PORTB & RELAY_PI);
}

/* --- Fault B: one stray byte resets the chip --------------------------- */

static void a_lone_star_is_refused_without_a_reset(void)
{
    power_up();
    boot_to_run();
    uint8_t relays = PORTB;
    CHECK(command('*') == NO_RESET);
    CHECK(last_command_result() == NACK);
    CHECK(PORTB == relays);
    CHECK(powerOnTime == 3);
    CHECK(my_eeprom_array[1] == 3);
    CHECK(systemState == STATE_RUN);
}

static void star_and_digit_still_set_the_power_on_delay(void)
{
    power_up();
    receive('*');
    CHECK(command('5') == NO_RESET);
    CHECK(last_command_result() == ACK);
    CHECK(powerOnTime == 5);
    CHECK(my_eeprom_array[1] == 5);
}

static void a_digit_a_few_ms_late_still_counts(void)
{
    power_up();
    late[late_count++] = (struct late_byte){ 3, '7' };
    CHECK(command('*') == NO_RESET);
    CHECK(last_command_result() == ACK);
    CHECK(powerOnTime == 7);
}

static void star_with_an_invalid_digit_changes_nothing(void)
{
    power_up();
    receive('*');
    CHECK(command('0') == NO_RESET);
    CHECK(last_command_result() == NACK);
    CHECK(powerOnTime == 3);
    CHECK(my_eeprom_array[1] == 3);
}

static void a_stray_u_while_the_pi_runs_is_refused(void)
{
    uint8_t states_with_pi_power[] = { STATE_PIBOOT, STATE_RUN };
    for(unsigned i = 0; i < sizeof states_with_pi_power; i++) {
        power_up();
        if(states_with_pi_power[i] == STATE_PIBOOT) {
            boot_to_piboot();
        } else {
            boot_to_run();
        }
        uint8_t relays = PORTB;
        CHECK(command('U') == NO_RESET);
        CHECK(command('u') == NO_RESET);
        CHECK(last_command_result() == NACK);
        CHECK(PORTB == relays);
        CHECK(systemState == states_with_pi_power[i]);
    }

    /* POWEROFF too: the Pi is still shutting down. */
    power_up();
    boot_to_run();
    ignition(false);
    pass_ms(1100);
    CHECK(systemState == STATE_POWEROFF);
    CHECK(command('U') == NO_RESET);
    CHECK(PORTB & RELAY_PI);
}

static void u_with_the_pi_off_still_enters_the_bootloader(void)
{
    power_up();
    expect_reset = true;
    CHECK(command('U') == RESET_BY_CLI);

    power_up();
    ignition(true);
    MainLoop();
    CHECK(systemState == STATE_POWERON);
    expect_reset = true;
    CHECK(command('u') == RESET_BY_CLI);
}

/* --- What stays as it was ---------------------------------------------- */

/* --- C1: the ignition counts as off only after a second ---------------- */

static void a_short_ignition_dip_in_run_is_ignored(void)
{
    power_up();
    boot_to_run();
    receive('3');
    pass_ms(1);
    ignition(false);
    receive('+');
    pass_ms(500);
    ignition(true);
    for(int s = 0; s < 3; s++) {
        receive('+');
        second();
    }
    CHECK(systemState == STATE_RUN);
    CHECK(PORTB & RELAY_AMPLIFIER);
}

static void ignition_off_for_a_second_in_run_gives_15_s(void)
{
    power_up();
    boot_to_run();
    CHECK(PORTB & RELAY_PI);
    ignition(false);
    receive('+');
    pass_ms(KL15_OFF_DEBOUNCE_MS - 10);
    CHECK(systemState == STATE_RUN);
    pass_ms(20);
    CHECK(systemState == STATE_POWEROFF);
    CHECK(powerOffTimer >= 14);
    CHECK(!(PORTB & RELAY_AMPLIFIER));
}

static void a_short_ignition_dip_in_poweron_does_not_cancel(void)
{
    power_up();
    ignition(true);
    pass_ms(1);
    CHECK(systemState == STATE_POWERON);
    ignition(false);
    pass_ms(300);
    CHECK(systemState == STATE_POWERON);
    CHECK(PORTB & RELAY_DISPLAY);
    ignition(true);
    pass_ms(1);
    CHECK(systemState == STATE_POWERON);
    while(systemState == STATE_POWERON) {
        second();
    }
    CHECK(systemState == STATE_PIBOOT);
}

static void ignition_on_counts_at_once(void)
{
    power_up();
    ignition(true);
    pass_ms(1);
    CHECK(systemState == STATE_POWERON);
    CHECK(PORTB & RELAY_DISPLAY);
}

static void a_board_starting_with_the_ignition_off_stays_idle(void)
{
    power_up();
    pass_ms(1500);
    CHECK(systemState == STATE_IDLE);
    CHECK((PORTB & 7) == 0);
}

/* --- C2: no debug output unless switched on ---------------------------- */

#ifndef OLD_FIRMWARE
static void an_empty_eeprom_starts_without_debug_output(void)
{
    power_up();
    memset(my_eeprom_array, 0xFF, sizeof my_eeprom_array);
    LoadSettings();
    CHECK(!sendDebugMessages);
    CHECK(my_eeprom_array[0] == 0x00);
    CHECK(powerOnTime == 3);
    CHECK(my_eeprom_array[1] == 0x03);
}

static void a_module_flashed_from_v2_3_switches_debug_off_once(void)
{
    power_up();
    my_eeprom_array[0] = 0x01; /* debug on, as the old default left it */
    my_eeprom_array[1] = 0x05;
    my_eeprom_array[2] = 0xFF; /* never written before V2.4.0 */
    LoadSettings();
    CHECK(!sendDebugMessages);
    CHECK(my_eeprom_array[0] == 0x00);
    CHECK(my_eeprom_array[2] == EEPROM_LAYOUT);
    CHECK(powerOnTime == 5);

    /* Switched on again with '#', it stays on across restarts. */
    CHECK(command('#') == NO_RESET);
    CHECK(sendDebugMessages);
    LoadSettings();
    CHECK(sendDebugMessages);
    CHECK(my_eeprom_array[0] == 0x01);
}
#endif

static void the_watchdog_cuts_a_silent_pi_after_its_grace(void)
{
    power_up();
    boot_to_run();
    for(int s = 0; s < PI_ALIVE_ON_RUN - 1; s++) {
        second();
    }
    CHECK(systemState == STATE_RUN);
    second();
    CHECK(systemState == STATE_POWEROFF);
    CHECK(powerOffTimer == 5);
}

static void signs_of_life_keep_run_going(void)
{
    power_up();
    boot_to_run();
    for(int s = 0; s < 100; s++) {
        receive('+');
        second();
    }
    CHECK(systemState == STATE_RUN);
    CHECK(last_command_result() == ACK);
}

static void the_amplifier_relay_follows_3_and_6(void)
{
    power_up();
    boot_to_run();
    CHECK(command('3') == NO_RESET);
    CHECK(PORTB & RELAY_AMPLIFIER);
    CHECK(command('6') == NO_RESET);
    CHECK(!(PORTB & RELAY_AMPLIFIER));
}

static void the_version_answers(void)
{
    power_up();
    CHECK(command('v') == NO_RESET);
    CHECK(memmem(sent, sent_count, VERSION, strlen(VERSION)) != NULL);
}


/* --- C3: battery protection -------------------------------------------- */

#ifndef OLD_FIRMWARE
static void keep_alive_seconds(int seconds)
{
    for(int s = 0; s < seconds; s++) {
        receive('+');
        second();
    }
}

static void the_voltage_reads_as_set(void)
{
    power_up();
    voltage(118);
    CHECK(Get12Volt() / 100 == 118);
    voltage(117);
    CHECK(Get12Volt() / 100 == 117);
}

static void sixty_seconds_below_the_limit_shut_the_pi_down(void)
{
    power_up();
    boot_to_run();
    voltage(117);
    keep_alive_seconds(LOW_VOLTAGE_SECONDS - 2);
    CHECK(systemState == STATE_RUN);
    int seconds = 0;
    while(systemState == STATE_RUN && seconds++ < 4) {
        keep_alive_seconds(1);
    }
    CHECK(systemState == STATE_POWEROFF);
    CHECK(powerOffTimer >= 14);
    CHECK(!(PORTB & RELAY_AMPLIFIER));
    CHECK(PORTB & RELAY_PI);
}

static void at_the_limit_nothing_happens(void)
{
    power_up();
    boot_to_run();
    voltage(118);
    keep_alive_seconds(LOW_VOLTAGE_SECONDS + 10);
    CHECK(systemState == STATE_RUN);
}

static void cranking_dips_are_ignored(void)
{
    power_up();
    boot_to_run();
    for(int round = 0; round < 3; round++) {
        voltage(95); /* starter */
        keep_alive_seconds(LOW_VOLTAGE_SECONDS / 2);
        voltage(141); /* engine runs */
        keep_alive_seconds(2);
    }
    CHECK(systemState == STATE_RUN);
}

/* After a shutdown for low voltage the supply must not power the Pi up
 * again while the ignition stays on: that would drain the battery further. */
static void the_lock_keeps_the_pi_off_while_the_ignition_stays_on(void)
{
    power_up();
    boot_to_run();
    voltage(115);
    keep_alive_seconds(LOW_VOLTAGE_SECONDS + 2);
    CHECK(systemState == STATE_POWEROFF);
    int seconds = 0;
    while(systemState == STATE_POWEROFF && seconds++ < 20) {
        second();
    }
    CHECK(systemState == STATE_IDLE);
    /* Ten minutes later: still off, and the chip stays awake (no sleep,
     * whose watchdog reset would forget the lock). */
    for(int s = 0; s < 600; s++) {
        second();
    }
    CHECK(systemState == STATE_IDLE);
    CHECK((PORTB & 7) == 0);
}

static void ignition_off_lifts_the_lock(void)
{
    power_up();
    boot_to_run();
    voltage(115);
    keep_alive_seconds(LOW_VOLTAGE_SECONDS + 20);
    CHECK(systemState == STATE_IDLE);
    ignition(false);
    /* Unlocked and the ignition off, the chip goes to sleep; with USB power
     * that ends in a watchdog reset, as on the board. */
    expect_reset = true;
    int cause = setjmp(chip_reset);
    if(cause == NO_RESET) {
        pass_ms(KL15_OFF_DEBOUNCE_MS + 2100);
    }
    CHECK(cause == RESET_BY_CLI);
    CHECK(!lowVoltageLock);
    expect_reset = false;
    Init();
    LoadSettings();
    systemState = STATE_IDLE;
    ignition(true);
    pass_ms(2);
    CHECK(systemState == STATE_POWERON);
}

static void the_engine_running_lifts_the_lock(void)
{
    power_up();
    boot_to_run();
    voltage(115);
    keep_alive_seconds(LOW_VOLTAGE_SECONDS + 20);
    CHECK(systemState == STATE_IDLE);
    voltage(LOW_VOLTAGE_UNLOCK - 1);
    for(int s = 0; s < 5; s++) {
        second();
    }
    CHECK(systemState == STATE_IDLE);
    voltage(LOW_VOLTAGE_UNLOCK);
    second();
    second();
    CHECK(systemState == STATE_POWERON);
}

static void limit_zero_switches_the_protection_off(void)
{
    power_up();
    receive('B');
    receive('0');
    receive('0');
    CHECK(command('0') == NO_RESET);
    CHECK(last_command_result() == ACK);
    CHECK(my_eeprom_array[3] == 0);
    boot_to_run();
    voltage(100);
    keep_alive_seconds(LOW_VOLTAGE_SECONDS + 10);
    CHECK(systemState == STATE_RUN);
}

static void the_limit_is_set_with_b_and_three_digits(void)
{
    power_up();
    receive('B');
    receive('1');
    receive('2');
    CHECK(command('0') == NO_RESET);
    CHECK(last_command_result() == ACK);
    CHECK(my_eeprom_array[3] == 120);
    CHECK(lowVoltageLimit == 120);
    LoadSettings();
    CHECK(lowVoltageLimit == 120);

    /* Out of range or not digits: refused, nothing changes. */
    receive('B');
    receive('2');
    receive('0');
    CHECK(command('0') == NO_RESET);
    CHECK(last_command_result() == NACK);
    receive('B');
    receive('1');
    receive('x');
    CHECK(command('8') == NO_RESET);
    CHECK(last_command_result() == NACK);
    CHECK(my_eeprom_array[3] == 120);
}

static void a_lone_b_is_refused_without_a_reset(void)
{
    power_up();
    boot_to_run();
    uint8_t relays = PORTB;
    CHECK(command('B') == NO_RESET);
    CHECK(last_command_result() == NACK);
    CHECK(PORTB == relays);
    CHECK(my_eeprom_array[3] == 118);
}

static void an_old_module_gets_the_default_limit(void)
{
    power_up();
    my_eeprom_array[2] = 0xFF;
    my_eeprom_array[3] = 0xFF;
    LoadSettings();
    CHECK(my_eeprom_array[3] == 118);
    CHECK(lowVoltageLimit == 118);
}
#endif

#define RUN(test)                                                                                  \
    do {                                                                                           \
        int before = failures;                                                                     \
        if(setjmp(chip_reset) != NO_RESET) {                                                       \
            printf("  FAILED: the chip reset unexpectedly\n");                                     \
            failures++;                                                                            \
        } else {                                                                                   \
            test();                                                                                \
        }                                                                                          \
        printf("%s %s\n", failures == before ? "ok    " : "FAILED", #test);                         \
    } while(0)

int main(void)
{
    RUN(ignition_off_in_piboot_gives_the_pi_its_15_s_to_shut_down);
    RUN(the_pi_halted_signal_ends_that_poweroff_early);
    RUN(ignition_back_on_before_piboot_ends_goes_to_run);
    RUN(a_lone_star_is_refused_without_a_reset);
    RUN(star_and_digit_still_set_the_power_on_delay);
    RUN(a_digit_a_few_ms_late_still_counts);
    RUN(star_with_an_invalid_digit_changes_nothing);
    RUN(a_stray_u_while_the_pi_runs_is_refused);
    RUN(u_with_the_pi_off_still_enters_the_bootloader);
    RUN(a_short_ignition_dip_in_run_is_ignored);
    RUN(ignition_off_for_a_second_in_run_gives_15_s);
    RUN(a_short_ignition_dip_in_poweron_does_not_cancel);
    RUN(ignition_on_counts_at_once);
    RUN(a_board_starting_with_the_ignition_off_stays_idle);
#ifndef OLD_FIRMWARE
    RUN(an_empty_eeprom_starts_without_debug_output);
    RUN(a_module_flashed_from_v2_3_switches_debug_off_once);
#endif
#ifndef OLD_FIRMWARE
    RUN(the_voltage_reads_as_set);
    RUN(sixty_seconds_below_the_limit_shut_the_pi_down);
    RUN(at_the_limit_nothing_happens);
    RUN(cranking_dips_are_ignored);
    RUN(the_lock_keeps_the_pi_off_while_the_ignition_stays_on);
    RUN(ignition_off_lifts_the_lock);
    RUN(the_engine_running_lifts_the_lock);
    RUN(limit_zero_switches_the_protection_off);
    RUN(the_limit_is_set_with_b_and_three_digits);
    RUN(a_lone_b_is_refused_without_a_reset);
    RUN(an_old_module_gets_the_default_limit);
#endif
    RUN(the_watchdog_cuts_a_silent_pi_after_its_grace);
    RUN(signs_of_life_keep_run_going);
    RUN(the_amplifier_relay_follows_3_and_6);
    RUN(the_version_answers);
    printf("%d checks, %d failed\n", checks, failures);
    return failures == 0 ? 0 : 1;
}
