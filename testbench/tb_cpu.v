`timescale 1ns / 1ps

module tb_cpu();

    reg clk;
    reg rst_n;
    wire [31:0] pc;

    riscv_cpu_simple uut (
        .clk(clk),
        .rst_n(rst_n),
        .pc(pc)
    );

    always #5 clk = ~clk;

    initial begin
        $dumpfile("cpu.vcd");
        $dumpvars(0, tb_cpu);
    end

    initial begin
        clk = 0;
        rst_n = 0;
        #15 rst_n = 1;
        #500 $finish;
    end

    integer instr_count;
    initial instr_count = 0;

  always @(posedge clk) begin
        $display("==================================================");
        $display("Cycle %0d at time %t", instr_count, $time);
        $display("PC = %h, instr = %h", pc, uut.instr);
        $display("Control: reg_write=%b, alu_src=%b, mem_write=%b, branch=%b, alu_op=%b, imm_sel=%b, wb_sel=%b, alu_a_sel=%b",
                 uut.reg_write, uut.alu_src, uut.mem_write, uut.branch, uut.alu_op, uut.imm_sel, uut.wb_sel, uut.alu_a_sel);
        $display("ALU: a=%h, b=%h, alu_ctrl=%b, result=%h, zero=%b",
                 uut.alu_a, uut.alu_in2, uut.alu_ctrl, uut.alu_result, uut.zero);
        $display("Immediate: imm=%h", uut.imm);
        $display("Memory: mem_rdata=%h, mem_write=%b, mem_addr=%h, mem_wdata=%h",
                 uut.mem_rdata, uut.mem_write, uut.alu_result, uut.rs2_data);
        $display("Write back: write_data=%h", uut.write_data);
        $display("Registers: x1=%h, x2=%h, x3=%h, x4=%h, x5=%h, x9=%h, x10=%h, x12=%h", 
                 uut.reg_inst.regs[1], uut.reg_inst.regs[2], uut.reg_inst.regs[3],
                 uut.reg_inst.regs[4], uut.reg_inst.regs[5], uut.reg_inst.regs[9],
                 uut.reg_inst.regs[10], uut.reg_inst.regs[12]);
        $display("==================================================\n");
        instr_count = instr_count + 1;
    end

       // 在仿真结束时检查结果
   initial begin
    #400;
    $display("Memory[0] = %h", uut.dmem_inst.mem[0]);
    $display("Memory[4] = %h", uut.dmem_inst.mem[1]); // 可能未写入，仅供参考
    $display("x9 = %h", uut.reg_inst.regs[9]);
    $display("x12 = %h", uut.reg_inst.regs[12]);      // 应等于4
    if (uut.dmem_inst.mem[0] === 32'h12345678 && 
        uut.reg_inst.regs[9] === 32'h00000002 &&
        uut.reg_inst.regs[12] === 32'h00000004)
        $display("Test PASSED!");
    else
        $display("Test FAILED!");
    #10 $finish;
end

endmodule