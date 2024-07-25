OUTPUT_ARCH (mips)

#define LINKER_MAIN        0x80000400

#define BEGIN_SEG(name, addr) \
    _##name##SegmentStart = ADDR(.name); \
    _##name##SegmentRomStart = __romPos; \
    .name addr : AT(__romPos)

#define END_SEG(name) \
    _##name##SegmentEnd = ADDR(.name) + SIZEOF(.name); \
    _##name##SegmentRomEnd = __romPos + SIZEOF(.name); \
    _##name##SegmentSize = SIZEOF(.name); \
    __romPos += SIZEOF(.name);

#define BEGIN_NOLOAD(name) \
    _##name##SegmentNoloadStart = ADDR(.name.noload); \
    .name.noload (NOLOAD) :
	
#define END_NOLOAD(name) \
    _##name##SegmentNoloadEnd = ADDR(.name.noload) + SIZEOF(.name.noload);

MEMORY
{
    ROM (rx) : ORIGIN = 0, LENGTH = 64M
    RAM (wx) : org = 0x08000000, len = 8M
}

SECTIONS
{
   __romPos = 0;

   BEGIN_SEG(boot, 0xA4000000)
   {
      BUILD_DIR/asm/rom_header.o(.text);
   }
   END_SEG(boot)

   /* 0x80000400 001000-0D9B70 [D8B70] */
   BEGIN_SEG(main, LINKER_MAIN) SUBALIGN(0x10)
   {
      BUILD_DIR/asm/entry.o(.text);
      #include "file_ld_o.inc.ld"
   }
   END_SEG(main)

   BEGIN_NOLOAD(main) {
      #include "file_ld_o_bss.inc.ld"
      . = ALIGN(0x10);
   }
   END_NOLOAD(main)

   /* Discard everything not specifically mentioned above. */
   /DISCARD/ :
   {
      *(*);
   }
}