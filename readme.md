# NXP LPC11U24 – project scaffolding with timers, UART and GPIO
This project comprises a basic LPC11U24 project for the [Yagarto](http://www.yagarto.de) toolchain.

The project includes CMSIS and syscalls.c stubs for Newlib. The `_write_r` method has been modified to output to UART.

## Makefile
The included Makefile contains targets for compiling a binary file: `make bin` and for dumping the compiled ELF file to assembly code and memory map: `make objdump`.  
The Makefile uses an optional brief, colored output format. This can be disabled by setting the variable `USE_COLORS` to 0.

## Newlib, printf and syscalls
The project compiles using the [Yagarto](http://www.yagarto.de) toolchain which includes [Newlib](sourceware.org/newlib/).  
Newlib requires a couple of stubs to be implemented. This is done in `syscalls.c`. I'm using [Michael Fischer's implementation](www.yagarto.de/download/yagarto/syscalls.c) modified to redirect all output to UART.

Be aware that the complete implementation of `printf()` is rather large and will most likely _not_ fit in flash memory. So use the simpler, non-floating point version, `iprintf()` instead.

## UART
A simple UART driver is included based on NXP's LPC1114 UART driver example. It is not complete and is currently hardcoded for 9600 baud on a 48 MHz system clock and uses P1.26 and P1.27 for RX/TX.

All STDIO output is redirected to the UART. Make sure you call `UARTInit()` before calling `printf()`.

## Error in LPC11Uxx.h file
I had weird problems trying to use the CT32B1 timer together with CT32B0. It turns out that the CMSIS device header file, LPC11Uxx.h, contained an error.  
The register definitions for the two timers were this:

	#define LPC_CT32B0_BASE           (0x40014000)
	#define LPC_CT32B1_BASE           (0x40014000)
	
Both timers sharing the same address. Which is wrong. Changing the second line to:

	#define LPC_CT32B1_BASE           (0x40018000)
	
As per the manual, fixed everything.

## TAOS TCS3200D
In this project, the ARM MCU interfaces to an [TCS3200 color-to-frequency](http://www.ams.com/eng/Products/Light-Sensors/Color-Sensor/TCS3200) light sensor by using two 32 bit timers: one in timer mode generating a match interrupt at fixed intervals and the other in counter mode using pin P1.5/CT32B1_CAP1 connected to the TCS3200's output pin as counter input and counting on the rising edge. That way I count the frequency of the output.