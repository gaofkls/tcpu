.section .text
.globl _start

_start:
    # 设置栈指针（可选）
    lui sp, 0x8
    addi sp, sp, 0

    # 测试 mtimecmp 读写
    li t0, 0x2000004       # mtimecmp 地址
    li t1, 0x12345678
    sw t1, 0(t0)           # 写入
    fence
    lw t2, 0(t0)           # 读出
    bne t1, t2, fail

    # 测试 mtime 读（不验证）
    li t0, 0x2000000
    lw t3, 0(t0)           # 读 mtime

    # 测试成功
    li x28, 0x5A5
    li x8, 0x5A6
    j done

fail:
    li x28, 0xDEAD
    li x8, 0xBEEF

done:
    j done