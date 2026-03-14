`timescale 1ns / 1ps

module tb_top;

    reg         clk;
    reg         rst_n;
    wire [31:0] pc;

    reg int_soft, int_timer, int_ext;

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

    // 调试信号声明
    wire        id_ex_jal_reg = u_cpu.id_ex_jal_reg;
    wire        jump_taken = u_cpu.jump_taken;
    wire        ex_mem_jump_taken_reg = u_cpu.ex_mem_jump_taken_reg;
    wire [31:0] ex_mem_jump_target_reg = u_cpu.ex_mem_jump_target_reg;
    wire [31:0] target = u_cpu.target;
    wire [31:0] next_pc = u_cpu.next_pc;
    wire        flush_id_ex_orig = u_cpu.flush_id_ex_orig;
    wire        mmu_busy = u_cpu.mmu_busy;
    wire [31:0] if_id_instr_reg = u_cpu.if_id_instr_reg;
    wire        csr_flush = u_cpu.csr_flush;
    wire        id_ex_enable = u_cpu.id_ex_enable;
    wire [31:0] jump_target = u_cpu.jump_target;
    wire [31:0] id_ex_imm_reg = u_cpu.id_ex_imm_reg;
    wire [31:0] id_ex_pc_plus4 = u_cpu.id_ex_pc_plus4;
    wire        mem_wb_reg_write = u_cpu.mem_wb_reg_write_reg;
    wire [4:0]  mem_wb_rd_addr  = u_cpu.mem_wb_rd_addr_reg;
    wire [31:0] mem_wb_wr_data  = u_cpu.write_data;
    wire        timer_irq  = u_cpu.u_timer.irq_timer;
    wire [31:0] mtime      = u_cpu.u_timer.mtime;
    wire [31:0] mtimecmp   = u_cpu.u_timer.mtimecmp;
    wire [31:0] x10        = u_cpu.reg_inst.regs[10];
    // 新增存储相关信号
    wire        ex_mem_mem_write = u_cpu.ex_mem_mem_write_reg;
    wire        timer_we = u_cpu.timer_we;
    wire [31:0] dmem_addr = u_cpu.dmem_addr;
    wire [31:0] ex_mem_alu_result = u_cpu.ex_mem_alu_result_reg;
    wire [31:0] ex_mem_rs2_data = u_cpu.ex_mem_rs2_data_reg;

    reg         jal_detected = 0;
    reg [31:0]  jal_pc = 0;

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

        // 运行50个周期，足够观察 sw 指令
        #500;  // 50 cycles * 10ns = 500ns

        $display("\n========================================");
        $display("Simulation finished at time %t", $time);
        $display("x28 = 0x%h", u_cpu.reg_inst.regs[28]);
        $display("x8  = 0x%h", u_cpu.reg_inst.regs[8]);
        $finish;
    end

    always @(posedge clk) begin
        cycle = cycle + 1;
        #1;

        $display("Cycle %0d: PC=%h, instr=%h", cycle, pc, if_id_instr_reg);
        $display("  x28=%h, x8=%h", u_cpu.reg_inst.regs[28], u_cpu.reg_inst.regs[8]);
        $display("  MEM/WB reg_write=%b, rd_addr=%d, wr_data=0x%h", mem_wb_reg_write, mem_wb_rd_addr, mem_wb_wr_data);
        $display("  timer_irq=%b, mtime=%h, mtimecmp=%h, x10=%h", timer_irq, mtime, mtimecmp, x10);
        // 打印存储相关
        $display("  ex_mem_mem_write=%b, timer_we=%b, dmem_addr=%h, ex_mem_rs2_data=%h", 
                 ex_mem_mem_write, timer_we, dmem_addr, ex_mem_rs2_data);
        $display("  ex_mem_alu_result=%h", ex_mem_alu_result);
        $display("  imem[%0d] = %h", pc>>2, u_cpu.imem_inst.mem[pc>>2]);

        // 检测 JAL 指令（可选保留）
        if (if_id_instr_reg == 32'h0000006f) begin
            jal_detected <= 1;
            jal_pc <= pc;
            $display("  >>> JAL instruction detected at IF/ID, PC=%h", pc);
        end

        if (jal_detected) begin
            $display("  >>> Checking EX stage for JAL (detected at PC=%h)", jal_pc);
            $display("  ID/EX jal_reg=%b, EX jump_taken=%b, EX/MEM jump_taken_reg=%b", 
                     u_cpu.id_ex_jal_reg, jump_taken, ex_mem_jump_taken_reg);
            $display("  EX jump_target (comb)=%h", jump_target);
            jal_detected <= 0;
        end

        if (cycle >= 50) begin
            $display(">>> Reached 50 cycles, finishing early.");
            $finish;
        end
    end

endmodule