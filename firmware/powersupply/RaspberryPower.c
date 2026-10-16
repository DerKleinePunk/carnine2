/*
 * RaspberryPowerSupply.c
 *
 * Created: 15.08.2017 08:22:24
 * Author : Marcus Borst
 * Author : Michael Nenninger
 */

#include <avr/eeprom.h>
#include <avr/interrupt.h>
#include <avr/io.h>
#include <avr/sleep.h>
#include <avr/wdt.h>
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>
#include <util/delay.h>

#include "helper.h"
#include "serial.h"

volatile uint32_t GlobalTime;
volatile uint8_t Int1msCount;
volatile uint8_t Int100msCount;
volatile uint8_t Int200msCount;
volatile uint16_t Int1000msCount;
volatile uint8_t Int10msCount;
volatile uint8_t Int25msCount;

volatile uint16_t ADCRes[8];
volatile uint32_t RunTime;

#define STATE_IDLE 0x00
#define STATE_POWERON 0x01
#define STATE_PIBOOT 0x02
#define STATE_RUN 0x03
#define STATE_POWEROFF 0x04

volatile uint8_t powerOnTimer = 0x00;
volatile uint8_t bootTimer = 0x00;
volatile uint8_t powerOffTimer = 0x00;
volatile uint8_t idleTimer = 0x00;
volatile uint8_t piAlive = 0x00;
// '+' received in this PIBOOT; only '+' counts, and only from the start of
// PIBOOT, so signs of life from the last run or line noise cannot end it
// before the Pi has booted.
volatile uint8_t piBootAlive = 0x00;
volatile uint8_t systemState = STATE_IDLE;
volatile uint8_t powerOnTime = 3;
// Milliseconds KL15 has been off without a break, up to KL15_OFF_DEBOUNCE_MS.
volatile uint16_t kl15OffMs = 0;
// Battery protection: limit in 0.1 V (0 = off), seconds below it in RUN, and
// the lock that keeps the Pi off after such a shutdown.
volatile uint8_t lowVoltageLimit = 118;
volatile uint8_t lowVoltageSeconds = 0;
volatile bool lowVoltageLock = false;

volatile bool sendDebugMessages = false;
volatile bool serviceMode = false;

uint8_t clearScreenCommand[4] = { 0x1B, 0x5B, '2', 'J' };
uint8_t resetDevice[2] = { 0x1B, 'c' };

// https://electronics.stackexchange.com/questions/100887/how-to-store-array-of-values-in-eeprom-of-atmega16-and-then-read-it-in-sequence#100898
// macro for easier usage
#define read_eeprom_byte(address) eeprom_read_byte((const uint8_t*)address)
#define write_eeprom_byte(address, value) eeprom_write_byte((uint8_t*)address, (uint8_t)value)
#define update_eeprom_byte(address, value) eeprom_update_byte((uint8_t*)address, (uint8_t)value)


// declare an eeprom array
// [0] debug output (0x00 off, 0x01 on), [1] power-on delay in s,
// [2] EEPROM_LAYOUT once the settings were brought up to V2.4.0,
// [3] battery protection limit in 0.1 V (0 = off).
uint8_t EEMEM my_eeprom_array[10] = { 0x00, 0x03, 0x02, 118 };

#define forever while(1)

// Protokoll Defs
#define STX 0x02
#define ETX 0x03
#define ACK 0x06
#define IDKL15 0x10
#define PIALIVECOUNT 0x11
#define SYSTEMSTATE 0x12
#define COMMANDRESULT 0x13
#define EXTERNVOLTAGE 0x14
#define NACK 0x15

#define VERSION "V2.4.1"

