.section .text
.globl _start

_start:
    # 设置 mtimecmp = mtime + 1000
    li t0, 0x2000000
    li t1, 0x2000004
    lw t2, 0(t0)
    li t3, 1000
    add t2, t2, t3
    sw t2, 0(t1)

    # 等待足够长时间（比如 2000 周期），然后直接设置成功
    li t4, 2000
wait:
    addi t4, t4, -1
    bnez t4, wait

    li x28, 0x5A5
    li x8, 0x5A6
done:
    j done