module riscv_cpu_simple (
    input clk,
    input rst_n,
    output [31:0] pc
);
    // 内部信号
    wire [31:0] next_pc;
    wire [31:0] instr;
    wire [31:0] rs1_data, rs2_data;
    wire [31:0] imm;
    wire [31:0] alu_in2;
    wire [31:0] alu_result;
    wire [31:0] mem_rdata;
    wire [31:0] write_data;
    wire zero;
    wire br_taken;
    wire reg_write, alu_src, mem_write, branch, jal, jalr;
    wire [1:0] alu_op;
    wire [2:0] imm_sel;
    wire [3:0] alu_ctrl;
    wire [1:0] wb_sel;
    wire [1:0] alu_a_sel;
    wire [31:0] alu_a;   // 保持 wire

    // PC寄存器
    pc_reg pc_inst (
        .clk(clk), .rst_n(rst_n), .next_pc(next_pc), .pc(pc)
    );

    // 指令存储器
    imem imem_inst (
        .addr(pc), .instr(instr)
    );

    // 寄存器文件
    reg_file reg_inst (
        .clk(clk),
        .we(reg_write),
        .rs1_addr(instr[19:15]),
        .rs2_addr(instr[24:20]),
        .rd_addr(instr[11:7]),
        .rd_data(write_data),
        .rs1_data(rs1_data),
        .rs2_data(rs2_data)
    );

    // 立即数生成器
    imm_gen imm_inst (
        .instr(instr),
        .immsel(imm_sel),
        .imm(imm)
    );

    // 控制单元（新版本，无 mem_to_reg）
    control_unit ctrl_inst (
        .opcode(instr[6:0]),
        .funct3(instr[14:12]),
        .funct7(instr[31:25]),
        .reg_write(reg_write),
        .alu_src(alu_src),
        .mem_write(mem_write),
        .branch(branch),
        .jal(jal),
        .jalr(jalr),
        .alu_op(alu_op),
        .imm_sel(imm_sel),
        .wb_sel(wb_sel),
        .alu_a_sel(alu_a_sel)
    );

    // ALU控制
    alu_control alu_ctrl_inst (
        .alu_op(alu_op),
        .funct3(instr[14:12]),
        .funct7(instr[31:25]),
        .alu_ctrl(alu_ctrl)
    );

    // ALU输入a选择（组合逻辑 assign）
    assign alu_a = (alu_a_sel == 2'b00) ? rs1_data :
                   (alu_a_sel == 2'b01) ? pc :
                   (alu_a_sel == 2'b10) ? 32'h0 : 32'h0;

    // ALU第二操作数选择
    assign alu_in2 = alu_src ? imm : rs2_data;

    // ALU
    alu alu_inst (
        .a(alu_a),
        .b(alu_in2),
        .alu_ctrl(alu_ctrl),
        .result(alu_result),
        .zero(zero)
    );

    // 数据存储器
    dmem dmem_inst (
        .clk(clk),
        .we(mem_write),
        .addr(alu_result),
        .wdata(rs2_data),
        .funct3(instr[14:12]),
        .rdata(mem_rdata)
    );

    // 写回数据选择（组合逻辑 assign）
    wire [31:0] pc_plus4 = pc + 4;
    assign write_data = (wb_sel == 2'b00) ? alu_result :
                        (wb_sel == 2'b01) ? mem_rdata :
                        (wb_sel == 2'b10) ? pc_plus4 : 32'h0;

    // 分支比较
    branch_compare br_comp (
        .funct3(instr[14:12]),
        .rs1_data(rs1_data),
        .rs2_data(rs2_data),
        .br_taken(br_taken)
    );

    // PC更新逻辑
    wire [31:0] branch_target = pc + imm;          // B型
    wire [31:0] jal_target = pc + imm;             // J型（已左移1位）
    wire [31:0] jalr_target = (rs1_data + imm) & ~32'h1; // I型，最低位清零

    wire jump_taken = jal | jalr;
    wire [31:0] jump_target = jalr ? jalr_target : jal_target;

    assign next_pc = jump_taken ? jump_target :
                     (branch & br_taken) ? branch_target : pc_plus4;
endmodule