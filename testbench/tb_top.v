`timescale 1ns / 1ps

module tb_top;

    reg         clk;
    reg         rst_n;
    wire [31:0] pc;

    // 中断输入（本测试未用，但保留以兼容顶层）
    reg int_soft;
    reg int_timer;
    reg int_ext;

    top u_cpu (
        .clk      (clk),
        .rst_n    (rst_n),
        .int_soft (int_soft),
        .int_timer(int_timer),
        .int_ext  (int_ext),
        .pc       (pc)
    );

    always #5 clk = ~clk;

    integer cycle = 0;
    integer i;

    initial begin
        $dumpfile("wave.vcd");
        $dumpvars(0, tb_top);

        clk   = 0;
        rst_n = 0;
        int_soft  = 0;
        int_timer = 0;
        int_ext   = 0;

        #20;
        rst_n = 1;

        // 运行足够时间（根据新程序调整）
        #6000;

        $display("\n========================================");
        $display("Simulation finished at time %t", $time);
        $display("x28 = 0x%h", u_cpu.reg_inst.regs[28]);
        $display("x8  = 0x%h", u_cpu.reg_inst.regs[8]);
        $display("privilege = %d", u_cpu.csr_inst.privilege);
        $display("satp = 0x%h", u_cpu.csr_satp);
        $display("sstatus = 0x%h", u_cpu.csr_inst.sstatus);
        $display("sepc = 0x%h", u_cpu.csr_inst.sepc);
        $display("scause = 0x%h", u_cpu.csr_inst.scause);

        $display("=== imem content (first 16 words) ===");
        for (i=0; i<16; i=i+1) $display("mem[%0d] = %h", i, u_cpu.imem_inst.mem[i]);

        // 打印物理地址 0x800 处的内容（新测试程序使用的地址）
        $display("mem[0x800>>2] (addr 0x200) = %h", u_cpu.dmem_inst.mem[32'h800>>2]);

        // 验证结果
        if (u_cpu.reg_inst.regs[28] === 32'h5A5 && u_cpu.reg_inst.regs[8] === 32'h5A6) begin
            $display(">>> TEST PASSED");
        end else begin
            $display(">>> TEST FAILED");
            $display("x3 = 0x%h (expected 0x12345678)", u_cpu.reg_inst.regs[3]);
        end

        $finish;
    end

    // 每个周期打印关键信息（可注释掉以加快仿真）
    always @(posedge clk) begin
        cycle = cycle + 1;
        #1;
        $display("Cycle %0d: PC=%h, instr=%h", cycle, pc, u_cpu.if_id_instr_reg);
        $display("  x28=%h, x8=%h, privilege=%d", 
                 u_cpu.reg_inst.regs[28], u_cpu.reg_inst.regs[8], u_cpu.csr_inst.privilege);
        $display("  mtvec=%h, mepc=%h, mcause=%h", 
                 u_cpu.csr_inst.mtvec, u_cpu.csr_inst.mepc, u_cpu.csr_inst.mcause);
        $display("  sstatus=%h, sepc=%h, scause=%h",
                 u_cpu.csr_inst.sstatus, u_cpu.csr_inst.sepc, u_cpu.csr_inst.scause);
        $display("  satp=%h, mmu_paddr=%h, mmu_done=%b",
                 u_cpu.csr_satp, u_cpu.mmu_paddr, u_cpu.mmu_done);
        if (u_cpu.csr_inst.trap_taken) $display("  >>> trap taken");
        $display("  csr_wdata=%h, we=%b, csr_addr=%h, mscratch=%h",
                 u_cpu.csr_wdata, u_cpu.id_ex_is_csr_reg,
                 u_cpu.id_ex_csr_addr_reg, u_cpu.csr_inst.mscratch);
        // 新增调试：检查 MMU 内部状态（如果信号暴露在顶层）
        // $display("  mmu_state=%d", u_cpu.mmu_inst.state);
        $display("mem[0x3000>>2] = %h", u_cpu.dmem_inst.mem[32'h3000>>2]);
    end

endmodule