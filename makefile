##############################################################################################
# 
# On command line:
#
# make all = Create project
# make bin = Build and convert to binary file
# make size = Show size usage
# make objdump = Dump objects to objdump.txt
# make clean = Clean project files.
#
# To rebuild project do "make clean" and "make all".
#

##############################################################################################
# Start of user section
#

# Define project name and MCU here
PROJECT        = tcs3200
MCU			   = cortex-m0
SYSCALLS	   = 1

# Define linker script file here
LDSCRIPT = LPC11U24.ld

# List all user C define here, like -D_DEBUG=1
UDEFS = -D__USE_CMSIS

# Define ASM defines here
UADEFS = 

# List C source files here
SRC  = ./cmsis/core/core_cm0.c \
       ./cmsis/device/system_LPC11Uxx.c \
       ./src/startup_LPC11U24.c \
	   ./src/uart.c \
       ./src/main.c

# List ASM source files here
ASRC =

# List all user directories here
UINCDIR = ./inc \
		  ./src \
          ./cmsis/core \
          ./cmsis/device

# List the user directory to look for the libraries here
ULIBDIR =

# List all user libraries here
ULIBS = 

# Define optimisation level here
OPT = -O1

#
# End of user defines
##############################################################################################

##############################################################################################
# Start of default section
#

TRGT = arm-none-eabi-
CC   = $(TRGT)gcc
CP   = $(TRGT)objcopy
AS   = $(TRGT)gcc -x assembler-with-cpp
BIN  = $(CP) -O ihex 
ECHO = echo
CAT  = cat

# Use colors? (1/0)
USE_COLORS = 1

# List all default C defines here, like -D_DEBUG=1
DDEFS =

# List all default ASM defines here, like -D_DEBUG=1
DADEFS = 

# List all default directories to look for include files here
DINCDIR = 

# List the default directory to look for the libraries here
DLIBDIR =

# List all default libraries here
DLIBS = 

#
# End of default section
##############################################################################################


###
# Color definitions