// Seconds the Pi gets to boot before the watchdog starts (was 30).
#define PI_BOOT_TIME 60
// Alive count on entering RUN: seconds of grace for the first alive (was 1).
#define PI_ALIVE_ON_RUN 3
// PIBOOT ends early once the Pi has sent this many '+' in it: the Pi is up,
// so RUN (watchdog, ignition off with 15 s, battery protection, amplifier)
// need not wait for the rest of PI_BOOT_TIME, which stays the longest wait.
#define PI_BOOT_ALIVE_TO_RUN 2
// KL15 counts as off only after this many milliseconds without a break: a
// dip from a loose contact or the starter must not shut the Pi down, and
// POWEROFF cannot be cancelled. On counts at once.
#define KL15_OFF_DEBOUNCE_MS 1000
// How long '*' waits for its digit; it follows at once on the line.
#define COMMAND_ARGUMENT_WAIT_MS 20
// Written to my_eeprom_array[2] once the settings were brought up to V2.4.0
// (debug output off once, see LoadSettings).
#define EEPROM_LAYOUT 0x02
// Battery protection: in RUN, this many seconds in a row below the limit
// (EEPROM [3], 0.1 V, default 11.8 V, 'B' + three digits) start POWEROFF.
// The engine running keeps the voltage above ~13.2 V, so it only trips with
// the engine off; the starter's dip lasts seconds. Afterwards the supply
// stays off until the ignition was off or the voltage reaches
// LOW_VOLTAGE_UNLOCK (engine started), or it would power the Pi up again at
// once and drain the battery further.
#define LOW_VOLTAGE_SECONDS 60
#define LOW_VOLTAGE_DEFAULT 118
#define LOW_VOLTAGE_MIN 90
#define LOW_VOLTAGE_MAX 140
#define LOW_VOLTAGE_UNLOCK 130

SIGNAL(TIMER0_COMPA_vect) // Global Timer, 1000 Hz
{
    GlobalTime++;
    Int1msCount++;
}

SIGNAL(ADC_vect)
{
    volatile uint16_t Temp;

    Temp = ADCL;
    Temp = Temp + (ADCH << 8);
    ADCRes[ADMUX & 7] = Temp;

    ADMUX = ((ADMUX & (192 + 7)) + 1) & 199;
    ADCSRA = ADCSRA | 64;
}

SIGNAL(WDT_vect)
{
}

void SwitchGreenLed()
{
    PORTD = PORTD ^ 128; // Green LED
    // SETBIT(PORTD,UDRIE0)
}

void InitGlobalVariables()
{
    powerOffTimer = 0;
    powerOnTimer = 0;
    idleTimer = 30;
    piAlive = 0;
    kl15OffMs = KL15_OFF_DEBOUNCE_MS; // off until seen on
    lowVoltageSeconds = 0;
    lowVoltageLock = false;
    GlobalTime = 0;
    Int1msCount = 0;
    Int1000msCount = 0;
    Int100msCount = 0;
    Int10msCount = 0;
    Int25msCount = 0;
    serviceMode = false;
}

void InitIO()
{
    PORTD = 3;
    BIT_CLEAR(&DDRD, 4); // Dig3 Input
    BIT_SET(&PORTD, 4); // Dig3 Pullup On
    BIT_CLEAR(&DDRD, 5); // Dig2 Input
    BIT_SET(&PORTD, 5); // Dig2 Pullup On
    DDRD = 128 + 2;
    PORTC = 32 + 16; // Pin für selbst erhalt und KL15 setzen
    DDRC = 32;
    PORTB = 0;
    DDRB = 7;

    // Enbale Pin Change Interupt (Pin C4)
    // PCMSK1 |= (1 << PCINT12); // set PCINT12 to trigger an interrupt
    // PCICR |= (1 << PCIE1);     // set PCIE1 to enable PCMSK1 scan
}

void InitADC()
{
    ADMUX = 64;
    ADCSRA = 128 + 64 + 8 + 7;
}

void InitWDT()
{
    WDTCSR = 16 + 8;
    WDTCSR = 8 + 3;
    // wdt_enable(WDTO_2S);
}

void InitTimer()
{
    TCCR0A = 3;
    TCCR0B = 8 + 3;
    OCR0A = 125;
    TIMSK0 = 2;
}

void Init()
{
    InitIO();
    InitGlobalVariables();
    InitTimer();
    InitSerial();
    InitADC();
#ifndef DEBUG
    InitWDT();
#endif
    sei();
}

