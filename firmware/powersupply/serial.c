/*
 * serial.c
 *
 * Created: 16.08.2017 04:29:48
 *  Author: michael.nenninger
 */

#include "serial.h"

#include <avr/interrupt.h>
#include <avr/io.h>
#include <util/delay.h>

#include "helper.h"

#ifndef INLINE
#define INLINE inline __attribute__((__always_inline__))
#endif
#ifndef NOINLINE
#define NOINLINE __attribute__((__noinline__))
#endif

#define UART_TX_BUF_MASK (UART_TX_BUF_SIZE - 1)
#define UART_RX_BUF_MASK (UART_RX_BUF_SIZE - 1)

static volatile struct {
    uint8_t in, out, cnt;
    uint8_t buf[UART_TX_BUF_SIZE];
} _tx;

static volatile struct {
    uint8_t in, out, cnt;
    uint8_t buf[UART_RX_BUF_SIZE];
} _rx;

void InitSerial()
{
    UCSR0A = 2;
    UCSR0B = 128 + 16 + 8; // Interrut On ?!?
    UCSR0C = 128 | 6;
    UBRR0H = 0;
    UBRR0L = 25; // 38400 BPS

    /*
    UBRRH = (F_CPU /(baudrate * 8L) - 1) >> 8;         				//High byte of UART speed
    UBRRL = (uint8_t)(F_CPU / (baudrate * 8L)-1);     				//Low byte of UART speed*/

    // Reset Buffers
    _tx.in = 0;
    _tx.out = 0;
    _tx.cnt = 0;

    _rx.in = 0;
    _rx.out = 0;
    _rx.cnt = 0;

    // BIT_SET(&UCSR0B,TXCIE0);
    // BIT_SET(&UCSR0B,UDRIE0);// activate uart data register empty interrupt
    BIT_SET(&UCSR0B, TXEN0);
}

// USART_UDRE_vect
// USART_TXC_vect
//(USART_TX_vect
SIGNAL(USART_UDRE_vect) // Data Send to PC or PI  Data Register Empty send next
{
    if(_tx.cnt > 0) {
        _tx.cnt--;
        if(_tx.cnt > 0) {
            UDR0 = _tx.buf[_tx.out];
            _tx.out = (_tx.out + 1) & UART_TX_BUF_MASK;
        }
    } else {
        // BIT_CLEAR(&UCSR0B,TXCIE0);
        BIT_CLEAR(&UCSR0B, UDRIE0); // activate uart data register empty interrupt
        // BIT_CLEAR(&UCSR0B,TXEN0);
        _tx.in = 0;
        _tx.out = 0;
        _tx.cnt = 0;
    }
}

SIGNAL(USART_RX_vect) // Received Data from PC or PI USART Rx Complete
{
    uint8_t tmp;
    _rx.buf[_rx.in] = UDR0;
    tmp = (_rx.in + 1) & UART_RX_BUF_MASK;
    if(tmp != _rx.out) {
        _rx.in = tmp;
        _rx.cnt++;
    }
}

NOINLINE bool SendByte(uint8_t const data)
{
    uint8_t retry = 0;
    bool good = true;
    while(_tx.cnt >= UART_TX_BUF_SIZE) {
        // buffer full we wait
        _delay_ms(1);
        retry++;
        if(retry == 4) {
            // Outbuffer Überlauf
            good = false;
            _tx.in = 0;
            _tx.out = 0;
            _tx.cnt = 0;
            break;
        }
    }

    // cli();
    ATOMIC_BLOCK(ATOMIC_FORCEON)
    {
        if(_tx.cnt) {
            _tx.buf[_tx.in] = data;
            _tx.in = (_tx.in + 1) & UART_TX_BUF_MASK;
        } else {
            BIT_SET(&UCSR0B, UDRIE0); // activate uart data register empty interrupt
            // BIT_SET(&UCSR0B,TXEN0);
            UDR0 = data;
        }
        _tx.cnt++;
    }
    // sei();

    return good;
}

void SendBytes(uint8_t* data, uint8_t size)
{
    uint8_t pos = 0;
    while(pos < 50 && pos < size)
        SendByte(data[pos++]);
}

void SendString(char text[50])
{
    SendString_(text);
    SendByte(13);
    SendByte(10);
}

void SendString_(char text[50])
{
    uint8_t pos;
    pos = 0;
    while(pos < 50 && text[pos] != 0)
        SendByte(text[pos++]);
}

INLINE uint8_t NewDataInAvailable()
{
    return _rx.cnt;
}

uint8_t GetDataIn()
{
    while(NewDataInAvailable() == 0) {
        _delay_ms(1);
    }

    uint8_t ch = 0;
    // cli();
    ATOMIC_BLOCK(ATOMIC_FORCEON)
    {
        if(_rx.cnt > 0) {
            ch = _rx.buf[_rx.out];
            _rx.out = (_rx.out + 1) & UART_RX_BUF_MASK;
            _rx.cnt--;
        }
    }
    // sei();
    return ch;
}

void WaitSendBufferEmpty()
{
    if(_tx.cnt > 0) {
        _delay_ms(1);
        if(_tx.cnt > 0) {
            _delay_ms(1);
        }
        if(_tx.cnt > 0) {
            _delay_ms(1);
        }
    }
}
