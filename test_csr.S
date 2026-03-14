.section .text
.globl _start

_start:
    # 测试 mscratch 读写
    li x1, 0x12345678
    csrw mscratch, x1
    csrr x2, mscratch
    li x3, 0x12345678
    bne x2, x3, fail

    # 成功标志
    li x28, 0x5A5
    li x8, 0x5A6
    j done

fail:
    li x28, 0xDEAD
    li x8, 0xBEEF

done:
    j done