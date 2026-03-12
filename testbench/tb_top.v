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
    integer i;          // 声明用于循环的变量

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
        $display("privilege = %d", u_cpu.csr_inst.privilege);
        $display("sstatus = 0x%h", u_cpu.csr_inst.sstatus);
        $display("sepc = 0x%h", u_cpu.csr_inst.sepc);
        $display("scause = 0x%h", u_cpu.csr_inst.scause);

        #100;
        $display("=== imem content ===");
        for (i=0; i<16; i=i+1) $display("mem[%0d] = %h", i, u_cpu.imem_inst.mem[i]);

        if (u_cpu.reg_inst.regs[28] === 32'h5A5)
            $display(">>> TEST PASSED");
        else
            $display(">>> TEST FAILED");

        $finish;
    end

always @(posedge clk) begin
    cycle = cycle + 1;
    #1;
    $display("  trap_pc=%h", u_cpu.csr_trap_pc);
    $display("Cycle %0d: PC=%h, instr=%h", cycle, pc, u_cpu.if_id_instr_reg);
    $display("  x28=%h, privilege=%d", u_cpu.reg_inst.regs[28], u_cpu.csr_inst.privilege);
    $display("  mtvec=%h, mepc=%h, mcause=%h", u_cpu.csr_inst.mtvec, u_cpu.csr_inst.mepc, u_cpu.csr_inst.mcause);
    $display("  sstatus=%h, sepc=%h, scause=%h",
             u_cpu.csr_inst.sstatus, u_cpu.csr_inst.sepc, u_cpu.csr_inst.scause);
    if (u_cpu.csr_inst.trap_taken) $display("  >>> trap taken");
    $display("  csr_wdata=%h, we=%b, csr_addr=%h, mscratch=%h",
             u_cpu.csr_wdata, u_cpu.id_ex_is_csr_reg,
             u_cpu.id_ex_csr_addr_reg, u_cpu.csr_inst.mscratch);
end

endmodule