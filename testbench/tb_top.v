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
    $display("Cycle %0d: PC=%h, instr=%h, x28=%h", 
             cycle, pc, u_cpu.if_id_instr_reg, u_cpu.reg_inst.regs[28]);
    $display("  mtvec=%h, mepc=%h, mcause=%h, trap_pc=%h", 
             u_cpu.csr_inst.mtvec, u_cpu.csr_inst.mepc, u_cpu.csr_inst.mcause, u_cpu.csr_trap_pc);
    $display("  ex_mem_jump_taken=%b, ex_mem_jump_target=%h, next_pc=%h",
             u_cpu.ex_mem_jump_taken_reg, u_cpu.ex_mem_jump_target_reg, u_cpu.next_pc);
    if (u_cpu.id_ex_is_ecall_reg) $display("  >>> ecall in EX");
    if (u_cpu.csr_inst.trap_taken) $display("  >>> trap taken");
    if (u_cpu.csr_inst.mret_pending) $display("  >>> mret pending");
    if (u_cpu.reg_inst.regs[28] != 0) $display("  *** x28 changed to 0x%h", u_cpu.reg_inst.regs[28]);
end
endmodule