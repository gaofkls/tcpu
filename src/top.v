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
    wire reg_write, alu_src, mem_write, mem_to_reg, branch;
    wire [1:0] alu_op;
    wire [2:0] imm_sel;
    wire [3:0] alu_ctrl;

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

    // 控制单元
    control_unit ctrl_inst (
        .opcode(instr[6:0]),
        .funct3(instr[14:12]),
        .funct7(instr[31:25]),
        .reg_write(reg_write),
        .alu_src(alu_src),
        .mem_write(mem_write),
        .mem_to_reg(mem_to_reg),
        .branch(branch),
        .alu_op(alu_op),
        .imm_sel(imm_sel)
    );

    // ALU控制
    alu_control alu_ctrl_inst (
        .alu_op(alu_op),
        .funct3(instr[14:12]),
        .funct7(instr[31:25]),
        .alu_ctrl(alu_ctrl)
    );

    // ALU第二操作数选择
    assign alu_in2 = alu_src ? imm : rs2_data;

    // ALU
    alu alu_inst (
        .a(rs1_data),
        .b(alu_in2),
        .alu_ctrl(alu_ctrl),
        .result(alu_result),
        .zero(zero)
    );

    // 数据存储器
    dmem dmem_inst (
        .clk(clk),
        .we(mem_write),
        .addr(alu_result), // 地址为ALU计算结果
        .wdata(rs2_data),
        .rdata(mem_rdata)
    );

    // 写回数据选择
    assign write_data = mem_to_reg ? mem_rdata : alu_result;

    // 分支比较
    branch_compare br_comp (
        .funct3(instr[14:12]),
        .rs1_data(rs1_data),
        .rs2_data(rs2_data),
        .br_taken(br_taken)
    );

    // PC更新逻辑
    wire [31:0] pc_plus4 = pc + 4;
    wire [31:0] branch_target = pc + imm; // imm已左移1位
    assign next_pc = (branch & br_taken) ? branch_target : pc_plus4;
endmodule