uint8_t USB_Connected()
{
    if((PINC & 0x1) == 1)
        return (1);
    else
        return (0);
}

void ResetTheChip()
{
    WDTCSR = 16 + 8;
    WDTCSR = 8 + 1;
    cli();
    while(1)
        ;
}

uint8_t KL15_Aktiv() // 1 if KL15 is 12V Pin C4
{
    if((PINC & 0x10) == 0)
        return (0);
    else
        return (1);
}

// KL15 debounced: on at once, off only after KL15_OFF_DEBOUNCE_MS.
uint8_t KL15_On()
{
    if(KL15_Aktiv() == 1 || kl15OffMs < KL15_OFF_DEBOUNCE_MS)
        return (1);
    else
        return (0);
}

bool Dig3On()
{
    // Invertieren 0 Activ
    if(bit_is_clear(PIND, PD4)) {
        return true;
    }
    return false;
}

bool Dig2On()
{
    // Invertieren 0 Activ
    if(bit_is_clear(PIND, PD5)) {
        return true;
    }
    return false;
}

// Controller put in sleep mode and Wait for Power on with Klemme 15 Pin C4
void SwitchOff()
{
    PORTC = PORTC & (255 - 32); // PORTC5 selbst erhalt in weg nehmen (Funktioniert nur wenn vom USB keine 5Volt kommen)
    if(USB_Connected() == 1) {
        set_sleep_mode(SLEEP_MODE_PWR_DOWN);
        sleep_enable();
        sleep_cpu();

        sleep_disable();
        if(KL15_Aktiv() == 1) {
            SendString("Wake Up");
        }

        ResetTheChip();
    } else {
        // Kondensator leer machen
        forever asm("WDR");
    }
}

uint16_t Get12Volt() // Result in 100mV
{
    return (ADCRes[6] * 35);
}

uint8_t GetAnalogInput(uint8_t Nr) // mV
{
    if(Nr >= 0 && Nr <= 2)
        return (ADCRes[Nr + 1] * 3300 / 1024);
    else
        return (0);
}

void SetRelaisOn(uint8_t Nr)
{
    if(Nr == 0) PORTB = PORTB | 1;
    if(Nr == 1) PORTB = PORTB | 2;
    if(Nr == 2) PORTB = PORTB | 4;
}

void SetRelaisOff(uint8_t Nr)
{
    if(Nr == 0) PORTB = PORTB & 254;
    if(Nr == 1) PORTB = PORTB & 253;
    if(Nr == 2) PORTB = PORTB & 251;
}

void Timer200ms()
{
    if(systemState == STATE_PIBOOT) {
        SwitchGreenLed();
    }
}

void Timer100ms()
{
    if(systemState == STATE_POWERON || systemState == STATE_POWEROFF) {
        SwitchGreenLed();
    }
}

void Timer10ms()
{
}

void Timer25ms()
{
}

void PrintStatusOnTerminal(bool resetScreen)
{
    if(resetScreen) {
        // Clear Screen VT100
        SendBytes(resetDevice, 2);
    }

    uint8_t kl15 = KL15_Aktiv();

    char s[10];
    memset(s, 0, 10);

    SendString_("KL15: ");
    itoa(kl15, s, 10);
    SendString(s);

    WaitSendBufferEmpty();

    SendString_("Spannung (0,1V): ");
    itoa(Get12Volt() / 100, s, 10);
    SendString(s);

    WaitSendBufferEmpty();

    SendString_("System State: ");
    switch(systemState) {
    case 0:
        SendString("IDLE");
        break;
    case 1:
        SendString("POWERON");
        break;
    case 2:
        SendString("PIBOOT");
        break;
    case 3:
        SendString("RUN");
        break;
    case 4:
        SendString("POWEROFF");
        break;
    default:
        SendString("Undefined");
    }

    WaitSendBufferEmpty();

    SendString_("Power on Timer: ");
    itoa(powerOnTimer, s, 10);
    SendString(s);

    WaitSendBufferEmpty();

    SendString_("Power on Time: ");
    itoa(powerOnTime, s, 10);
    SendString(s);

    WaitSendBufferEmpty();

    SendString_("Boot Timer: ");
    itoa(bootTimer, s, 10);
    SendString(s);

    WaitSendBufferEmpty();

    SendString_("Power off Timer: ");
    itoa(powerOffTimer, s, 10);
    SendString(s);

    WaitSendBufferEmpty();

    SendString_("Alive: ");
    itoa(piAlive, s, 10);
    SendString(s);

    WaitSendBufferEmpty();

    SendString_("Idle Timer: ");
    itoa(idleTimer, s, 10);
    SendString(s);

    WaitSendBufferEmpty();

    if(serviceMode) {
        SendString("Service Mode On");
    } else {
        SendString("Service Mode Off");
    }

    WaitSendBufferEmpty();

    if(Dig3On()) {
        SendString("Dig3 On");
    } else {
        SendString("Dig3 Off");
    }

    if(Dig2On()) {
        SendString("Dig2 On");
    } else {
        SendString("Dig2 Off");
    }

    WaitSendBufferEmpty();
}

