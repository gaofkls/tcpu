.section .text
.globl _start
_start:
    la t0, trap_handler
    nop
    csrw mtvec, t0
    la t1, s_mode
    csrw sepc, t1
    csrr t2, mstatus
    li t3, ~0x1800
    and t2, t2, t3
    csrw mstatus, t2
    sret
s_mode:
    ecall
    j .
trap_handler:
    li x28, 0x5A5
    mret