TARGET = uc-fs-liam
.PHONY: bear clean

DEBUG = 1
OPT = -O0
# Build path
BUILD_DIR = build
C_SOURCES = $(wildcard F401RE/app/src/*.c)
C_SOURCES += $(wildcard F401RE/BSP/*.c)
C_SOURCES += $(wildcard uc-FS/Source/*.c)
C_SOURCES += $(wildcard uc-FS/Dev/SD/*.c)
C_SOURCES += $(wildcard uc-FS/Dev/SD/Card/*.c)
C_SOURCES += $(wildcard uc-FS/FAT/*.c)
C_SOURCES += $(wildcard uc-CPU/*.c)
C_SOURCES += $(wildcard uc-LIB/*.c)
C_SOURCES += \
uc-FS/OS/None/fs_os.c\
Cortex-Mv7/cpu_c.c \
uc-Clk/Source/clk.c \

ASM_SOURCES = startup_stm32f401xe.s
ASM_SOURCES +=  \
Cortex-Mv7/cpu_a.s \
# uc-LIB/Ports/lib_mem_a.s \

#######################################
# binaries
#######################################
PREFIX = arm-none-eabi-
# The gcc compiler bin path can be either defined in make command via GCC_PATH variable (> make GCC_PATH=xxx)
# either it can be added to the PATH environment variable.
CC = arm-none-eabi-gcc
AS = arm-none-eabi-gcc -x assembler-with-cpp
CP = arm-none-eabi-objcopy
SZ = arm-none-eabi-size
HEX = $(CP) -O ihex
BIN = $(CP) -O binary -S

# mcu
MCU = -mcpu=cortex-m4 -mthumb -mfpu=fpv4-sp-d16 -mfloat-abi=soft

# macros for gcc
# AS defines
AS_DEFS = 

# C defines
C_DEFS =  \
-DSTM32F401xE


# AS includes
AS_INCLUDES = 

# C includes
C_INCLUDES =  \
-Iuc-CPU \
-Iuc-FS \
-Iuc-LIB \
-ICortex-Mv7 \
-IF401RE/app/inc \
-ICfg \
-Iuc-Clk \



# compile gcc flags
ASFLAGS = $(MCU) $(AS_DEFS) $(AS_INCLUDES) $(OPT) -Wall -fdata-sections -ffunction-sections

CFLAGS += $(MCU) $(C_DEFS) $(C_INCLUDES) $(OPT) -Wall -fdata-sections -ffunction-sections

ifeq ($(DEBUG), 1)
CFLAGS += -g -gdwarf-2
endif


# Generate dependency information
CFLAGS += -MMD -MP -MF"$(@:%.o=%.d)"


#######################################
# LDFLAGS
#######################################
# link script
LDSCRIPT = STM32F401RETx_FLASH.ld

# libraries
LIBS = -lc -lm -lnosys 
LIBDIR = 
LDFLAGS = $(MCU) -specs=nano.specs -T$(LDSCRIPT) $(LIBDIR) $(LIBS) -Wl,-Map=$(BUILD_DIR)/$(TARGET).map,--cref -Wl,--gc-sections

# default action: build all
all: $(BUILD_DIR)/$(TARGET).elf $(BUILD_DIR)/$(TARGET).hex $(BUILD_DIR)/$(TARGET).bin


#######################################
# build the application
#######################################
# list of objects
OBJECTS = $(addprefix $(BUILD_DIR)/,$(notdir $(C_SOURCES:.c=.o)))
vpath %.c $(sort $(dir $(C_SOURCES)))
# list of ASM program objects
temp = $(ASM_SOURCES:.S=.o)
OBJECTS += $(addprefix $(BUILD_DIR)/,$(notdir $(temp:.s=.o)))

vpath %.s $(sort $(dir $(ASM_SOURCES)))
vpath %.S $(sort $(dir $(ASM_SOURCES)))


$(BUILD_DIR)/%.o: %.c Makefile STM32F401RETx_FLASH.ld | $(BUILD_DIR) 
	$(CC) -c $(CFLAGS) -Wa,-a,-ad,-alms=$(BUILD_DIR)/$(notdir $(<:.c=.lst)) $< -o $@

$(BUILD_DIR)/%.o: %.s Makefile STM32F401RETx_FLASH.ld | $(BUILD_DIR)
	$(AS) -c $(ASFLAGS) $< -o $@

$(BUILD_DIR)/%.o: %.S Makefile STM32F401RETx_FLASH.ld | $(BUILD_DIR)
	$(AS) -c $(ASFLAGS) $< -o $@

$(BUILD_DIR)/$(TARGET).elf: $(OBJECTS) Makefile STM32F401RETx_FLASH.ld
	$(CC) $(OBJECTS) $(LDFLAGS) -o $@
	$(SZ) $@

$(BUILD_DIR)/%.hex: $(BUILD_DIR)/%.elf | $(BUILD_DIR)
	$(HEX) $< $@
	
$(BUILD_DIR)/%.bin: $(BUILD_DIR)/%.elf | $(BUILD_DIR)
	$(BIN) $< $@	
	
$(BUILD_DIR):
	mkdir $@		

#######################################
# clean up
#######################################
clean:
	-rm -fR $(BUILD_DIR)
  
#######################################
# dependencies
#######################################
-include $(wildcard $(BUILD_DIR)/*.d)

bear:
	make clean
	bear -o build/compile_commands.json make -j4

debug:
	make bear
# 需要下载tmux
	tmux has-session -t test0 2>/dev/null && tmux kill-session -t test0 || true
	tmux new-session -d -s test0 'openocd -f interface/stlink.cfg -f target/stm32f4x.cfg -c init -c "halt" -c "flash write_image erase build/uc-fs-liam.bin 0x8000000" -c reset'
# 这里看你电脑的性能,因为gdb-server服务器要启动一会儿
	sleep 7
	arm-none-eabi-gdb -x init.gdb
format:
	find . -iname *.h -o -iname *.c | xargs clang-format -i
download:
	make bear
	openocd -f interface/stlink.cfg -f target/stm32f4x.cfg -c init -c "halt" -c "flash write_image erase build/uc-fs-liam.bin 0x8000000" -c "reset" -c "shutdown"