NO_COLOR=\x1b[0m
OK_COLOR=\x1b[32;01m
ERROR_COLOR=\x1b[31;01;47m
WARN_COLOR=\x1b[33;01m

OK_STRING=$(OK_COLOR)[OK]$(NO_COLOR)
ERROR_STRING=$(ERROR_COLOR)[ERRORS]$(NO_COLOR)
WARN_STRING=$(WARN_COLOR)[WARNINGS]$(NO_COLOR)
DONE_STRING=$(OK_COLOR)[Done]$(NO_COLOR)

# End of color definitions
###

ifeq ($(SYSCALLS),1)
	SRC += ./src/syscalls.c
endif

INCDIR  = $(patsubst %,-I%,$(DINCDIR) $(UINCDIR))
LIBDIR  = $(patsubst %,-L%,$(DLIBDIR) $(ULIBDIR))

DEFS    = $(DDEFS) $(UDEFS) -DRUN_FROM_FLASH=1
ADEFS   = $(DADEFS) $(UADEFS)
OBJS    = $(ASRC:.s=.o) $(SRC:.c=.o)
LIBS    = $(DLIBS) $(ULIBS)
MCFLAGS = -mcpu=$(MCU)

ASFLAGS = $(MCFLAGS) -Wa,-amhls=$(<:.s=.lst) $(ADEFS)
CPFLAGS = $(MCFLAGS) $(OPT) -mthumb -fomit-frame-pointer -Wall -Wstrict-prototypes -fverbose-asm -Wa,-ahlms=$(<:.c=.lst) $(DEFS)
LDFLAGS = $(MCFLAGS) -mthumb -nostartfiles -T$(LDSCRIPT) -Wl,-Map=$(PROJECT).map,--cref,--no-warn-mismatch $(LIBDIR)

# Generate dependency information
CPFLAGS += -MD -MP -MF .dep/$(@F).d

#
# makefile rules
#

all: $(OBJS) $(PROJECT).elf $(PROJECT).hex

bin: $(OBJS) $(PROJECT).bin size clean-intermediates

size:
	@$(ECHO) Size:
	@arm-none-eabi-size $(PROJECT).elf

objdump:
	arm-none-eabi-objdump -x -d $(PROJECT).elf >objdump.txt

%.o : %.c
ifeq ($(USE_COLORS),1)
	@$(ECHO) -n Compiling $<…
	@$(CC) -c $(CPFLAGS) -I . $(INCDIR) $< -o $@ 2> temp.log || touch temp.errors
	@if test -e temp.errors; then $(ECHO) "$(ERROR_STRING)" && $(CAT) temp.log; elif test -s temp.log; then $(ECHO) "$(WARN_STRING)" && $(CAT) temp.log; else $(ECHO) "$(OK_STRING)"; fi;
	@rm -f temp.errors temp.log
else
	$(CC) -c $(CPFLAGS) -I . $(INCDIR) $< -o $@
endif

%.o : %.s
	$(AS) -c $(ASFLAGS) $< -o $@

%elf: $(OBJS)
ifeq ($(USE_COLORS),1)
	@$(ECHO) -n Linking $(OBJS)…
	@$(CC) $(OBJS) $(LDFLAGS) $(LIBS) -o $@ 2> temp.log || touch temp.errors
	@if test -e temp.errors; then $(ECHO) "$(ERROR_STRING)" && $(CAT) temp.log; elif test -s temp.log; then $(ECHO) "$(WARN_STRING)" && $(CAT) temp.log; else $(ECHO) "$(OK_STRING)"; fi;
	@rm -f temp.errors temp.log
else
	$(CC) $(OBJS) $(LDFLAGS) $(LIBS) -o $@
endif
  
%hex: %elf
ifeq ($(USE_COLORS),1)
	@$(ECHO) -n Copying $< to $@…
	@$(BIN) $< $@ 2> temp.log || touch temp.errors
	@if test -e temp.errors; then $(ECHO) "$(ERROR_STRING)" && $(CAT) temp.log; elif test -s temp.log; then $(ECHO) "$(WARN_STRING)" && $(CAT) temp.log; else $(ECHO) "$(OK_STRING)"; fi;
	@rm -f temp.errors temp.log
else
	$(BIN) $< $@
endif

%bin: %elf
ifeq ($(USE_COLORS),1)
	@$(ECHO) -n Copying $< to $@…
	@$(CP) -O binary $< $@ 2> temp.log || touch temp.errors
	@if test -e temp.errors; then $(ECHO) "$(ERROR_STRING)" && $(CAT) temp.log; elif test -s temp.log; then $(ECHO) "$(WARN_STRING)" && $(CAT) temp.log; else $(ECHO) "$(OK_STRING)"; fi;
	@rm -f temp.errors temp.log
	@$(ECHO) -n Generating checksum... $< to $@…
	@crc $@ 2> temp.log || touch temp.errors
	@if test -e temp.errors; then $(ECHO) "$(ERROR_STRING)" && $(CAT) temp.log; elif test -s temp.log; then $(ECHO) "$(WARN_STRING)" && $(CAT) temp.log; else $(ECHO) "$(OK_STRING)"; fi;
	@rm -f temp.errors temp.log
else
	$(CP) -O binary $< $@ 
	crc $@
endif

clean-intermediates:
	@$(ECHO) -n Removing intermediates…
	@rm -f $(SRC:.c=.c.bak)
	@rm -f $(SRC:.c=.lst)
	@rm -f $(ASRC:.s=.s.bak)
	@rm -f $(ASRC:.s=.lst)
	@rm -fR .dep
	@$(ECHO) "$(DONE_STRING)"

clean:
	@$(ECHO) -n Cleaning…
	@rm -f $(OBJS)
	@rm -f $(PROJECT).elf
	@rm -f $(PROJECT).map
	@rm -f $(PROJECT).hex
	@rm -f $(PROJECT).bin
	@rm -f $(SRC:.c=.c.bak)
	@rm -f $(SRC:.c=.lst)
	@rm -f $(ASRC:.s=.s.bak)
	@rm -f $(ASRC:.s=.lst)
	@rm -fR .dep
	@$(ECHO) "$(DONE_STRING)"

# 
# Include the dependency files, should be the last of the makefile
#
-include $(shell mkdir .dep 2>/dev/null) $(wildcard .dep/*)

# *** EOF ***