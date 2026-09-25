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
volatile uint8_t systemState = STATE_IDLE;
volatile uint8_t powerOnTime = 3;

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
uint8_t EEMEM my_eeprom_array[10] = { 0x01, 0x03, 0x00, 0x00 };

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

#define VERSION "V2.2.12"

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
    itoa(KL15_Aktiv(), buffer, 10);

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
    if(Command == 'U' || Command == 'u') {
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
    } else if(Command == '*') {
        powerOnTime = GetDataIn();
        powerOnTime = powerOnTime - 0x30;
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
    uint8_t kl15 = KL15_Aktiv();
    if(systemState == STATE_IDLE && kl15 == 1) {
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
            bootTimer = 30;
            stateChanged = true;
        }
    } else if(systemState == STATE_PIBOOT && bootTimer == 0) {
        if(kl15 == 0) { // Cancel Power on
            systemState = STATE_POWEROFF;
            powerOnTimer = 0;
            bootTimer = 0;
            stateChanged = true;
        } else {
            systemState = STATE_RUN;
            powerOnTimer = 0;
            bootTimer = 25;
            piAlive++;
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
    } else if(systemState == STATE_IDLE && idleTimer == 0) {
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

int main(void)
{
#ifdef DEBUG
    wdt_disable();
#endif
    Init();
    // Read Debug Enabe from EEPROM
    if(read_eeprom_byte(&my_eeprom_array[0]) != 0x01 && read_eeprom_byte(&my_eeprom_array[0]) != 0x00) {
        write_eeprom_byte(&my_eeprom_array[0], 0x01);
    }
    // Read Power On Time from EEPROM
    if(read_eeprom_byte(&my_eeprom_array[1]) < 0x01 || read_eeprom_byte(&my_eeprom_array[1]) > 0x09) {
        write_eeprom_byte(&my_eeprom_array[1], 0x03);
    }
    systemState = STATE_IDLE;

    // Todo How Detect Reset cam from WDT or not ?
    sendDebugMessages = read_eeprom_byte(&my_eeprom_array[0]) == 1;

    // Powerup PI Waiting time from Config
    powerOnTime = read_eeprom_byte(&my_eeprom_array[1]);

    if(sendDebugMessages) {
        SendString_("Startup ");
        SendString(VERSION);
        PrintStatusOnTerminal(false);
    }
    forever MainLoop();
}
