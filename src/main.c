#include "LPC11Uxx.h"
#include "uart.h"
#include <stdio.h>

#define BUFFERSIZE 100
volatile char UARTbuffer[ BUFFERSIZE ];
volatile uint32_t UARTbufferPtr = 0;

volatile uint32_t freq = 0;

int main(void)
{
	SystemCoreClockUpdate();
	
	// Enable clocks for GPIO and IOCON (both off on reset)
	LPC_SYSCON->SYSAHBCLKCTRL = (LPC_SYSCON->SYSAHBCLKCTRL & 0x098DFFFF) | (1<< 6) | (1<< 16);

	LPC_IOCON->PIO1_8  = 0x00000080;	// P1_8 to P1_11: no pull-up/-down, no hysteresis, no invert, no open-drain (default: pull-up)
	LPC_IOCON->PIO1_9  = 0x00000080;
	LPC_IOCON->PIO1_10 = 0x00000080;
	LPC_IOCON->PIO1_11 = 0x00000080;
	LPC_GPIO->DIR[1] = 0x00000F00;		// P1_8 to P1-11 as output

    // CMSIS interrupt config
    NVIC_SetPriority(TIMER_32_0_IRQn,0);	// Default priority group 0, can be 0(highest) - 3(lowest)
    NVIC_EnableIRQ(TIMER_32_0_IRQn);		// Enable 32-bit Timer0 Interrupt

	// Timer CT32B0: timer, rising PCLK, 1 kHz, match interrupt every 100 ms
	LPC_SYSCON->SYSAHBCLKCTRL = (LPC_SYSCON->SYSAHBCLKCTRL & 0x098DFFFF) | (1UL<<9);    // Enable clock for CT32B0 (default is disabled)
	LPC_CT32B0->CTCR = 0x00;	// Count Control Register: Counter/Timer Mode= b00 (timer, rising PCLK), bits [7:2] are not relevant for timer mode
	LPC_CT32B0->PR = 47999;		// Prescale register: 11999 for a frequency of 12000000/(11999+1) = 1000 Hz
	LPC_CT32B0->MCR = 0x0003;	// Match Control Register: MR0I + MR0R – interrupt and reset on MR0
	LPC_CT32B0->MR0 = 1000;		// Match Register 0: 500 ms for a period of 1 sec (on 0.5 secs, off 0.5 secs)
    LPC_CT32B0->MR1 = 0x00000000;
    LPC_CT32B0->MR2 = 0x00000000;
    LPC_CT32B0->MR3 = 0x00000000;
    LPC_CT32B0->CCR = 0x0000;	// Capture Control Register: not used (no capture, no interrupts)
    LPC_CT32B0->EMR = 0x0000;	// External Match Register: no external change on CT32B0_MATx pins on MRx match
	LPC_CT32B0->TCR = 0x0001;	// Timer Control Register: enable counter

	// PIO1_5/CT32B1_CAP1/DIP29 -> capture
	LPC_IOCON->PIO1_5 &= ~0x07;	// Clean FUNC bits
	LPC_IOCON->PIO1_5 |= 0x01;	// CT32B1_CAP1

	// Timer CT32B1: counter, rising CAP1 edge, no interrupts
	LPC_SYSCON->SYSAHBCLKCTRL = (LPC_SYSCON->SYSAHBCLKCTRL & 0x098DFFFF) | (1UL<< 10);    // Enable clock for CT32B1
	LPC_CT32B1->CCR = 0;			// No capture
	LPC_CT32B1->CTCR = 0b00000101;	// Configure CT32B1 as counter: CTM=1, CIS=1
	LPC_CT32B1->PR = 0;				// Prescaler 0
	LPC_CT32B1->MR0 = 0;
	LPC_CT32B1->MR1 = 0;
	LPC_CT32B1->MR2 = 0;
	LPC_CT32B1->MR3 = 0;
	LPC_CT32B1->MCR = 0;			// No match
	LPC_CT32B1->EMR = 0;			// No external match
	LPC_CT32B1->TCR = 0x0001;		// Enable	

	// USART
	UARTInit( 9600 );	// Even though 9600 baud is hard-coded in the UARTInit() method…

	// Get device ID and send Ready message on STDIO (=UART)
	uint32_t deviceID = LPC_SYSCON->DEVICE_ID;
	iprintf( "\033[32;1mConnected. Device ID: %lx\r\n\033[0m", deviceID );

	LPC_GPIO->PIN[1] |= (1<< 9);
	LPC_GPIO->PIN[1] |= (1<< 10);
	
	// Empty main loop
	while( 1 )
	{
		// Do we have a valid counter value?
		if( freq != 0 )
		{
			// Yes: print it and reset
			iprintf( "Frequency: %ld\r\n", freq );
			freq = 0;
		}
	}

	return 0;
}

/* CT32B0 interrupt handler.
 */
void TIMER32_0_IRQHandler(void)
{
	// Save CT32B1 counter value and reset
	freq = LPC_CT32B1->TC;
	LPC_CT32B1->TC = 0;

	LPC_GPIO->PIN[1] ^= (1<< 8);
	
   // Clear interrupt
	LPC_CT32B0->IR = (1UL<<0);
}

/* USART interrupt handler.
 * Since we have set only RBRINTEN in LPC_USART->IER we get only "data ready" interrupts and need not check for Receive Line Status etc.
 */
void UART_IRQHandler(void)
{
	// Get data into buffer. Reading RBR clears interrupt.
	UARTbuffer[ UARTbufferPtr++ ] = LPC_USART->RBR;
//	UARTSend( (uint8_t*)"2\r\n", 3 );
	freq = LPC_CT32B1->TC;
	iprintf( "Frequency: %ld\r\n", freq );

	return;
}