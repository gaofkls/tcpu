.section .text
.globl _start

_start:
    # 设置栈指针
    lui sp, 0x8
    addi sp, sp, 0

    # 设置 mtvec 为 trap_handler
    la t0, trap_handler
    csrw mtvec, t0

    # 设置 mtimecmp = mtime + 1000
    li t1, 0x2000000
    li t2, 0x2000004
    lw t3, 0(t1)
    li t4, 1000
    add t3, t3, t4
    sw t3, 0(t2)

    # 使能定时器中断
    li t4, 0x80
    csrw mie, t4

    # 全局中断使能
    csrr t5, mstatus
    li t6, 0x8
    or t5, t5, t6
    csrw mstatus, t5

    # 无限循环，等待中断
loop:
    wfi
    j loop

trap_handler:
    # 保存上下文
    addi sp, sp, -16
    sw t0, 0(sp)
    sw t1, 4(sp)

    # 读取 mcause，验证是否为定时器中断
    csrr t0, mcause
    li t1, 0x80000007
    bne t0, t1, other_int

    # 设置成功标志
    li x28, 0x5A5
    li x9, 0x5A6

    # 清除中断（可选，重新设置 mtimecmp）
    li t1, 0x2000004
    lw t2, 0(t1)
    li t3, 1000
    add t2, t2, t3
    sw t2, 0(t1)

    j done_int

other_int:
    # 其他中断（略）

done_int:
    lw t0, 0(sp)
    lw t1, 4(sp)
    addi sp, sp, 16
    mret