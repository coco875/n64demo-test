# Default target
default: all

include util.mk

DEBUG ?= 1

GRUCODE   ?= f3dex2

# GRUCODE - selects which RSP microcode to use.
#   f3dex_old - default, version 0.95. An early version of F3DEX.
#   f3dex     - latest version of F3DEX, used on iQue and Lodgenet.
#   f3dex2    - F3DEX2, currently unsupported.
# Note that 3/4 player mode uses F3DLX
$(eval $(call validate-option,GRUCODE,f3dex_old f3dex f3dex2))

TARGET := demo

# Whether to hide commands or not
VERBOSE ?= 1
ifeq ($(VERBOSE),0)
  V := @
endif

ifeq ($(OS),Windows_NT)
    DETECTED_OS=windows
    # Set Windows temporary directory to its environment variable
    export TMPDIR=$(TEMP)
else
    UNAME_S := $(shell uname -s)
    ifeq ($(UNAME_S),Linux)
        DETECTED_OS=linux
    else ifeq ($(UNAME_S),Darwin)
        DETECTED_OS=macos
    endif
endif

# display selected options unless 'make clean' or 'make distclean' is run
ifeq ($(filter clean distclean,$(MAKECMDGOALS)),)
  $(info ==== Build Options ====)
  $(info Microcode:      $(GRUCODE))
  $(info Target:         $(TARGET))
  $(info =======================)
endif

N64_INST := /opt/libdragon

TOOLS_DIR := tools
N64CKSUM := $(TOOLS_DIR)/n64cksum
N64TOOL := $(TOOLS_DIR)/n64tool

# (This is a bit hacky, but a lot of rules implicitly depend
# on tools and assets, and we use directory globs further down
# in the makefile that we want should cover assets.)
ifeq ($(DETECTED_OS),windows)
# because python3 is a command to trigger windows store, and python on windows it's just called python
  ifneq ($(PYTHON),)
  else ifneq ($(call find-command,python),)
    PYTHON := python
  else ifneq ($(call find-command,python3),)
    PYTHON := python3
  endif
else
  PYTHON ?= python3
endif

DUMMY != $(PYTHON) --version || echo FAIL
ifeq ($(DUMMY),FAIL)
  $(error Unable to find python)
endif

ifeq ($(filter clean distclean print-%,$(MAKECMDGOALS)),)
   # Make tools if out of date
  DUMMY != make -C $(TOOLS_DIR)
  ifeq ($(DUMMY),FAIL)
    $(error Failed to build tools)
  endif
endif


# detect prefix for MIPS toolchain
ifneq ($(CROSS),)
else ifneq      ($(call find-command,$(N64_INST)/bin/mips64-elf-ld),)
  CROSS := $(N64_INST)/bin/mips64-elf-
else ifneq      ($(call find-command,mips-linux-gnu-ld),)
  CROSS := mips-linux-gnu-
else ifneq ($(call find-command,mips64-linux-gnu-ld),)
  CROSS := mips64-linux-gnu-
else ifneq ($(call find-command,mips64-elf-ld),)
  CROSS := mips64-elf-
else
  $(error Unable to detect a suitable MIPS toolchain installed)
endif

AS      := $(CROSS)as
CC      := $(CROSS)gcc
LD      := $(CROSS)ld
AR      := $(CROSS)ar
OBJDUMP := $(CROSS)objdump
OBJCOPY := $(CROSS)objcopy

#==============================================================================#
# Target Executable and Sources                                                #
#==============================================================================#

BUILD_DIR := build
ROM := $(BUILD_DIR)/$(TARGET).z64
ELF := $(BUILD_DIR)/$(TARGET).elf
LD_SCRIPT := $(TARGET).ld

INCLUDE_DIRS   := include lib/ultralib/include lib/ultralib/include/PR lib/ultralib/include/gcc
SRC_DIRS       := src src/gcc
ASM_DIRS       := asm

PRINT          ?= printf

ALL_DIRS := $(BUILD_DIR) $(addprefix $(BUILD_DIR)/,$(SRC_DIRS) $(ASM_DIRS))

ASM_FILE_ALREADY_IN_LD := asm/entry.s asm/rom_header.s

