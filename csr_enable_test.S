.section .text
.globl _start

_start:
    # 1. 使能定时器中断：mie[7] = 1
    li t0, 0x80
    csrw mie, t0

    # 2. 读取 mie 并验证
    csrr t1, mie
    li t2, 0x80
    bne t1, t2, fail

    # 3. 全局中断使能：mstatus.MIE = 1
    csrr t3, mstatus
    li t4, 0x8
    or t3, t3, t4
    csrw mstatus, t3

    # 4. 读取 mstatus 并验证 MIE 位
    csrr t5, mstatus
    andi t5, t5, 0x8   # 只保留 MIE 位
    li t6, 0x8
    bne t5, t6, fail

    # 成功
    li x28, 0x5A5
    li x8,  0x5A6
    j done

fail:
    li x28, 0xDEAD
    li x8,  0xBEEF

done:
    j done