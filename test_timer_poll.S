.section .text
.globl _start

_start:
    # 设置 mtimecmp = mtime + 1000
    li t0, 0x2000000          # mtime 地址
    li t1, 0x2000004          # mtimecmp 地址
    lw t2, 0(t0)              # 读当前 mtime
    li t3, 1000               # 增量
    add t2, t2, t3            # mtime + 1000
    sw t2, 0(t1)              # 写 mtimecmp

    # 轮询等待 mtime >= mtimecmp
wait:
    lw t4, 0(t0)              # 读 mtime (注意这里用 t0，不要用 t1 混淆)
    lw t5, 0(t1)              # 读 mtimecmp
    blt t4, t5, wait          # 如果 mtime < mtimecmp 则继续等待

    # 达到条件，设置通过标志
    li x28, 0x5A5
    li x8,  0x5A6
done:
    j done