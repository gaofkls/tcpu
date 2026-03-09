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

    // 在每个时钟上升沿打印详细信息
    always @(posedge clk) begin
        $display("==================================================");
        $display("Cycle %0d at time %t", instr_count, $time);
        $display("PC = %h, instr = %h", pc, uut.instr);
        $display("Control: reg_write=%b, alu_src=%b, mem_write=%b, mem_to_reg=%b, branch=%b, alu_op=%b, imm_sel=%b",
                 uut.reg_write, uut.alu_src, uut.mem_write, uut.mem_to_reg, uut.branch, uut.alu_op, uut.imm_sel);
        $display("ALU: a=%h, b=%h, alu_ctrl=%b, result=%h, zero=%b",
                 uut.rs1_data, uut.alu_in2, uut.alu_ctrl, uut.alu_result, uut.zero);
        $display("Immediate: imm=%h", uut.imm);
        $display("Memory: mem_rdata=%h, mem_write=%b, mem_addr=%h, mem_wdata=%h",
                 uut.mem_rdata, uut.mem_write, uut.alu_result, uut.rs2_data);
        $display("Write back: write_data=%h", uut.write_data);
        $display("Registers: x1=%h, x2=%h, x3=%h", 
                 uut.reg_inst.regs[1], uut.reg_inst.regs[2], uut.reg_inst.regs[3]);
        $display("==================================================\n");
        instr_count = instr_count + 1;
    end

    // 结果检查
    initial begin
        #400;
        $display("Memory[0] = %h", uut.dmem_inst.mem[0]);
        if (uut.dmem_inst.mem[0] === 32'h00000037)
            $display("Test PASSED!");
        else
            $display("Test FAILED!");
        #10 $finish;
    end

endmodule