/*
 * serial.h
 *
 * Created: 16.08.2017 04:30:50
 *  Author: michael.nenninger
 */

#include <stdbool.h>
#include <util/atomic.h>

#ifndef SERIAL_H_
#define SERIAL_H_

#define UART_TX_BUF_SIZE 128
#define UART_RX_BUF_SIZE 128

void InitSerial();
bool SendByte(uint8_t const Data);
void SendBytes(uint8_t* data, uint8_t size);
void SendString(char s[50]);
void SendString_(char s[50]);
uint8_t NewDataInAvailable();
uint8_t GetDataIn();
void WaitSendBufferEmpty();

#endif /* SERIAL_H_ */
