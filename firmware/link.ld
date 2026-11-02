/* Code only; network data is placed by the exporter at 0x4000 and up (BOARD_FORMAT.md). */
ENTRY(_start)
MEMORY { CODE (rx) : ORIGIN = 0x0000, LENGTH = 0x4000 }
SECTIONS
{
    .text : { *(.text.start) *(.text*) *(.rodata*) } > CODE
    /DISCARD/ : { *(.eh_frame*) *(.comment) *(.riscv.attributes) }
}
