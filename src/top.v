module top (
    input clk,
    input rst_n,
    output [31:0] pc
);
    // -------------------- 流水线寄存器信号定义 --------------------
    // IF/ID
    wire [31:0] if_id_pc_plus4, if_id_instr;
    reg  [31:0] if_id_pc_plus4_reg, if_id_instr_reg;
    wire if_id_flush, if_id_stall;

    // ID/EX
    wire [31:0] id_ex_pc_plus4, id_ex_rs1_data, id_ex_rs2_data, id_ex_imm;
    wire [4:0]  id_ex_rs1_addr, id_ex_rs2_addr, id_ex_rd_addr;
    wire [3:0]  id_ex_alu_ctrl;
    wire        id_ex_alu_src, id_ex_mem_write, id_ex_mem_to_reg, id_ex_reg_write;
    wire        id_ex_branch, id_ex_jal, id_ex_jalr;
    wire [1:0]  id_ex_alu_a_sel;
    wire [2:0]  id_ex_funct3;
    reg  [31:0] id_ex_pc_plus4_reg, id_ex_rs1_data_reg, id_ex_rs2_data_reg, id_ex_imm_reg;
    reg  [4:0]  id_ex_rs1_addr_reg, id_ex_rs2_addr_reg, id_ex_rd_addr_reg;
    reg  [3:0]  id_ex_alu_ctrl_reg;
    reg         id_ex_alu_src_reg, id_ex_mem_write_reg, id_ex_mem_to_reg_reg, id_ex_reg_write_reg;
    reg         id_ex_branch_reg, id_ex_jal_reg, id_ex_jalr_reg;
    reg  [1:0]  id_ex_alu_a_sel_reg;
    reg  [2:0]  id_ex_funct3_reg;
    wire id_ex_flush, id_ex_enable;

    // EX/MEM
    wire [31:0] ex_mem_alu_result, ex_mem_rs2_data, ex_mem_pc_plus4;
    wire [4:0]  ex_mem_rd_addr;
    wire        ex_mem_mem_write, ex_mem_mem_to_reg, ex_mem_reg_write;
    wire        ex_mem_branch_taken, ex_mem_jump_taken;
    wire [31:0] ex_mem_branch_target, ex_mem_jump_target;
    wire [2:0]  ex_mem_funct3;
    reg  [31:0] ex_mem_alu_result_reg, ex_mem_rs2_data_reg, ex_mem_pc_plus4_reg;
    reg  [4:0]  ex_mem_rd_addr_reg;
    reg         ex_mem_mem_write_reg, ex_mem_mem_to_reg_reg, ex_mem_reg_write_reg;
    reg         ex_mem_branch_taken_reg, ex_mem_jump_taken_reg;
    reg  [31:0] ex_mem_branch_target_reg, ex_mem_jump_target_reg;
    reg  [2:0]  ex_mem_funct3_reg;
    // 无冲刷停顿控制，直接传递

    // MEM/WB
    wire [31:0] mem_wb_alu_result, mem_wb_mem_rdata;
    wire [4:0]  mem_wb_rd_addr;
    wire        mem_wb_mem_to_reg, mem_wb_reg_write;
    reg  [31:0] mem_wb_alu_result_reg, mem_wb_mem_rdata_reg;
    reg  [4:0]  mem_wb_rd_addr_reg;
    reg         mem_wb_mem_to_reg_reg, mem_wb_reg_write_reg;

    // -------------------- 其他内部信号 --------------------
    wire [31:0] next_pc;
    wire [31:0] instr;
    wire [31:0] rs1_data, rs2_data;
    wire [31:0] imm;
    wire zero;
    wire br_taken;
    wire [3:0] alu_ctrl;
    wire [31:0] alu_result;
    wire [31:0] mem_rdata;
    wire [31:0] write_data;

    // 控制信号 (来自ID阶段)
    wire reg_write, alu_src, mem_write, branch, jal, jalr;
    wire [1:0] alu_op;
    wire [2:0] imm_sel;
    wire [1:0] wb_sel;
    wire [1:0] alu_a_sel;
    wire [2:0] funct3 = if_id_instr_reg[14:12];

    // 前递信号
    wire [1:0] forward_a, forward_b;
    wire [31:0] alu_src1, alu_src2_rs2, alu_src2;

    // 冒险检测信号
    wire stall_pc, stall_if_id, flush_id_ex;
    wire flush_if_id = ex_mem_branch_taken_reg || ex_mem_jump_taken_reg; // 分支或跳转发生时，冲刷IF/ID
   
    // load-use 数据冒险产生的停顿信号由hazard检测单元给出

    // 分支/跳转结果
    wire branch_taken, jump_taken;
    wire [31:0] branch_target, jump_target;

    // -------------------- 实例化各模块 --------------------

    // PC寄存器
    pc_reg pc_inst (
        .clk(clk), .rst_n(rst_n), .stall(stall_pc), .next_pc(next_pc), .pc(pc)
    );

    // 指令存储器
    imem imem_inst (
        .addr(pc), .instr(instr)
    );

    // IF/ID 寄存器
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            if_id_pc_plus4_reg <= 32'h0;
            if_id_instr_reg    <= 32'h00000013; // nop
        end else if (!stall_if_id) begin
            if (flush_if_id) begin
                if_id_pc_plus4_reg <= 32'h0;
                if_id_instr_reg    <= 32'h00000013;
            end else begin
                if_id_pc_plus4_reg <= pc + 4;
                if_id_instr_reg    <= instr;
            end
        end
    end
    assign if_id_pc_plus4 = if_id_pc_plus4_reg;
    assign if_id_instr    = if_id_instr_reg;

    // 寄存器文件（在ID阶段）
    reg_file reg_inst (
        .clk(clk),
        .we(mem_wb_reg_write_reg),
        .rs1_addr(if_id_instr[19:15]),
        .rs2_addr(if_id_instr[24:20]),
        .rd_addr(mem_wb_rd_addr_reg),
        .rd_data(write_data),
        .rs1_data(rs1_data),
        .rs2_data(rs2_data)
    );

    // 立即数生成器
    imm_gen imm_inst (
        .instr(if_id_instr),
        .immsel(imm_sel),
        .imm(imm)
    );

    // 控制单元
    control_unit ctrl_inst (
        .opcode(if_id_instr[6:0]),
        .funct3(if_id_instr[14:12]),
        .funct7(if_id_instr[31:25]),
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

    // ALU控制（在ID阶段生成）
    alu_control alu_ctrl_inst (
        .alu_op(alu_op),
        .funct3(if_id_instr[14:12]),
        .funct7(if_id_instr[31:25]),
        .alu_ctrl(alu_ctrl)
    );

    // ID/EX 寄存器（修正冲刷逻辑）
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            id_ex_pc_plus4_reg   <= 32'h0;
            id_ex_rs1_data_reg   <= 32'h0;
            id_ex_rs2_data_reg   <= 32'h0;
            id_ex_imm_reg        <= 32'h0;
            id_ex_rs1_addr_reg   <= 5'h0;
            id_ex_rs2_addr_reg   <= 5'h0;
            id_ex_rd_addr_reg    <= 5'h0;
            id_ex_alu_ctrl_reg   <= 4'h0;
            id_ex_alu_src_reg    <= 1'b0;
            id_ex_mem_write_reg  <= 1'b0;
            id_ex_mem_to_reg_reg <= 1'b0;
            id_ex_reg_write_reg  <= 1'b0;
            id_ex_branch_reg     <= 1'b0;
            id_ex_jal_reg        <= 1'b0;
            id_ex_jalr_reg       <= 1'b0;
            id_ex_alu_a_sel_reg  <= 2'b0;
            id_ex_funct3_reg     <= 3'b0;
        end else if (flush_id_ex) begin
            // 完全清零，插入气泡（与复位相同）
            id_ex_pc_plus4_reg   <= 32'h0;
            id_ex_rs1_data_reg   <= 32'h0;
            id_ex_rs2_data_reg   <= 32'h0;
            id_ex_imm_reg        <= 32'h0;
            id_ex_rs1_addr_reg   <= 5'h0;
            id_ex_rs2_addr_reg   <= 5'h0;
            id_ex_rd_addr_reg    <= 5'h0;
            id_ex_alu_ctrl_reg   <= 4'h0;
            id_ex_alu_src_reg    <= 1'b0;
            id_ex_mem_write_reg  <= 1'b0;
            id_ex_mem_to_reg_reg <= 1'b0;
            id_ex_reg_write_reg  <= 1'b0;
            id_ex_branch_reg     <= 1'b0;
            id_ex_jal_reg        <= 1'b0;
            id_ex_jalr_reg       <= 1'b0;
            id_ex_alu_a_sel_reg  <= 2'b0;
            id_ex_funct3_reg     <= 3'b0;
        end else if (id_ex_enable) begin
            id_ex_pc_plus4_reg   <= if_id_pc_plus4;
            id_ex_rs1_data_reg   <= rs1_data;
            id_ex_rs2_data_reg   <= rs2_data;
            id_ex_imm_reg        <= imm;
            id_ex_rs1_addr_reg   <= if_id_instr[19:15];
            id_ex_rs2_addr_reg   <= if_id_instr[24:20];
            id_ex_rd_addr_reg    <= if_id_instr[11:7];
            id_ex_alu_ctrl_reg   <= alu_ctrl;
            id_ex_alu_src_reg    <= alu_src;
            id_ex_mem_write_reg  <= mem_write;
            id_ex_mem_to_reg_reg <= (wb_sel == 2'b01); // mem_to_reg
            id_ex_reg_write_reg  <= reg_write;
            id_ex_branch_reg     <= branch;
            id_ex_jal_reg        <= jal;
            id_ex_jalr_reg       <= jalr;
            id_ex_alu_a_sel_reg  <= alu_a_sel;
            id_ex_funct3_reg     <= if_id_instr[14:12];
        end
    end
    assign id_ex_pc_plus4   = id_ex_pc_plus4_reg;
    assign id_ex_rs1_data   = id_ex_rs1_data_reg;
    assign id_ex_rs2_data   = id_ex_rs2_data_reg;
    assign id_ex_imm        = id_ex_imm_reg;
    assign id_ex_rs1_addr   = id_ex_rs1_addr_reg;
    assign id_ex_rs2_addr   = id_ex_rs2_addr_reg;
    assign id_ex_rd_addr    = id_ex_rd_addr_reg;
    assign id_ex_alu_ctrl   = id_ex_alu_ctrl_reg;
    assign id_ex_alu_src    = id_ex_alu_src_reg;
    assign id_ex_mem_write  = id_ex_mem_write_reg;
    assign id_ex_mem_to_reg = id_ex_mem_to_reg_reg;
    assign id_ex_reg_write  = id_ex_reg_write_reg;
    assign id_ex_branch     = id_ex_branch_reg;
    assign id_ex_jal        = id_ex_jal_reg;
    assign id_ex_jalr       = id_ex_jalr_reg;
    assign id_ex_alu_a_sel  = id_ex_alu_a_sel_reg;
    assign id_ex_funct3     = id_ex_funct3_reg;

    // 前递单元
    forwarding_unit fwd_unit (
        .id_ex_rs1(id_ex_rs1_addr),
        .id_ex_rs2(id_ex_rs2_addr),
        .ex_mem_rd(ex_mem_rd_addr_reg),
        .mem_wb_rd(mem_wb_rd_addr_reg),
        .ex_mem_reg_write(ex_mem_reg_write_reg),
        .mem_wb_reg_write(mem_wb_reg_write_reg),
        .forward_a(forward_a),
        .forward_b(forward_b)
    );

    // 冒险检测单元
    hazard_detection hazard (
        .id_ex_rd(id_ex_rd_addr),
        .id_ex_mem_read(id_ex_mem_to_reg),  // load指令：mem_to_reg为1
        .if_id_rs1(if_id_instr[19:15]),
        .if_id_rs2(if_id_instr[24:20]),
        .branch_taken(ex_mem_branch_taken_reg),
        .jump_taken(ex_mem_jump_taken_reg),
        .stall_pc(stall_pc),
        .stall_if_id(stall_if_id),
        .flush_id_ex(flush_id_ex)
    );


    assign id_ex_enable = 1'b1; // 除非需要额外停顿，通常保持使能

    // EX阶段：ALU输入选择（带前递）
    assign alu_src1 = (forward_a == 2'b00) ? id_ex_rs1_data :
                      (forward_a == 2'b01) ? ex_mem_alu_result_reg :
                      (forward_a == 2'b10) ? (mem_wb_mem_to_reg_reg ? mem_wb_mem_rdata_reg : mem_wb_alu_result_reg) : 32'h0;
    assign alu_src2_rs2 = (forward_b == 2'b00) ? id_ex_rs2_data :
                          (forward_b == 2'b01) ? ex_mem_alu_result_reg :
                          (forward_b == 2'b10) ? (mem_wb_mem_to_reg_reg ? mem_wb_mem_rdata_reg : mem_wb_alu_result_reg) : 32'h0;
    assign alu_src2 = id_ex_alu_src ? id_ex_imm : alu_src2_rs2;

    // ALU实例
    alu alu_inst (
        .a(alu_src1),
        .b(alu_src2),
        .alu_ctrl(id_ex_alu_ctrl),
        .result(alu_result),
        .zero(zero)
    );

    // 分支比较（使用前递后的操作数）
    branch_compare br_comp (
        .funct3(id_ex_funct3),
        .rs1_data(alu_src1),
        .rs2_data(alu_src2_rs2), // 注意：分支比较需要原始的rs2，不是alu_src2（因为alu_src2可能被立即数覆盖，但分支不会，所以这里用 alu_src2_rs2 是正确的）
        .br_taken(br_taken)
    );
    assign branch_taken = id_ex_branch & br_taken;

    // 分支目标计算
    assign branch_target = id_ex_pc_plus4 + id_ex_imm; // 注意：B型立即数已在imm_gen左移1位，所以直接加

    // 跳转目标计算
    wire [31:0] jal_target = id_ex_pc_plus4 + id_ex_imm; // J型立即数已左移1位
    wire [31:0] jalr_target = (alu_src1 + id_ex_imm) & ~32'h1; // rs1 + imm, 最低位清零
    assign jump_taken = id_ex_jal | id_ex_jalr;
    assign jump_target = id_ex_jalr ? jalr_target : jal_target;

    // EX/MEM 寄存器
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ex_mem_alu_result_reg     <= 32'h0;
            ex_mem_rs2_data_reg       <= 32'h0;
            ex_mem_pc_plus4_reg       <= 32'h0;
            ex_mem_rd_addr_reg        <= 5'h0;
            ex_mem_mem_write_reg      <= 1'b0;
            ex_mem_mem_to_reg_reg     <= 1'b0;
            ex_mem_reg_write_reg      <= 1'b0;
            ex_mem_branch_taken_reg   <= 1'b0;
            ex_mem_jump_taken_reg     <= 1'b0;
            ex_mem_branch_target_reg  <= 32'h0;
            ex_mem_jump_target_reg    <= 32'h0;
            ex_mem_funct3_reg         <= 3'b0;
        end else begin
            ex_mem_alu_result_reg     <= alu_result;
            ex_mem_rs2_data_reg       <= alu_src2_rs2; // 存储数据使用原始rs2（已前递）
            ex_mem_pc_plus4_reg       <= id_ex_pc_plus4;
            ex_mem_rd_addr_reg        <= id_ex_rd_addr;
            ex_mem_mem_write_reg      <= id_ex_mem_write;
            ex_mem_mem_to_reg_reg     <= id_ex_mem_to_reg;
            ex_mem_reg_write_reg      <= id_ex_reg_write;
            ex_mem_branch_taken_reg   <= branch_taken;
            ex_mem_jump_taken_reg     <= jump_taken;
            ex_mem_branch_target_reg  <= branch_target;
            ex_mem_jump_target_reg    <= jump_target;
            ex_mem_funct3_reg         <= id_ex_funct3;
        end
    end
    assign ex_mem_alu_result   = ex_mem_alu_result_reg;
    assign ex_mem_rs2_data     = ex_mem_rs2_data_reg;
    assign ex_mem_pc_plus4     = ex_mem_pc_plus4_reg;
    assign ex_mem_rd_addr      = ex_mem_rd_addr_reg;
    assign ex_mem_mem_write    = ex_mem_mem_write_reg;
    assign ex_mem_mem_to_reg   = ex_mem_mem_to_reg_reg;
    assign ex_mem_reg_write    = ex_mem_reg_write_reg;
    assign ex_mem_branch_taken = ex_mem_branch_taken_reg;
    assign ex_mem_jump_taken   = ex_mem_jump_taken_reg;
    assign ex_mem_branch_target= ex_mem_branch_target_reg;
    assign ex_mem_jump_target  = ex_mem_jump_target_reg;
    assign ex_mem_funct3       = ex_mem_funct3_reg;

    // 数据存储器
    dmem dmem_inst (
        .clk(clk),
        .we(ex_mem_mem_write),
        .addr(ex_mem_alu_result),
        .wdata(ex_mem_rs2_data),
        .funct3(ex_mem_funct3),
        .rdata(mem_rdata)
    );

    // MEM/WB 寄存器
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_wb_alu_result_reg  <= 32'h0;
            mem_wb_mem_rdata_reg   <= 32'h0;
            mem_wb_rd_addr_reg     <= 5'h0;
            mem_wb_mem_to_reg_reg  <= 1'b0;
            mem_wb_reg_write_reg   <= 1'b0;
        end else begin
            mem_wb_alu_result_reg  <= ex_mem_alu_result;
            mem_wb_mem_rdata_reg   <= mem_rdata;
            mem_wb_rd_addr_reg     <= ex_mem_rd_addr;
            mem_wb_mem_to_reg_reg  <= ex_mem_mem_to_reg;
            mem_wb_reg_write_reg   <= ex_mem_reg_write;
        end
    end
    assign mem_wb_alu_result = mem_wb_alu_result_reg;
    assign mem_wb_mem_rdata  = mem_wb_mem_rdata_reg;
    assign mem_wb_rd_addr    = mem_wb_rd_addr_reg;
    assign mem_wb_mem_to_reg = mem_wb_mem_to_reg_reg;
    assign mem_wb_reg_write  = mem_wb_reg_write_reg;

    // 写回数据选择
    assign write_data = mem_wb_mem_to_reg ? mem_wb_mem_rdata : mem_wb_alu_result;

    // PC 更新逻辑
    wire [31:0] pc_plus4 = pc + 4;
    // 分支/跳转目标优先级：跳转 > 分支
    wire [31:0] target = ex_mem_jump_taken ? ex_mem_jump_target :
                         ex_mem_branch_taken ? ex_mem_branch_target : pc_plus4;
    assign next_pc = target; // 如果停顿，next_pc会被忽略（因为pc寄存器 stall 为1）

endmodule