void SendStatusToPi()
{
    char buffer[10];
    itoa(KL15_On(), buffer, 10);

    uint8_t telegram[4];
    telegram[0] = STX;
    telegram[1] = IDKL15;
    telegram[2] = buffer[0];
    telegram[3] = ETX;
    SendBytes(telegram, 4);

    itoa(piAlive, buffer, 10);
    telegram[0] = STX;
    telegram[1] = PIALIVECOUNT;
    SendBytes(telegram, 2);
    SendString_(buffer);
    telegram[0] = ETX;
    SendBytes(telegram, 1);

    itoa(systemState, buffer, 10);
    telegram[0] = STX;
    telegram[1] = SYSTEMSTATE;
    telegram[2] = buffer[0];
    telegram[3] = ETX;
    SendBytes(telegram, 4);

    itoa(Get12Volt() / 100, buffer, 10);
    telegram[0] = STX;
    telegram[1] = EXTERNVOLTAGE;
    SendBytes(telegram, 2);
    SendString_(buffer);
    telegram[0] = ETX;
    SendBytes(telegram, 1);
}

void Timer1000ms()
{
    if(systemState == STATE_RUN || systemState == STATE_IDLE) {
        // in  Other states the LED is blinking faster
        SwitchGreenLed();
    }

    RunTime++;

    uint16_t tenths = Get12Volt() / 100;
    if(systemState == STATE_RUN && lowVoltageLimit > 0 && tenths < lowVoltageLimit) {
        if(lowVoltageSeconds < 255) {
            lowVoltageSeconds++;
        }
    } else {
        lowVoltageSeconds = 0;
    }
    if(lowVoltageLock && (KL15_On() == 0 || tenths >= LOW_VOLTAGE_UNLOCK)) {
        lowVoltageLock = false;
    }

    if(systemState == STATE_POWERON && powerOnTimer < powerOnTime) {
        powerOnTimer++;
    } else if(systemState == STATE_RUN) {
        if(piAlive > 0 && serviceMode == false) {
            piAlive--;
        }
    } else if(systemState == STATE_POWEROFF) {
        if(powerOffTimer > 0) {
            powerOffTimer--;
        }

    } else if(systemState == STATE_IDLE) {
        if(idleTimer > 0) {
            idleTimer--;
        }
    } else if(systemState == STATE_PIBOOT) {
        if(bootTimer > 0) {
            bootTimer--;
        }
    }

    SendStatusToPi();
}

void Timer1ms()
{
    if(KL15_Aktiv() == 1) {
        kl15OffMs = 0;
    } else if(kl15OffMs < KL15_OFF_DEBOUNCE_MS) {
        kl15OffMs++;
    }

    Int1000msCount++;
    if(Int1000msCount > 1000) {
        Int1000msCount = 0;
        Timer1000ms();
    }
    Int200msCount++;
    if(Int200msCount > 200) {
        Int200msCount = 0;
        Timer200ms();
    }
    Int100msCount++;
    if(Int100msCount > 100) {
        Int100msCount = 0;
        Timer100ms();
    }
    Int25msCount++;
    if(Int25msCount > 25) {
        Int25msCount = 0;
        Timer25ms();
    }
    Int10msCount++;
    if(Int10msCount > 10) {
        Int10msCount = 0;
        Timer10ms();
    }
}