C_FILES := $(foreach dir,$(SRC_DIRS),$(wildcard $(dir)/*.c))
S_FILES := $(foreach dir,$(ASM_DIRS),$(wildcard $(dir)/*.s))

O_FILES := $(foreach file,$(C_FILES),$(BUILD_DIR)/$(file:.c=.o)) $(foreach file,$(S_FILES),$(BUILD_DIR)/$(file:.s=.o))

include lib/libreultra.mk

# Make sure build directory exists before compiling anything
DUMMY != mkdir -p $(ALL_DIRS)

LD_O_FILES := $(filter-out $(BUILD_DIR)/$(ASM_FILE_ALREADY_IN_LD:.s=.o),$(O_FILES))

FILE_LD_O :=

EXTENSION := .o(.text*);
FILE_LD_O += $(LD_O_FILES:.o=$(EXTENSION))
EXTENSION := .o(.data*);
FILE_LD_O += $(LD_O_FILES:.o=$(EXTENSION))
EXTENSION := .o(.rodata*);
FILE_LD_O += $(LD_O_FILES:.o=$(EXTENSION))
EXTENSION := .o(.bss*);
FILE_LD_O_BSS += $(LD_O_FILES:.o=$(EXTENSION))

DEP_FILES := $(O_FILES:.o=.d) $(BUILD_DIR)/$(LD_SCRIPT).d

define print
  @$(PRINT) "$(GREEN)$(1) $(YELLOW)$(2)$(GREEN) -> $(BLUE)$(3)$(NO_COL)\n"
endef

#==============================================================================#
# Compiler Options                                                             #
#==============================================================================#

ifeq ($(DEBUG), 1)
  OPT_FLAGS += -Os -ggdb
  DEFINES += DEBUG_MODE=1
else
  OPT_FLAGS += -O2
endif

MIPSISET     := -mips3

C_DEFINES := $(foreach d,$(DEFINES),-D$(d))
DEF_INC_CFLAGS := $(foreach i,$(INCLUDE_DIRS),-I$(i)) $(C_DEFINES) -nostdinc

# Prefer clang as C preprocessor if installed on the system
ifneq (,$(call find-command,clang))
  CPP      := clang
  CPPFLAGS := -E -P -x c -Wno-trigraphs $(DEF_INC_CFLAGS)
else ifneq (,$(call find-command,cpp))
  CPP      := cpp
  CPPFLAGS := -P -Wno-trigraphs $(DEF_INC_CFLAGS)
else
  $(error Unable to find cpp or clang)
endif

CFLAGS = -G 0 $(OPT_FLAGS) $(TARGET_CFLAGS) $(MIPSISET) $(DEF_INC_CFLAGS) -mno-shared -march=vr4300 -mfix4300 -mabi=32 -mhard-float \
   -mdivide-breaks -fno-stack-protector -fno-common -fno-zero-initialized-in-bss -fno-PIC -mno-abicalls -fno-strict-aliasing -fno-inline-functions          \
   -ffreestanding -fwrapv -Wall -Wextra -ffast-math -fno-unsafe-math-optimizations

ASFLAGS = -march=vr4300 -mabi=32 -non_shared -I $(BUILD_DIR) $(VERSION_ASFLAGS) $(foreach d,$(DEFINES),--defsym $(d))

LDFLAGS = -T undefined_syms.txt -T $(BUILD_DIR)/$(LD_SCRIPT) -Map $(BUILD_DIR)/$(TARGET).map --no-check-sections -g

all: $(ROM)

$(BUILD_DIR)/%.o: %.c
	$(call print,Compiling:,$<,$@)
	$(V)$(CC) -c $(CFLAGS) -o $@ $<
	$(V)$(PYTHON) $(TOOLS_DIR)/set_o32abi_bit.py $@

$(BUILD_DIR)/%.o: %.s
	$(V)$(AS) $(ASFLAGS) -o $@ $<

# Run linker script through the C preprocessor
$(BUILD_DIR)/$(LD_SCRIPT): $(LD_SCRIPT)
	$(call print,Preprocessing linker script:,$<,$@)
	$(file > $(BUILD_DIR)/file_ld_o.inc.ld,$(FILE_LD_O))
	$(file > $(BUILD_DIR)/file_ld_o_bss.inc.ld,$(FILE_LD_O_BSS))
	$(V)$(CPP) $(CPPFLAGS) -Ibuild -DBUILD_DIR=$(BUILD_DIR) -MMD -MP -MT $@ -MF $@.d -o $@ $<

# Link MK64 ELF file
$(ELF): $(O_FILES) $(BUILD_DIR)/$(LD_SCRIPT) undefined_syms.txt
	@$(PRINT) "$(GREEN)Linking ELF file:  $(BLUE)$@ $(NO_COL)\n"
	$(V)$(LD) $(LDFLAGS) -o $@

# Build ROM
$(ROM): $(ELF)
	$(call print,Building ROM:,$<,$@)
	$(V)$(OBJCOPY) $(OBJCOPYFLAGS) $< $(@:.z64=.bin) -O binary
	$(V)$(N64CKSUM) $(@:.z64=.bin) $@

$(BUILD_DIR)/$(TARGET).hex: $(TARGET).z64
	$(V)xxd $< > $@

$(BUILD_DIR)/$(TARGET).objdump: $(ELF)
	$(V)$(OBJDUMP) -D $< > $@

run: $(ROM)
	flatpak run dev.ares.ares $(ROM)