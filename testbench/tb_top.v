`timescale 1ns / 1ps

module tb_top;

    reg         clk;
    reg         rst_n;
    wire [31:0] pc;

    // 中断输入（虽然本测试未用，但保留以兼容顶层）
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
    integer i;  // 用于循环

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

        // 运行足够时间
        #5000;

        $display("\n========================================");
        $display("Simulation finished at time %t", $time);
        $display("x28 = 0x%h", u_cpu.reg_inst.regs[28]);

        #100;
        $display("=== imem content ===");
        for (i = 0; i < 16; i = i + 1) begin
            $display("mem[%0d] = %h", i, u_cpu.imem_inst.mem[i]);
        end

        if (u_cpu.reg_inst.regs[28] === 32'h5A5)
            $display(">>> TEST PASSED");
        else
            $display(">>> TEST FAILED");

        $finish;
    end

    // 每个周期打印信息
    always @(posedge clk) begin
        cycle = cycle + 1;
        #1;
        $display("Cycle %0d: PC=%h, instr=%h", cycle, pc, u_cpu.if_id_instr_reg);
        $display("  x28=%h, privilege=%d", u_cpu.reg_inst.regs[28], u_cpu.csr_inst.privilege);
        $display("  mstatus=%h, mepc=%h, mcause=%h",
                 u_cpu.csr_inst.mstatus, u_cpu.csr_inst.mepc, u_cpu.csr_inst.mcause);
        if (u_cpu.csr_inst.trap_taken) $display("  >>> trap taken");
    end

endmodule