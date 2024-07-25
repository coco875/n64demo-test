
CC := gcc
MAKE = make
CFLAGS := -I . -Wall -Wextra -Wno-unused-parameter -pedantic -std=gnu11 -O2 -s

# Tools to compile
PROGRAMS := mio0 n64graphics displaylist_packer n64cksum tkmk00 extract_data_for_mio n64tool

all: armips $(PROGRAMS)

#==============================================================================#
# Source Files and Flags for Each Tool                                         #
#==============================================================================#

n64graphics_SOURCES := n64graphics.c utils.c
n64graphics_CFLAGS  := -DN64GRAPHICS_STANDALONE

displaylist_packer_SOURCES := displaylist_packer.c
displaylist_packer_CFLAGS  := -Wno-unused-result

mio0_SOURCES := libmio0.c
mio0_CFLAGS := -DMIO0_STANDALONE

tkmk00_SOURCES := libtkmk00.c utils.c
tkmk00_CFLAGS := -DTKMK00_STANDALONE

n64cksum_SOURCES := n64cksum.c utils.c
n64cksum_CFLAGS := -DN64CKSUM_STANDALONE

n64tool_SOURCES := n64tool.c
n64tool_CFLAGS :=

extract_data_for_mio_SOURCES := extract_data_for_mio.c

armips:
	mkdir build && cd build
	cmake -DCMAKE_BUILD_TYPE=Release ..
	cmake --build .


define COMPILE =
$(1): $($1_SOURCES)
	$(CC) $(CFLAGS) $($1_CFLAGS) $$^ -o $$@
endef

$(foreach p,$(PROGRAMS),$(eval $(call COMPILE,$(p))))
