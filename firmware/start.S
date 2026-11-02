    .section .text.start
    .globl _start
_start:
    li sp, 0xFFFC
    call main
1:  j 1b
