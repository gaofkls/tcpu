// top.v
// 五级流水线 CPU 顶层，集成 MMU 和内存映射定时器
module top (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        int_soft,
    input  wire        int_timer,
    input  wire        int_ext,
    output wire [31:0] pc
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
    // 新增 CSR 相关寄存器（ID/EX 阶段）
    reg  [1:0]  id_ex_wb_sel_reg;
    reg  [2:0]  id_ex_csr_op_reg;
    reg  [11:0] id_ex_csr_addr_reg;
    reg         id_ex_is_csr_reg;
    reg         id_ex_is_ecall_reg;
    reg         id_ex_is_ebreak_reg;
    reg         id_ex_is_mret_reg;
    reg         id_ex_is_sret_reg;

    // 原有的 ID/EX 寄存器
    reg  [31:0] id_ex_pc_plus4_reg, id_ex_rs1_data_reg, id_ex_rs2_data_reg, id_ex_imm_reg;
    reg  [4:0]  id_ex_rs1_addr_reg, id_ex_rs2_addr_reg, id_ex_rd_addr_reg;
    reg  [3:0]  id_ex_alu_ctrl_reg;
    reg         id_ex_alu_src_reg, id_ex_mem_write_reg, id_ex_mem_to_reg_reg, id_ex_reg_write_reg;
    reg         id_ex_branch_reg, id_ex_jal_reg, id_ex_jalr_reg;
    reg  [1:0]  id_ex_alu_a_sel_reg;
    reg  [2:0]  id_ex_funct3_reg;
    wire id_ex_flush;

    // EX/MEM
    wire [31:0] ex_mem_alu_result, ex_mem_rs2_data, ex_mem_pc_plus4;
    wire [4:0]  ex_mem_rd_addr;
    wire        ex_mem_mem_write, ex_mem_mem_to_reg, ex_mem_reg_write;
    wire        ex_mem_branch_taken, ex_mem_jump_taken;
    wire [31:0] ex_mem_branch_target, ex_mem_jump_target;
    wire [2:0]  ex_mem_funct3;
    // 新增 CSR 相关寄存器（EX/MEM 阶段）
    reg  [1:0]  ex_mem_wb_sel_reg;
    reg  [31:0] ex_mem_csr_rdata_reg;

    // 原有的 EX/MEM 寄存器
    reg  [31:0] ex_mem_alu_result_reg, ex_mem_rs2_data_reg, ex_mem_pc_plus4_reg;
    reg  [4:0]  ex_mem_rd_addr_reg;
    reg         ex_mem_mem_write_reg, ex_mem_mem_to_reg_reg, ex_mem_reg_write_reg;
    reg         ex_mem_branch_taken_reg, ex_mem_jump_taken_reg;
    reg  [31:0] ex_mem_branch_target_reg, ex_mem_jump_target_reg;
    reg  [2:0]  ex_mem_funct3_reg;

    // MEM/WB
    wire [31:0] mem_wb_alu_result, mem_wb_mem_rdata;
    wire [4:0]  mem_wb_rd_addr;
    wire        mem_wb_mem_to_reg, mem_wb_reg_write;
    // 新增 CSR 相关寄存器（MEM/WB 阶段）
    reg  [1:0]  mem_wb_wb_sel_reg;
    reg  [31:0] mem_wb_csr_rdata_reg;
    reg  [31:0] mem_wb_pc_plus4_reg;

    // 原有的 MEM/WB 寄存器
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
    // 新增 CSR 控制信号
    wire [2:0] csr_op;
    wire is_ecall, is_ebreak, is_mret, is_sret, is_csr;
    wire [2:0] funct3 = if_id_instr_reg[14:12];

    // 前递信号
    wire [1:0] forward_a, forward_b;
    wire [31:0] alu_src1, alu_src2_rs2, alu_src2;

    // 冒险检测信号（原）
    wire stall_pc_orig, stall_if_id_orig, flush_id_ex_orig;
    wire flush_if_id = ex_mem_branch_taken_reg || ex_mem_jump_taken_reg;

    // 分支/跳转结果
    wire branch_taken, jump_taken;
    wire [31:0] branch_target, jump_target;

    // -------------------- CSR 相关连线 --------------------
    wire [31:0] csr_rdata;
    wire        csr_take_trap;
    wire [31:0] csr_trap_pc;
    wire [31:0] csr_mepc;
    wire [31:0] csr_sepc;
    wire        csr_flush;
    wire [1:0]  csr_privilege;
    wire [31:0] csr_satp;

    // -------------------- MMU 相关信号 --------------------
    wire mmu_enable = csr_satp[31];                     // 分页使能（假设 mode 位在最高位）
    wire mmu_start  = mmu_enable && (ex_mem_mem_write_reg || ex_mem_mem_to_reg_reg); // 需要访存且分页使能时启动 MMU

    wire mmu_done;
    wire [31:0] mmu_paddr;
    wire mmu_page_fault;
    wire mmu_mem_req;                                   // 来自 MMU 的读页表请求
    wire [31:0] mmu_mem_addr;                           // MMU 读页表的地址

    wire mmu_busy = mmu_enable && mmu_start && !mmu_done; // 分页使能且转换未完成时停顿流水线

    // 合并停顿信号
    wire stall_pc   = stall_pc_orig   || mmu_busy;
    wire stall_if_id = stall_if_id_orig || mmu_busy;

    // 生成 mem_valid（延迟一拍）
    reg mem_valid_reg;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) mem_valid_reg <= 1'b0;
        else        mem_valid_reg <= mmu_mem_req;
    end
    wire mem_valid = mem_valid_reg;

    // -------------------- MMU 实例化 --------------------
    mmu u_mmu (
        .clk        (clk),
        .rst_n      (rst_n),
        .start      (mmu_start),
        .vaddr      (ex_mem_alu_result_reg),
        .is_store   (ex_mem_mem_write_reg),
        .priv       (csr_privilege),
        .satp       (csr_satp),
        .mem_req    (mmu_mem_req),
        .mem_addr   (mmu_mem_addr),
        .mem_rdata  (mem_rdata),
        .mem_valid  (mem_valid),
        .done       (mmu_done),
        .paddr      (mmu_paddr),
        .page_fault (mmu_page_fault)
    );

    // -------------------- 内存映射定时器实例化 --------------------
    wire        timer_we;
    wire [31:0] timer_rdata;
    wire        timer_irq;

    // 定时器基址：0x2000000
    timer u_timer (
        .clk      (clk),
        .rst_n    (rst_n),
        .we       (timer_we),
        .addr     (ex_mem_alu_result_reg),
        .wdata    (ex_mem_rs2_data_reg),
        .rdata    (timer_rdata),
        .irq_timer(timer_irq)
    );

    // 判断当前访问是否指向定时器地址范围（0x2000000 - 0x2000FFF）
    wire is_timer_access = (ex_mem_alu_result_reg >= 32'h20000000 && ex_mem_alu_result_reg < 32'h20001000);

    // 定时器写使能
    assign timer_we = is_timer_access && ex_mem_mem_write_reg && (mmu_enable ? mmu_done : 1'b1);

    // -------------------- 数据存储器连接 --------------------
    wire [31:0] dmem_addr;
    wire        dmem_we;

    // 物理地址选择：分页模式下，如果 MMU 请求读页表，则使用 mmu_mem_addr，否则使用 MMU 结果或直接虚拟地址
    assign dmem_addr = mmu_enable ? 
                       (mmu_mem_req ? mmu_mem_addr :          // 读页表时
                        (mmu_done   ? mmu_paddr :             // 数据访存时
                                      ex_mem_alu_result_reg)) // 未启动 MMU（如 ALU 指令）时，地址任意
                     : ex_mem_alu_result_reg;                 // Bare 模式

    assign dmem_we = !is_timer_access && (mmu_enable ? 
                     (mmu_done && !mmu_page_fault ? ex_mem_mem_write_reg : 1'b0)
                   : ex_mem_mem_write_reg);

    wire [31:0] dmem_rdata;
    dmem dmem_inst (
        .clk   (clk),
        .we    (dmem_we),
        .addr  (dmem_addr),
        .wdata (ex_mem_rs2_data_reg),
        .funct3(ex_mem_funct3_reg),
        .rdata (dmem_rdata)
    );

    // 最终读数据多路选择（定时器或 dmem）
    assign mem_rdata = is_timer_access ? timer_rdata : dmem_rdata;

    // 将定时器中断连接到 CSR
    wire int_timer_from_timer = timer_irq;

    // -------------------- CSR 模块实例化 --------------------
    csr csr_inst (
        .clk                (clk),
        .rst_n              (rst_n),
        .addr               (id_ex_csr_addr_reg),
        .wdata              (csr_wdata),
        .op                 (id_ex_csr_op_reg),
        .we                 (id_ex_is_csr_reg),
        .rdata              (csr_rdata),
        .ex_ecall           (id_ex_is_ecall_reg),
        .ex_ebreak          (id_ex_is_ebreak_reg),
        .ex_illegal         (1'b0),          // 可连接非法指令检测
        .ex_page_fault      (mmu_page_fault),
        .ex_page_fault_addr (ex_mem_alu_result_reg),
        .is_store           (ex_mem_mem_write_reg),
        .ex_mret            (id_ex_is_mret_reg),
        .ex_sret            (id_ex_is_sret_reg),
        .int_soft           (int_soft),
        .int_timer          (int_timer_from_timer),
        .int_ext            (int_ext),
        .current_pc         (id_ex_pc_plus4 - 4),  // 异常指令 PC = ID/EX PC - 4
        .current_instr      (32'h0),               // 如需 mtval 可传入
        .inst_retire        (1'b0),                // 暂未使用
        .trap_taken         (csr_take_trap),
        .trap_pc            (csr_trap_pc),
        .flush_pipeline     (csr_flush),
        .privilege          (csr_privilege),
        .satp_value         (csr_satp),
        .mepc_value         (csr_mepc),
        .sepc_value         (csr_sepc),
        .mcause_value       (),
        .scause_value       (),
        .mtvec_value        (),
        .stvec_value        (),
        .mscratch_value     (),
        .sscratch_value     (),
        .mstatus_value      (),
        .sstatus_value      ()
    );

    // -------------------- ID/EX 使能信号 --------------------
    wire id_ex_enable = ~mmu_busy;   // MMU 忙碌时停顿 ID/EX

    // -------------------- 其余部分保持不变 --------------------

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
        if_id_instr_reg    <= 32'h00000013; // 复位时插入 NOP
    end else if (!stall_if_id) begin
        if (flush_if_id || csr_flush) begin
            if_id_pc_plus4_reg <= 32'h0;
            if_id_instr_reg    <= 32'h00000013; // 冲刷时插入气泡
        end else begin
            if_id_pc_plus4_reg <= pc + 4;
            if_id_instr_reg    <= instr;
        end
    end
end
    assign if_id_pc_plus4 = if_id_pc_plus4_reg;
    assign if_id_instr    = if_id_instr_reg;

    // 寄存器文件
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
        .instr(if_id_instr),
        .reg_write(reg_write),
        .alu_src(alu_src),
        .mem_write(mem_write),
        .mem_read(),                         // 如果不需要可以留空
        .branch(branch),
        .jal(jal),
        .jalr(jalr),
        .alu_op(alu_op),
        .imm_sel(imm_sel),
        .wb_sel(wb_sel),
        .alu_a_sel(alu_a_sel),
        .csr_op(csr_op),
        .is_ecall(is_ecall),
        .is_ebreak(is_ebreak),
        .is_mret(is_mret),
        .is_sret(is_sret),
        .is_csr(is_csr)
    );

    // ALU控制
    alu_control alu_ctrl_inst (
        .alu_op(alu_op),
        .funct3(if_id_instr[14:12]),
        .funct7(if_id_instr[31:25]),
        .alu_ctrl(alu_ctrl)
    );

    // ID/EX 寄存器（包含 CSR 字段）
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
            id_ex_wb_sel_reg     <= 2'b0;
            id_ex_csr_op_reg     <= 3'b0;
            id_ex_csr_addr_reg   <= 12'b0;
            id_ex_is_csr_reg     <= 1'b0;
            id_ex_is_ecall_reg   <= 1'b0;
            id_ex_is_ebreak_reg  <= 1'b0;
            id_ex_is_mret_reg    <= 1'b0;
            id_ex_is_sret_reg    <= 1'b0;
        end else if (flush_id_ex_orig || csr_flush) begin
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
            id_ex_wb_sel_reg     <= 2'b0;
            id_ex_csr_op_reg     <= 3'b0;
            id_ex_csr_addr_reg   <= 12'b0;
            id_ex_is_csr_reg     <= 1'b0;
            id_ex_is_ecall_reg   <= 1'b0;
            id_ex_is_ebreak_reg  <= 1'b0;
            id_ex_is_mret_reg    <= 1'b0;
            id_ex_is_sret_reg    <= 1'b0;
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
            id_ex_mem_to_reg_reg <= (wb_sel == 2'b01);
            id_ex_reg_write_reg  <= reg_write;
            id_ex_branch_reg     <= branch;
            id_ex_jal_reg        <= jal;
            id_ex_jalr_reg       <= jalr;
            id_ex_alu_a_sel_reg  <= alu_a_sel;
            id_ex_funct3_reg     <= if_id_instr[14:12];
            id_ex_wb_sel_reg     <= wb_sel;
            id_ex_csr_op_reg     <= csr_op;
            id_ex_csr_addr_reg   <= if_id_instr[31:20];
            id_ex_is_csr_reg     <= is_csr;
            id_ex_is_ecall_reg   <= is_ecall;
            id_ex_is_ebreak_reg  <= is_ebreak;
            id_ex_is_mret_reg    <= is_mret;
            id_ex_is_sret_reg    <= is_sret;
        end
    end

    // 将 ID/EX 寄存器输出连接到 wire
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
        .id_ex_mem_read(id_ex_mem_to_reg),
        .if_id_rs1(if_id_instr[19:15]),
        .if_id_rs2(if_id_instr[24:20]),
        .branch_taken(ex_mem_branch_taken_reg),
        .jump_taken(ex_mem_jump_taken_reg),
        .stall_pc(stall_pc_orig),
        .stall_if_id(stall_if_id_orig),
        .flush_id_ex(flush_id_ex_orig)
    );

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

    // 分支比较
    branch_compare br_comp (
        .funct3(id_ex_funct3),
        .rs1_data(alu_src1),
        .rs2_data(alu_src2_rs2),
        .br_taken(br_taken)
    );
    assign branch_taken = id_ex_branch & br_taken;

    // 分支目标计算
    assign branch_target = (id_ex_pc_plus4 - 4) + id_ex_imm;

    // 跳转目标计算
   wire [31:0] jal_target = (id_ex_pc_plus4 - 4) + id_ex_imm;
    wire [31:0] jalr_target = (alu_src1 + id_ex_imm) & ~32'h1;
    wire [31:0] exc_pc = id_ex_pc_plus4 - 4;

    // CSR 写数据选择
    wire [31:0] csr_wdata = (id_ex_is_csr_reg && id_ex_csr_op_reg[2]) ? {27'b0, id_ex_rs1_addr} : alu_src1;

    // 跳转控制
    wire mret_taken = id_ex_is_mret_reg;
    wire sret_taken = id_ex_is_sret_reg;
    wire trap_taken = csr_take_trap;

    assign jump_taken = id_ex_jal | id_ex_jalr | mret_taken | sret_taken | trap_taken;
    assign jump_target = trap_taken ? csr_trap_pc :
                         sret_taken ? csr_sepc :
                         mret_taken ? csr_mepc :
                         id_ex_jalr  ? jalr_target : jal_target;

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
            ex_mem_wb_sel_reg         <= 2'b0;
            ex_mem_csr_rdata_reg      <= 32'b0;
        end else if (!mmu_busy) begin
            ex_mem_alu_result_reg     <= alu_result;
            ex_mem_rs2_data_reg       <= alu_src2_rs2;
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
            ex_mem_wb_sel_reg         <= id_ex_wb_sel_reg;
            ex_mem_csr_rdata_reg      <= csr_rdata;
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

    // MEM/WB 寄存器
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_wb_alu_result_reg  <= 32'h0;
            mem_wb_mem_rdata_reg   <= 32'h0;
            mem_wb_rd_addr_reg     <= 5'h0;
            mem_wb_mem_to_reg_reg  <= 1'b0;
            mem_wb_reg_write_reg   <= 1'b0;
            mem_wb_wb_sel_reg      <= 2'b0;
            mem_wb_csr_rdata_reg   <= 32'b0;
            mem_wb_pc_plus4_reg    <= 32'b0;
        end else begin
            mem_wb_alu_result_reg  <= ex_mem_alu_result;
            mem_wb_mem_rdata_reg   <= mem_rdata;
            mem_wb_rd_addr_reg     <= ex_mem_rd_addr;
            mem_wb_mem_to_reg_reg  <= ex_mem_mem_to_reg;
            mem_wb_reg_write_reg   <= ex_mem_reg_write;
            mem_wb_wb_sel_reg      <= ex_mem_wb_sel_reg;
            mem_wb_csr_rdata_reg   <= ex_mem_csr_rdata_reg;
            mem_wb_pc_plus4_reg    <= ex_mem_pc_plus4;
        end
    end

    assign mem_wb_alu_result = mem_wb_alu_result_reg;
    assign mem_wb_mem_rdata  = mem_wb_mem_rdata_reg;
    assign mem_wb_rd_addr    = mem_wb_rd_addr_reg;
    assign mem_wb_mem_to_reg = mem_wb_mem_to_reg_reg;
    assign mem_wb_reg_write  = mem_wb_reg_write_reg;

    // 写回数据选择
    assign write_data = (mem_wb_wb_sel_reg == 2'b00) ? mem_wb_alu_result_reg :
                        (mem_wb_wb_sel_reg == 2'b01) ? mem_wb_mem_rdata_reg :
                        (mem_wb_wb_sel_reg == 2'b10) ? mem_wb_pc_plus4_reg :
                        (mem_wb_wb_sel_reg == 2'b11) ? mem_wb_csr_rdata_reg : 32'h0;

    // PC 更新逻辑
    wire [31:0] pc_plus4 = pc + 4;
    wire [31:0] target = ex_mem_jump_taken ? ex_mem_jump_target :
                         ex_mem_branch_taken ? ex_mem_branch_target : pc_plus4;
    assign next_pc = target;

endmodule