void SwitchToBootLoaderOperation()
{
    volatile long n;

    if(USB_Connected() == 1 && sendDebugMessages) {
        SendString("Reboot for Bootloader");
    }

    for(n = 0; n < 1000; n++)
        asm("WDR"); // Wait one moment

    ResetTheChip();
}

void Interpret(uint8_t Command)
{
    uint8_t response = NACK;
    bool bootloaderAllowed = systemState == STATE_IDLE || systemState == STATE_POWERON;
    if((Command == 'U' || Command == 'u') && bootloaderAllowed) {
        SwitchToBootLoaderOperation();
        return;
        // response = ACK;
    }
    if(sendDebugMessages) {
        SendString_("Command ");
        SendByte(Command);
        SendByte(13);
        SendByte(10);
        WaitSendBufferEmpty();
        PrintStatusOnTerminal(true);
    }
    if(Command == '1') {
        piAlive++;
        SetRelaisOn(0);
        response = ACK;
    } else if(Command == '2') {
        piAlive++;
        SetRelaisOn(1);
        response = ACK;
    } else if(Command == '3') {
        piAlive++;
        SetRelaisOn(2);
        response = ACK;
    } else if(Command == '4') {
        SetRelaisOff(0);
        response = ACK;
    } else if(Command == '5') {
        piAlive++;
        SetRelaisOff(1);
        response = ACK;
    } else if(Command == '6') {
        piAlive++;
        SetRelaisOff(2);
        response = ACK;
    } else if(Command == '+') {
        piAlive++;
        if(systemState == STATE_PIBOOT && piBootAlive < 255) {
            piBootAlive++;
        }
        response = ACK;
    } else if(Command == '$') {
        SetRelaisOff(2);
        piAlive++;
        systemState = STATE_POWEROFF;
        powerOffTimer = 15;
        response = ACK;
    } else if(Command == '#') {
        piAlive++;
        sendDebugMessages = !sendDebugMessages;
        if(sendDebugMessages) {
            update_eeprom_byte(&my_eeprom_array[0], 0x01);
        } else {
            update_eeprom_byte(&my_eeprom_array[0], 0x00);
        }
        response = ACK;
    } else if(Command == 'U' || Command == 'u') {
        // The reset into the bootloader drops every relay. Only while the Pi
        // has no power (IDLE, POWERON), so a stray 'U' cannot cut it off.
        if(sendDebugMessages) {
            SendString("Bootloader only while the Pi is off");
            WaitSendBufferEmpty();
        }
    } else if(Command == '*') {
        // A lone '*' (line noise) must not wait for ever: the hardware
        // watchdog would reset the chip and drop every relay.
        uint8_t digit = 0;
        if(GetDataInWithin(COMMAND_ARGUMENT_WAIT_MS, &digit)) {
            powerOnTime = digit - 0x30;
        } else {
            powerOnTime = 0;
        }
        if(powerOnTime > 0 && powerOnTime < 10) {
            if(sendDebugMessages) {
                SendString_("Set Power On Time to ");
                SendByte(powerOnTime + 0x30);
                SendByte(13);
                SendByte(10);
            }
            update_eeprom_byte(&my_eeprom_array[1], powerOnTime);
            response = ACK;
        } else {
            powerOnTime = read_eeprom_byte(&my_eeprom_array[1]);
        }
    } else if(Command == 'B') {
        // Battery protection limit: three digits in 0.1 V, "000" = off.
        uint8_t digits[3];
        uint16_t limit = 0;
        bool valid = true;
        for(uint8_t i = 0; i < 3 && valid; i++) {
            valid = GetDataInWithin(COMMAND_ARGUMENT_WAIT_MS, &digits[i]) && digits[i] >= '0' && digits[i] <= '9';
            limit = limit * 10 + (digits[i] - '0');
        }
        if(valid && (limit == 0 || (limit >= LOW_VOLTAGE_MIN && limit <= LOW_VOLTAGE_MAX))) {
            lowVoltageLimit = (uint8_t)limit;
            update_eeprom_byte(&my_eeprom_array[3], lowVoltageLimit);
            response = ACK;
        }
    } else if(Command == '!') {
        serviceMode = true;
        if(sendDebugMessages) {
            SendString("switch service mode disable watchdock");
            WaitSendBufferEmpty();
        }
        response = ACK;
    } else if(Command == '?') {
        serviceMode = false;
        if(sendDebugMessages) {
            SendString("enable watchdock");
            WaitSendBufferEmpty();
        }
        response = ACK;
    } else if(Command == 'v') {
        SendString(VERSION);
        response = ACK;
    } else {
        if(sendDebugMessages) {
            SendString_("Command unkown");
            SendByte(Command);
            SendByte(13);
            SendByte(10);
            WaitSendBufferEmpty();
        }
    }

    uint8_t telegram[5];
    telegram[0] = STX;
    telegram[1] = COMMANDRESULT;
    telegram[2] = response;
    telegram[3] = ETX;

    SendBytes(telegram, 4);

    if(piAlive > 3) {
        piAlive = 3;
    }
}

