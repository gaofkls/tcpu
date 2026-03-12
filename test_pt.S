# test_pt.S
# 设置 satp，建立一级页表（假设页表放在物理地址 0x1000）
# 虚拟地址 0x2000 映射到物理地址 0x8000

    .section .text
    .globl _start

_start:
    # 设置页表（在物理地址 0x1000 处）
    li      t0, 0x1000
    # 一级页表项（指向二级页表 0x2000，且有效）
    li      t1, 0x2001          # PPN=0x2000, V=1, R=W=X=0 (指向二级)
    sw      t1, 0(t0)           # 写入一级页表第0项（对应 VPN[1]=0）

    # 二级页表（在物理地址 0x2000 处）
    li      t0, 0x2000
    # 二级页表项（映射 0x2000 -> 0x8000，R=W=1）
    li      t1, 0x8000 | 0x1F   # PPN=0x800, R=1, W=1, X=0, U=1, V=1
    sw      t1, 0(t0)           # 写入二级页表第0项（对应 VPN[0]=0）

    # 设置 satp（MODE=1, PPN=0x1000>>12 = 0x1）
    li      t0, 0x80001000      # MODE=1, PPN=0x1, ASID=0
    csrw    satp, t0

    # 测试虚拟地址 0x2000
    li      t1, 0x2000
    li      t2, 0x5A5
    sw      t2, 0(t1)           # 写入
    lw      t3, 0(t1)           # 读出
    # 将 t3 存入内存 0x3000（物理地址）
    li      t4, 0x3000
    sw      t3, 0(t4)

loop:
    j       loop