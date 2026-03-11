# test_umode.S
# 手动设置 mtvec，避免伪指令问题

    .section .text
    .globl _start

_start:
    # 设置 mtvec = trap_handler
    lui     t0, 0x0
    addi    t0, t0, 0x20
    csrw    mtvec, t0

    # 设置 mepc = umode_entry
    lui     t1, 0x0
    addi    t1, t1, 0x2c
    csrw    mepc, t1

    # 设置 mstatus.MPP = U (00)
    csrr    t2, mstatus
    li      t3, ~0x1800
    and     t2, t2, t3
    csrw    mstatus, t2

    # 执行 mret，切换到 U-mode
    mret

umode_entry:
    ecall
    j       .

trap_handler:
    li      x28, 0x5A5
    mret