// Check Timers and UART then goto sleep
void MainLoop()
{
    if(Int1msCount > 0) {
        Timer1ms();
        Int1msCount--;
    }

    bool stateChanged = false;
    uint8_t kl15 = KL15_On();
    if(systemState == STATE_IDLE && kl15 == 1 && !lowVoltageLock) {
        systemState = STATE_POWERON;
        SetRelaisOn(0); // Power On Display and HDMI Spliter
        bootTimer = 0;
        stateChanged = true;

    } else if(systemState == STATE_POWERON && powerOnTimer < powerOnTime) {
        // Waiting for power on
        if(kl15 == 0) { // Cancel Power on
            systemState = STATE_IDLE;
            powerOnTimer = 0;
            bootTimer = 0;
            idleTimer = 2;
            SetRelaisOff(0);
            stateChanged = true;
        }
    } else if(systemState == STATE_POWERON && powerOnTimer == powerOnTime) {
        if(kl15 == 0) { // Cancel Power on
            systemState = STATE_IDLE;
            powerOnTimer = 0;
            bootTimer = 0;
            idleTimer = 2;
            SetRelaisOff(0);
            stateChanged = true;
        } else {
            systemState = STATE_PIBOOT;
            SetRelaisOn(1); // Power Raspberry
            powerOnTimer = 0;
            bootTimer = PI_BOOT_TIME;
            piBootAlive = 0;
            stateChanged = true;
        }
    } else if(systemState == STATE_PIBOOT && (bootTimer == 0 || piBootAlive >= PI_BOOT_ALIVE_TO_RUN)) {
        if(kl15 == 0) { // Cancel Power on
            // The Pi has booted by now: it gets the same 15 s to shut down
            // as from RUN. powerOffTimer was still 0 from the last POWEROFF,
            // which cut the Pi's power in the very next pass.
            SetRelaisOff(2);
            systemState = STATE_POWEROFF;
            powerOnTimer = 0;
            bootTimer = 0;
            powerOffTimer = 15;
            stateChanged = true;
        } else {
            systemState = STATE_RUN;
            powerOnTimer = 0;
            bootTimer = 25;
            if(piAlive < PI_ALIVE_ON_RUN) {
                piAlive = PI_ALIVE_ON_RUN;
            }
            stateChanged = true;
        }
    } else if(systemState == STATE_RUN) {
        if(piAlive == 0) { // Pi Hang crash it
            if(sendDebugMessages) {
                SendString("Alive time out !");
            }
            SetRelaisOff(2);
            powerOffTimer = 5;
            systemState = STATE_POWEROFF;
            stateChanged = true;
        } else if(kl15 == 0) { // Power off because Car Offline
            SetRelaisOff(2);
            systemState = STATE_POWEROFF;
            powerOnTimer = 0;
            bootTimer = 0;
            powerOffTimer = 15;
            stateChanged = true;
        } else if(lowVoltageSeconds >= LOW_VOLTAGE_SECONDS) { // Battery low, engine off
            if(sendDebugMessages) {
                SendString("Battery low !");
            }
            SetRelaisOff(2);
            systemState = STATE_POWEROFF;
            powerOnTimer = 0;
            bootTimer = 0;
            powerOffTimer = 15;
            lowVoltageSeconds = 0;
            lowVoltageLock = true;
            stateChanged = true;
        }
    } else if(systemState == STATE_POWEROFF && powerOffTimer > 0) {
        if(Dig3On()) {
            stateChanged = true;
            powerOffTimer = 0;
        }
    } else if(systemState == STATE_POWEROFF && powerOffTimer == 0) {
        SetRelaisOff(0);
        SetRelaisOff(1);
        SetRelaisOff(2);
        systemState = STATE_IDLE;
        idleTimer = 0;
        stateChanged = true;
    } else if(systemState == STATE_IDLE && idleTimer == 0 && !lowVoltageLock) {
        // Not while locked: the sleep ends in a watchdog reset, which would
        // forget the lock.
        if(sendDebugMessages) {
            SendString("Sleep");
            WaitSendBufferEmpty();
        }
        SwitchOff();
    }

    if(stateChanged && sendDebugMessages) {
        PrintStatusOnTerminal(true);
    }

    if(NewDataInAvailable() > 0) Interpret(GetDataIn());
    wdt_reset();
}

