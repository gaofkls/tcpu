`timescale 1ns / 1ps

module tb_top;

    reg         clk;
    reg         rst_n;
    wire [31:0] pc;

    top u_cpu (
        .clk   (clk),
        .rst_n (rst_n),
        .pc    (pc)
    );

    always #5 clk = ~clk;

    integer cycle = 0;

    initial begin
        $dumpfile("wave.vcd");
        $dumpvars(0, tb_top);

        clk   = 0;
        rst_n = 0;

        #20;
        rst_n = 1;

$display("=== imem content ===");
$display("imem[0] = %h", u_cpu.imem_inst.mem[0]);
$display("imem[1] = %h", u_cpu.imem_inst.mem[1]);
$display("imem[2] = %h", u_cpu.imem_inst.mem[2]);
$display("imem[3] = %h", u_cpu.imem_inst.mem[3]);
$display("imem[4] = %h", u_cpu.imem_inst.mem[4]);
$display("imem[5] = %h", u_cpu.imem_inst.mem[5]);
$display("imem[6] = %h", u_cpu.imem_inst.mem[6]);
$display("imem[7] = %h", u_cpu.imem_inst.mem[7]);
$display("imem[8] = %h", u_cpu.imem_inst.mem[8]);
$display("imem[9] = %h", u_cpu.imem_inst.mem[9]);

        // 运行足够周期
        #1000;

        $display("\n========================================");
        $display("Simulation finished at time %t", $time);
        $display("Final x28 = 0x%h", u_cpu.reg_inst.regs[28]);

        if (u_cpu.reg_inst.regs[28] === 32'h5A5) begin
            $display(">>> TEST PASSED");
        end else begin
            $display(">>> TEST FAILED");
        end

        $finish;
    end

always @(posedge clk) begin
    cycle = cycle + 1;
    #1;
    $display("Cycle %0d: PC=%h, instr=%h", cycle, pc, u_cpu.if_id_instr_reg);
    $display("  x1=%h, x2=%h, x3=%h, x5=%h", 
             u_cpu.reg_inst.regs[1], u_cpu.reg_inst.regs[2], 
             u_cpu.reg_inst.regs[3], u_cpu.reg_inst.regs[5]);
    $display("  id_ex_is_csr=%b, csr_op=%h, csr_addr=%h", 
             u_cpu.id_ex_is_csr_reg, u_cpu.id_ex_csr_op_reg, u_cpu.id_ex_csr_addr_reg);
    $display("  csr_wdata=%h, csr_rdata=%h", u_cpu.csr_wdata, u_cpu.csr_rdata);
    $display("  mem_wb_wb_sel=%b, mem_wb_csr_rdata=%h", 
             u_cpu.mem_wb_wb_sel_reg, u_cpu.mem_wb_csr_rdata_reg);
    if (u_cpu.id_ex_is_ecall_reg) $display("  >>> ecall in EX");
    if (u_cpu.csr_inst.trap_taken) $display("  >>> trap taken");
    if (u_cpu.csr_inst.mret_pending) $display("  >>> mret pending");
end
endmodule