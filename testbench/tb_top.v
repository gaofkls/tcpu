`timescale 1ns / 1ps

module tb_top;

    reg         clk;
    reg         rst_n;
    wire [31:0] pc;

    // 实例化你的处理器顶层模块（模块名 top）
    top u_cpu (
        .clk   (clk),
        .rst_n (rst_n),
        .pc    (pc)
    );

    // 时钟生成
    always #5 clk = ~clk;

    // 跟踪变量
    integer cycle = 0;
    reg [31:0] last_x5, last_x8, last_x11, last_x15, last_x16;
    reg [4:0]  load_rd;          // 记录最近进入 EX 的 load 指令的目标寄存器
    reg        load_in_ex;        // 标记当前是否有 load 在 EX 阶段

    initial begin
        $dumpfile("wave.vcd");
        $dumpvars(0, tb_top);

        clk   = 0;
        rst_n = 0;
        last_x5  = 0; last_x8  = 0; last_x11 = 0; last_x15 = 0; last_x16 = 0;
        load_rd = 0;
        load_in_ex = 0;

        #20 rst_n = 1;

        // 运行足够周期（程序约 30~40 个周期）
        #5000;

        $display("\n========================================");
        $display("Simulation finished at time %t", $time);
        $display("Final register values:");
        $display("x5  = %0d (expected 40)", u_cpu.reg_inst.regs[5]);
        $display("x8  = %0d (expected 105)", u_cpu.reg_inst.regs[8]);
        $display("x11 = %0d (expected 3)", u_cpu.reg_inst.regs[11]);
        $display("x15 = %0d (expected 15)", u_cpu.reg_inst.regs[15]);
        $display("x16 = %0d (expected 163)", u_cpu.reg_inst.regs[16]);

        if (u_cpu.reg_inst.regs[16] === 32'd163)
            $display("\n>>> TEST PASSED <<<\n");
        else
            $display("\n>>> TEST FAILED <<<\n");

        $finish;
    end

    // 每个时钟周期后打印详细流水线状态
    always @(posedge clk) begin
        cycle = cycle + 1;
        #1;  // 等待组合逻辑稳定

        $display("\n======== Cycle %0d ========", cycle);
        $display("PC = 0x%h", pc);

        // ---------- IF/ID ----------
        $display("IF/ID instr = 0x%h", u_cpu.if_id_instr_reg);

        // ---------- ID/EX ----------
        $display("ID/EX: rs1=%2d, rs2=%2d, rd=%2d",
                 u_cpu.id_ex_rs1_addr_reg, u_cpu.id_ex_rs2_addr_reg, u_cpu.id_ex_rd_addr_reg);
        $display("       ctrl: reg_write=%b, mem_to_reg=%b, mem_write=%b, branch=%b, jal=%b, jalr=%b",
                 u_cpu.id_ex_reg_write_reg, u_cpu.id_ex_mem_to_reg_reg,
                 u_cpu.id_ex_mem_write_reg, u_cpu.id_ex_branch_reg,
                 u_cpu.id_ex_jal_reg, u_cpu.id_ex_jalr_reg);
        $display("       forward_a=%d, forward_b=%d", u_cpu.forward_a, u_cpu.forward_b);

        // 检测 load 指令进入 EX
        if (u_cpu.id_ex_mem_to_reg_reg && u_cpu.id_ex_reg_write_reg) begin
            load_rd = u_cpu.id_ex_rd_addr_reg;
            load_in_ex = 1;
            $display(">>> LOAD instruction detected in EX, rd=x%d", load_rd);
        end else begin
            load_in_ex = 0;
        end

        // ---------- EX/MEM ----------
        $display("EX/MEM: alu_result=0x%h, rd_addr=%2d, branch_taken=%b, jump_taken=%b",
                 u_cpu.ex_mem_alu_result_reg, u_cpu.ex_mem_rd_addr_reg,
                 u_cpu.ex_mem_branch_taken_reg, u_cpu.ex_mem_jump_taken_reg);

        // ---------- MEM/WB ----------
        $display("MEM/WB: write_data=0x%h (from %s), rd_addr=%2d, reg_write=%b",
                 u_cpu.write_data,
                 (u_cpu.mem_wb_mem_to_reg_reg ? "MEM" : "ALU"),
                 u_cpu.mem_wb_rd_addr_reg,
                 u_cpu.mem_wb_reg_write_reg);

        // 打印目标寄存器的当前值
        $display("Regs: x5=%d, x8=%d, x11=%d, x15=%d, x16=%d",
                 u_cpu.reg_inst.regs[5], u_cpu.reg_inst.regs[8],
                 u_cpu.reg_inst.regs[11], u_cpu.reg_inst.regs[15],
                 u_cpu.reg_inst.regs[16]);

        // 检测重要寄存器的变化
        if (u_cpu.reg_inst.regs[5] !== last_x5) begin
            $display(">>> x5 changed to %d at cycle %d", u_cpu.reg_inst.regs[5], cycle);
            last_x5 = u_cpu.reg_inst.regs[5];
        end
        if (u_cpu.reg_inst.regs[8] !== last_x8) begin
            $display(">>> x8 changed to %d at cycle %d", u_cpu.reg_inst.regs[8], cycle);
            last_x8 = u_cpu.reg_inst.regs[8];
        end
        if (u_cpu.reg_inst.regs[11] !== last_x11) begin
            $display(">>> x11 changed to %d at cycle %d", u_cpu.reg_inst.regs[11], cycle);
            last_x11 = u_cpu.reg_inst.regs[11];
        end
        if (u_cpu.reg_inst.regs[15] !== last_x15) begin
            $display(">>> x15 changed to %d at cycle %d", u_cpu.reg_inst.regs[15], cycle);
            last_x15 = u_cpu.reg_inst.regs[15];
        end
        if (u_cpu.reg_inst.regs[16] !== last_x16) begin
            $display(">>> x16 changed to %d at cycle %d", u_cpu.reg_inst.regs[16], cycle);
            last_x16 = u_cpu.reg_inst.regs[16];
        end

        // 检测 load-use 停顿信号
        if (u_cpu.stall_if_id) $display(">>> STALL IF/ID active");
        if (u_cpu.flush_if_id) $display(">>> FLUSH IF/ID active");
        if (u_cpu.flush_id_ex) $display(">>> FLUSH ID/EX active");

        // 检查 load-use 相关：如果上一周期有 load 在 EX，且当前周期 ID/EX 的 rs1 或 rs2 等于 load_rd，应该产生停顿
        if (load_in_ex && (u_cpu.id_ex_rs1_addr_reg == load_rd || u_cpu.id_ex_rs2_addr_reg == load_rd)) begin
            $display(">>> LOAD-USE hazard detected: instruction in ID uses x%d (load result not ready)", load_rd);
            if (!u_cpu.stall_if_id)
                $display(">>> WARNING: Hazard detected but stall_if_id is NOT active!");
        end

        // 可选：检查内存
        // $display("dmem[0] = 0x%h", u_cpu.dmem_inst.mem[0]);
    end

endmodule