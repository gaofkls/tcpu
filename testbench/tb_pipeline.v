`timescale 1ns / 1ps

module tb_pipeline();

    reg clk;
    reg rst_n;
    wire [31:0] pc;

    riscv_cpu_pipeline uut (
        .clk(clk),
        .rst_n(rst_n),
        .pc(pc)
    );

    always #5 clk = ~clk;

    initial begin
        $dumpfile("pipeline.vcd");
        $dumpvars(0, tb_pipeline);
    end

    initial begin
        clk = 0;
        rst_n = 0;
        #15 rst_n = 1;
        #1000 $finish;
    end

    integer cycle;
    initial cycle = 0;
    always @(posedge clk) begin
        $display("x1=%h, x2=%h, x3=%h, x4=%h, x5=%h, x6=%h, x7=%h", 
         uut.reg_inst.regs[1], uut.reg_inst.regs[2], uut.reg_inst.regs[3],
         uut.reg_inst.regs[4], uut.reg_inst.regs[5], uut.reg_inst.regs[6],
         uut.reg_inst.regs[7]);
        $display("========== Cycle %0d ==========", cycle);
        $display("PC = %h", pc);
        $display("x1 = %h, x2 = %h, x3 = %h", uut.reg_inst.regs[1], uut.reg_inst.regs[2], uut.reg_inst.regs[3]);
        $display("forward_a=%b, forward_b=%b", uut.forward_a, uut.forward_b);
$display("alu_src1=%h, alu_src2_rs2=%h", uut.alu_src1, uut.alu_src2_rs2);
$display("ex_mem_rd=%d, ex_mem_alu=%h, ex_mem_regwrite=%b", uut.ex_mem_rd_addr_reg, uut.ex_mem_alu_result_reg, uut.ex_mem_reg_write_reg);
$display("mem_wb_rd=%d, mem_wb_alu=%h, mem_wb_regwrite=%b", uut.mem_wb_rd_addr_reg, uut.mem_wb_alu_result_reg, uut.mem_wb_reg_write_reg);
$display("id_ex_rs1=%d, id_ex_rs2=%d", uut.id_ex_rs1_addr_reg, uut.id_ex_rs2_addr_reg);
$display("if_id_instr=%h, rs1_field=%d", uut.if_id_instr_reg, uut.if_id_instr_reg[19:15]);
        cycle = cycle + 1;
    end

    initial begin
        #900;
        $display("\n======= Final Check =======");
        $display("Memory[0]  = %h", uut.dmem_inst.mem[0]);
        $display("Memory[4]  = %h", uut.dmem_inst.mem[1]);
        $display("Memory[8]  = %h", uut.dmem_inst.mem[2]);
        $display("Memory[12] = %h", uut.dmem_inst.mem[3]);
        if (uut.dmem_inst.mem[1] === 32'h0000005A &&
            uut.dmem_inst.mem[2] === 32'h00000002 &&
            uut.dmem_inst.mem[3] === 32'h00000004)
            $display("Test PASSED!");
        else
            $display("Test FAILED!");
        #10 $finish;
    end

endmodule