// Reads debug output and power-on delay from the EEPROM, writing defaults
// where nothing valid is stored. Flashing does not touch the EEPROM, so a
// module that ran V2.3.0 or older still has debug output on (the old
// default); the first start of V2.4.0 switches it off once, sets the
// battery protection limit to its default and marks the EEPROM with
// EEPROM_LAYOUT. '#' switches debug output on again for good.
void LoadSettings()
{
    if(read_eeprom_byte(&my_eeprom_array[2]) != EEPROM_LAYOUT) {
        update_eeprom_byte(&my_eeprom_array[0], 0x00);
        update_eeprom_byte(&my_eeprom_array[3], LOW_VOLTAGE_DEFAULT);
        update_eeprom_byte(&my_eeprom_array[2], EEPROM_LAYOUT);
    }
    uint8_t limit = read_eeprom_byte(&my_eeprom_array[3]);
    if(limit != 0 && (limit < LOW_VOLTAGE_MIN || limit > LOW_VOLTAGE_MAX)) {
        limit = LOW_VOLTAGE_DEFAULT;
        write_eeprom_byte(&my_eeprom_array[3], limit);
    }
    lowVoltageLimit = limit;
    // Read Debug Enabe from EEPROM
    if(read_eeprom_byte(&my_eeprom_array[0]) != 0x01 && read_eeprom_byte(&my_eeprom_array[0]) != 0x00) {
        write_eeprom_byte(&my_eeprom_array[0], 0x00);
    }
    // Read Power On Time from EEPROM
    if(read_eeprom_byte(&my_eeprom_array[1]) < 0x01 || read_eeprom_byte(&my_eeprom_array[1]) > 0x09) {
        write_eeprom_byte(&my_eeprom_array[1], 0x03);
    }

    // Todo How Detect Reset cam from WDT or not ?
    sendDebugMessages = read_eeprom_byte(&my_eeprom_array[0]) == 1;

    // Powerup PI Waiting time from Config
    powerOnTime = read_eeprom_byte(&my_eeprom_array[1]);
}

int main(void)
{
#ifdef DEBUG
    wdt_disable();
#endif
    Init();
    LoadSettings();
    systemState = STATE_IDLE;

    if(sendDebugMessages) {
        SendString_("Startup ");
        SendString(VERSION);
        PrintStatusOnTerminal(false);
    }
    forever MainLoop();
}
