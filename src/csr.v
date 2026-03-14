// csr.v
// 完整的 CSR 模块，支持机器模式和监管者模式，包含中断处理
module csr (
    input  wire        clk,
    input  wire        rst_n,

    // CSR 访问接口
    input  wire [11:0] addr,
    input  wire [31:0] wdata,
    input  wire [2:0]  op,          // CSR 操作类型
    input  wire        we,           // 写使能（由指令控制）
    output reg  [31:0] rdata,

    // 异常输入（来自流水线）
    input  wire        ex_ecall,
    input  wire        ex_ebreak,
    input  wire        ex_illegal,
    input  wire        ex_page_fault,
    input  wire [31:0] ex_page_fault_addr,
    input  wire        is_store,      // 用于区分加载/存储页错误

    // 特权模式变化指令
    input  wire        ex_mret,
    input  wire        ex_sret,

    // 中断输入
    input  wire        int_soft,
    input  wire        int_timer,
    input  wire        int_ext,

    // PC 相关
    input  wire [31:0] current_pc,   // 异常指令的 PC
    input  wire [31:0] current_instr,
    input  wire        inst_retire,   // 指令退休信号（用于 mcycle/minstret）

    // 输出到流水线
    output reg         trap_taken,
    output reg  [31:0] trap_pc,
    output reg         flush_pipeline,

    // 特权级输出
    output reg  [1:0]  privilege,     // 3=机器,1=监管者,0=用户

    // 特殊寄存器值输出（供其他模块使用）
    output wire [31:0] satp_value,
    output wire [31:0] mepc_value,
    output wire [31:0] sepc_value,
    output wire [31:0] mcause_value,
    output wire [31:0] scause_value,
    output wire [31:0] mtvec_value,
    output wire [31:0] stvec_value,
    output wire [31:0] mscratch_value,
    output wire [31:0] sscratch_value,
    output wire [31:0] mstatus_value,
    output wire [31:0] sstatus_value
);

    // 机器模式寄存器
    reg [31:0] mstatus;
    reg [31:0] misa;          // 可硬连线
    reg [31:0] mie;
    reg [31:0] mtvec;
    reg [31:0] mscratch;
    reg [31:0] mepc;
    reg [31:0] mcause;
    reg [31:0] mtval;
    reg [31:0] mip;           // 硬件更新，部分位可软件写

    // 监管者模式寄存器
    reg [31:0] sstatus;
    reg [31:0] stvec;
    reg [31:0] sscratch;
    reg [31:0] sepc;
    reg [31:0] scause;
    reg [31:0] stval;
    reg [31:0] satp;

    // 性能计数器（简化）
    reg [31:0] mcycle;
    reg [31:0] minstret;

    // 中断号定义
    localparam IRQ_SOFT  = 3;   // 机器软件中断
    localparam IRQ_TIMER = 7;   // 机器定时器中断
    localparam IRQ_EXT   = 11;  // 机器外部中断

    // 异常码定义（mcause/scause 编码）
    localparam CAUSE_MISALIGNED_FETCH    = 0;
    localparam CAUSE_FETCH_ACCESS        = 1;
    localparam CAUSE_ILLEGAL_INSTRUCTION = 2;
    localparam CAUSE_BREAKPOINT          = 3;
    localparam CAUSE_MISALIGNED_LOAD     = 4;
    localparam CAUSE_LOAD_ACCESS         = 5;
    localparam CAUSE_MISALIGNED_STORE    = 6;
    localparam CAUSE_STORE_ACCESS        = 7;
    localparam CAUSE_ECALL_U             = 8;
    localparam CAUSE_ECALL_S             = 9;
    localparam CAUSE_ECALL_M             = 11;
    localparam CAUSE_PAGE_FAULT_INST     = 12;
    localparam CAUSE_PAGE_FAULT_LOAD     = 13;
    localparam CAUSE_PAGE_FAULT_STORE    = 15;

    // 寄存器地址映射（仅列出关键地址）
    localparam CSR_USTATUS      = 12'h000;
    localparam CSR_UIE          = 12'h004;
    localparam CSR_UTVEC        = 12'h005;
    localparam CSR_USCRATCH     = 12'h040;
    localparam CSR_UEPC         = 12'h041;
    localparam CSR_UCAUSE       = 12'h042;
    localparam CSR_UTVAL        = 12'h043;
    localparam CSR_UIP          = 12'h044;

    localparam CSR_SSTATUS      = 12'h100;
    localparam CSR_SIE          = 12'h104;
    localparam CSR_STVEC        = 12'h105;
    localparam CSR_SSCRATCH     = 12'h140;
    localparam CSR_SEPC         = 12'h141;
    localparam CSR_SCAUSE       = 12'h142;
    localparam CSR_STVAL        = 12'h143;
    localparam CSR_SIP          = 12'h144;
    localparam CSR_SATP         = 12'h180;

    localparam CSR_MSTATUS      = 12'h300;
    localparam CSR_MISA         = 12'h301;
    localparam CSR_MIE          = 12'h304;
    localparam CSR_MTVEC        = 12'h305;
    localparam CSR_MSCRATCH     = 12'h340;
    localparam CSR_MEPC         = 12'h341;
    localparam CSR_MCAUSE       = 12'h342;
    localparam CSR_MTVAL        = 12'h343;
    localparam CSR_MIP          = 12'h344;
    localparam CSR_MCYCLE       = 12'hB00;
    localparam CSR_MINSTRET     = 12'hB02;

    // 更新 mip 寄存器（时钟沿更新）
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mip <= 32'h0;
        end else begin
            mip[IRQ_SOFT]  <= int_soft;
            mip[IRQ_TIMER] <= int_timer;
            mip[IRQ_EXT]   <= int_ext;
            // 其他位保持不变（因为没有写入，所以保持原值）
        end
    end

    // 中断请求判断（根据 mie 和 mip，以及全局中断使能 mstatus.MIE）
    wire pending_interrupt = (mie[IRQ_EXT]   & mip[IRQ_EXT])   ||
                             (mie[IRQ_TIMER] & mip[IRQ_TIMER]) ||
                             (mie[IRQ_SOFT]  & mip[IRQ_SOFT]);
    wire global_irq_enable = mstatus[3];  // mstatus.MIE 位
    wire take_interrupt = pending_interrupt && global_irq_enable && (privilege <= 2'b11); // 机器模式下可响应

    // 异常请求（按优先级）
    wire take_exception = ex_ecall | ex_ebreak | ex_illegal | ex_page_fault;

    // trap 优先级：异常 > 中断（简单处理）
    wire take_trap = take_exception || take_interrupt;

    // 选择异常原因
    reg [31:0] cause;
    reg [31:0] tval;
    always @(*) begin
        cause = 32'h0;
        tval = 32'h0;
        if (take_exception) begin
            if (ex_page_fault) begin
                cause = is_store ? CAUSE_PAGE_FAULT_STORE : CAUSE_PAGE_FAULT_LOAD;
                tval = ex_page_fault_addr;
            end else if (ex_ecall) begin
                case (privilege)
                    2'b00: cause = CAUSE_ECALL_U;
                    2'b01: cause = CAUSE_ECALL_S;
                    2'b11: cause = CAUSE_ECALL_M;
                endcase
                tval = 32'h0;
            end else if (ex_ebreak) begin
                cause = CAUSE_BREAKPOINT;
                tval = 32'h0;
            end else if (ex_illegal) begin
                cause = CAUSE_ILLEGAL_INSTRUCTION;
                tval = current_instr;
            end
        end else if (take_interrupt) begin
            // 外部中断优先级最高（简单），cause 最高位为1表示中断
            if (mie[IRQ_EXT] & mip[IRQ_EXT])
                cause = 32'h80000000 | IRQ_EXT;
            else if (mie[IRQ_TIMER] & mip[IRQ_TIMER])
                cause = 32'h80000000 | IRQ_TIMER;
            else if (mie[IRQ_SOFT] & mip[IRQ_SOFT])
                cause = 32'h80000000 | IRQ_SOFT;
        end
    end

    // 根据当前特权级决定使用的 trap 向量和保存的寄存器
    wire use_s_mode = (privilege == 2'b01) && (sstatus[0] != 0); // sstatus.SIE 等，简化：有 supervisor 模式才用
    // 我们默认仅在机器模式下处理，但保留监管者寄存器支持

    // 更新 mstatus/sstatus 等
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mstatus <= 32'h00001800;  // 默认 MPP=3（机器模式），MIE=0
            misa <= 32'h40001100;     // RV32I 扩展
            mie <= 32'h0;
            mtvec <= 32'h0;
            mscratch <= 32'h0;
            mepc <= 32'h0;
            mcause <= 32'h0;
            mtval <= 32'h0;

            sstatus <= 32'h0;
            stvec <= 32'h0;
            sscratch <= 32'h0;
            sepc <= 32'h0;
            scause <= 32'h0;
            stval <= 32'h0;
            satp <= 32'h0;

            mcycle <= 32'h0;
            minstret <= 32'h0;

            privilege <= 2'b11;        // 复位后为机器模式
            trap_taken <= 1'b0;
            flush_pipeline <= 1'b0;
            trap_pc <= 32'h0;
        end else begin
            // 性能计数器
            mcycle <= mcycle + 1'b1;
            if (inst_retire) minstret <= minstret + 1'b1;

            // 默认输出
            trap_taken <= 1'b0;
            flush_pipeline <= 1'b0;

            // 处理异常/中断
            if (take_trap) begin
                // 根据当前模式选择保存到哪个 CSR
                if (privilege == 2'b11) begin   // 机器模式
                    mepc <= current_pc;
                    mcause <= cause;
                    mtval <= tval;
                    // 保存当前 mstatus 并关闭中断
                    mstatus[7] <= mstatus[3];    // MPIE <= MIE
                    mstatus[3] <= 1'b0;          // MIE <= 0
                    // 保存当前模式到 MPP
                    mstatus[12:11] <= privilege;
                    // 跳转到 mtvec
                    trap_pc <= mtvec;
                end else if (privilege == 2'b01) begin // 监管者模式
                    sepc <= current_pc;
                    scause <= cause;
                    stval <= tval;
                    sstatus[5] <= sstatus[0];     // SPIE <= SIE
                    sstatus[0] <= 1'b0;            // SIE <= 0
                    sstatus[9] <= privilege[0];    // SPP
                    trap_pc <= stvec;
                end else begin
                    // 用户模式不直接处理，应陷入更低模式（实际应进入机器或监管者）
                    // 简化：直接进入机器模式
                    mepc <= current_pc;
                    mcause <= cause;
                    mtval <= tval;
                    mstatus[7] <= mstatus[3];
                    mstatus[3] <= 1'b0;
                    mstatus[12:11] <= 2'b11;
                    trap_pc <= mtvec;
                end

                trap_taken <= 1'b1;
                flush_pipeline <= 1'b1;
            end else if (ex_mret) begin
                // 从机器模式返回
                mstatus[3] <= mstatus[7];          // MIE <= MPIE
                mstatus[7] <= 1'b1;                 // MPIE 置 1
                privilege <= mstatus[12:11];        // 恢复特权级
                trap_pc <= mepc;
                trap_taken <= 1'b1;                  // 用 trap_taken 表示跳转
                flush_pipeline <= 1'b1;
            end else if (ex_sret) begin
                // 从监管者模式返回
                sstatus[0] <= sstatus[5];            // SIE <= SPIE
                sstatus[5] <= 1'b1;
                privilege <= {1'b0, sstatus[9]};      // SPP
                trap_pc <= sepc;
                trap_taken <= 1'b1;
                flush_pipeline <= 1'b1;
            end

            // CSR 写操作（优先级低于 trap 处理，但 trap 时不应写 CSR）
            if (we && !take_trap && !ex_mret && !ex_sret) begin
                case (op)
                    3'b001: begin // CSRRW
                        case (addr)
                            CSR_MSTATUS: mstatus <= wdata;
                            CSR_MIE:     mie <= wdata;
                            CSR_MTVEC:   mtvec <= {wdata[31:2], 2'b00}; // 低位清零
                            CSR_MSCRATCH: mscratch <= wdata;
                            CSR_MEPC:    mepc <= {wdata[31:1], 1'b0};   // 对齐
                            CSR_MCAUSE:  mcause <= wdata;
                            CSR_MTVAL:   mtval <= wdata;
                            CSR_MIP:     /* 部分位可写，暂忽略 */;
                            CSR_SSTATUS: sstatus <= wdata;
                            CSR_STVEC:   stvec <= {wdata[31:2], 2'b00};
                            CSR_SSCRATCH: sscratch <= wdata;
                            CSR_SEPC:    sepc <= {wdata[31:1], 1'b0};
                            CSR_SCAUSE:  scause <= wdata;
                            CSR_STVAL:   stval <= wdata;
                            CSR_SATP:    satp <= wdata;
                            CSR_MCYCLE:  mcycle <= wdata;
                            CSR_MINSTRET: minstret <= wdata;
                        endcase
                    end
                    3'b010: begin // CSRRS (设置位)
                        case (addr)
                            CSR_MSTATUS: mstatus <= mstatus | wdata;
                            CSR_MIE:     mie <= mie | wdata;
                            CSR_MTVEC:   mtvec <= mtvec | {wdata[31:2], 2'b00};
                            CSR_MSCRATCH: mscratch <= mscratch | wdata;
                            CSR_MEPC:    mepc <= mepc | {wdata[31:1], 1'b0};
                            CSR_MCAUSE:  mcause <= mcause | wdata;
                            CSR_MTVAL:   mtval <= mtval | wdata;
                            CSR_SSTATUS: sstatus <= sstatus | wdata;
                            CSR_STVEC:   stvec <= stvec | {wdata[31:2], 2'b00};
                            CSR_SSCRATCH: sscratch <= sscratch | wdata;
                            CSR_SEPC:    sepc <= sepc | {wdata[31:1], 1'b0};
                            CSR_SCAUSE:  scause <= scause | wdata;
                            CSR_STVAL:   stval <= stval | wdata;
                            CSR_SATP:    satp <= satp | wdata;
                            CSR_MCYCLE:  mcycle <= mcycle | wdata;
                            CSR_MINSTRET: minstret <= minstret | wdata;
                        endcase
                    end
                    3'b011: begin // CSRRC (清除位)
                        case (addr)
                            CSR_MSTATUS: mstatus <= mstatus & ~wdata;
                            CSR_MIE:     mie <= mie & ~wdata;
                            CSR_MTVEC:   mtvec <= mtvec & ~{wdata[31:2], 2'b00};
                            CSR_MSCRATCH: mscratch <= mscratch & ~wdata;
                            CSR_MEPC:    mepc <= mepc & ~{wdata[31:1], 1'b0};
                            CSR_MCAUSE:  mcause <= mcause & ~wdata;
                            CSR_MTVAL:   mtval <= mtval & ~wdata;
                            CSR_SSTATUS: sstatus <= sstatus & ~wdata;
                            CSR_STVEC:   stvec <= stvec & ~{wdata[31:2], 2'b00};
                            CSR_SSCRATCH: sscratch <= sscratch & ~wdata;
                            CSR_SEPC:    sepc <= sepc & ~{wdata[31:1], 1'b0};
                            CSR_SCAUSE:  scause <= scause & ~wdata;
                            CSR_STVAL:   stval <= stval & ~wdata;
                            CSR_SATP:    satp <= satp & ~wdata;
                            CSR_MCYCLE:  mcycle <= mcycle & ~wdata;
                            CSR_MINSTRET: minstret <= minstret & ~wdata;
                        endcase
                    end
                    // 3'b101 等是带读后置的，但读操作单独处理，写相同
                endcase
            end
        end
    end

    // CSR 读操作（组合逻辑，用于立即返回）
    always @(*) begin
        case (addr)
            CSR_MSTATUS: rdata = mstatus;
            CSR_MISA:    rdata = misa;
            CSR_MIE:     rdata = mie;
            CSR_MTVEC:   rdata = mtvec;
            CSR_MSCRATCH: rdata = mscratch;
            CSR_MEPC:    rdata = mepc;
            CSR_MCAUSE:  rdata = mcause;
            CSR_MTVAL:   rdata = mtval;
            CSR_MIP:     rdata = mip;
            CSR_MCYCLE:  rdata = mcycle;
            CSR_MINSTRET: rdata = minstret;

            CSR_SSTATUS: rdata = sstatus;
            CSR_STVEC:   rdata = stvec;
            CSR_SSCRATCH: rdata = sscratch;
            CSR_SEPC:    rdata = sepc;
            CSR_SCAUSE:  rdata = scause;
            CSR_STVAL:   rdata = stval;
            CSR_SATP:    rdata = satp;

            default: rdata = 32'h0;
        endcase
    end

    // 输出值供其他模块使用
    assign satp_value = satp;
    assign mepc_value = mepc;
    assign sepc_value = sepc;
    assign mcause_value = mcause;
    assign scause_value = scause;
    assign mtvec_value = mtvec;
    assign stvec_value = stvec;
    assign mscratch_value = mscratch;
    assign sscratch_value = sscratch;
    assign mstatus_value = mstatus;
    assign sstatus_value = sstatus;

endmodule