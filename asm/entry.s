# assembler directives
.set noat      # allow manual use of $at
.set noreorder # don't insert nops after branches
.set gp=64

.include "include/macros.inc"

.text
glabel __start
	la $t0, _mainSegmentStart
    la $t1, _mainSegmentSize
bss_clear:
    addi $t1, $t1, -8
    sw $zero, ($t0)
    sw $zero, 4($t0)
    bnez $t1, bss_clear
	addi $t0, $t0, 8
    la $t2, boot #Boot function address
	la $sp, bootStack+0x2000 #Setup boot stack pointer, change stack size if needed here
    jr $t2
    nop
