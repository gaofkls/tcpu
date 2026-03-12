// csr.v
// 机器模式和监管者模式 CSR 实现（支持异常、mret、sret，以及页错误）
module csr (
    input  wire        clk,
    input  wire        rst_n,

    // 来自 EX 阶段的 CSR 操作请求
    input  wire [11:0] addr,          // CSR 地址
    input  wire [31:0] wdata,         // 写入数据
    input  wire [2:0]  op,            // CSR 操作类型（来自 funct3）
    input  wire        we,            // 写使能（由译码产生）
    output reg  [31:0] rdata,         // 读出数据

    // 异常相关
    input  wire        ex_ecall,      // 当前指令是 ecall
    input  wire        ex_ebreak,     // 当前指令是 ebreak
    input  wire        ex_illegal,    // 当前指令非法
    input  wire        ex_mret,       // 当前指令是 mret
    input  wire        ex_sret,       // 当前指令是 sret
    input  wire        ex_page_fault, // 页错误异常
    input  wire [31:0] ex_page_fault_addr, // 出错的虚拟地址
    input  wire        is_store,      // 是否为 store 操作（用于区分页错误类型）
    input  wire [31:0] current_pc,    // 当前 PC
    input  wire [31:0] current_instr, // 当前指令（用于 mtval）

    // 中断源（暂未使用）
    input  wire        int_soft,
    input  wire        int_timer,
    input  wire        int_ext,

    // 指令退休信号（用于 minstret）
    input  wire        inst_retire,

    // 异常/中断处理结果
    output reg         trap_taken,    // 是否发生异常/中断（仅维持一个周期）
    output wire [31:0] trap_pc,       // 跳转地址（异常时 = mtvec，mret 时 = mepc，sret 时 = sepc）
    output reg         flush_pipeline,// 冲刷流水线（用于异常、mret、sret）

    // 当前特权级输出
    output reg  [1:0]  privilege,     // 当前特权级：0=U, 1=S, 3=M

    // 提供给顶层的 mepc/sepc/satp 值
    output wire [31:0] mepc_value,
    output wire [31:0] sepc_value,
    output wire [31:0] satp_value
);

    // -------------------- CSR 寄存器定义 --------------------
    // 机器模式
    reg [31:0] mstatus;  // 0x300
    reg [31:0] misa;     // 0x301
    reg [31:0] mie;      // 0x304
    reg [31:0] mtvec;    // 0x305
    reg [31:0] mscratch; // 0x340
    reg [31:0] mepc;     // 0x341
    reg [31:0] mcause;   // 0x342
    reg [31:0] mtval;    // 0x343
    reg [31:0] mip;      // 0x344
    // 监管者模式
    reg [31:0] sstatus;  // 0x100 (是 mstatus 的子集)
    reg [31:0] sie;      // 0x104
    reg [31:0] stvec;    // 0x105
    reg [31:0] sscratch; // 0x140
    reg [31:0] sepc;     // 0x141
    reg [31:0] scause;   // 0x142
    reg [31:0] stval;    // 0x143
    reg [31:0] sip;      // 0x144
    reg [31:0] satp;     // 0x180

    // 性能计数器
    reg [31:0] mcycle;   // 0xB00
    reg [31:0] mcycleh;  // 0xB80
    reg [31:0] minstret; // 0xB02
    reg [31:0] minstreth;// 0xB82
    reg [31:0] mhartid;  // 0xF14

    reg [31:0] trap_pc_reg;

    // 特权级编码
    localparam PRIV_M = 2'b11;
    localparam PRIV_S = 2'b01;
    localparam PRIV_U = 2'b00;

    // 异常原因编码
    localparam CAUSE_ECALL_U = 32'h8;
    localparam CAUSE_ECALL_S = 32'h9;
    localparam CAUSE_ECALL_M = 32'hB;
    localparam CAUSE_BREAKPOINT = 32'h3;
    localparam CAUSE_ILLEGAL_INSTR = 32'h2;
    localparam CAUSE_LOAD_PAGE_FAULT  = 32'hD;  // 13
    localparam CAUSE_STORE_PAGE_FAULT = 32'hF;  // 15

    // 初始化
    integer i;
    initial begin
        mstatus = 32'h00001800; // MPP=3 (M-mode), MIE=0, MPIE=0, SPP=0, SIE=0, SPIE=0
        sstatus = 32'h00000000; // SIE=0, SPIE=0, SPP=0
        misa    = 32'h40000100; // RV32I (MXL=1, I=1)
        mie     = 32'h0;
        sie     = 32'h0;
        mtvec   = 32'h0;
        stvec   = 32'h0;
        mscratch = 32'h0;
        sscratch = 32'h0;
        mepc    = 32'h0;
        sepc    = 32'h0;
        mcause  = 32'h0;
        scause  = 32'h0;
        mtval   = 32'h0;
        stval   = 32'h0;
        mip     = 32'h0;
        sip     = 32'h0;
        satp    = 32'h0;
        mcycle  = 32'h0;
        mcycleh = 32'h0;
        minstret = 32'h0;
        minstreth = 32'h0;
        mhartid = 32'h0;
        privilege = PRIV_M;
    end

    // CSR 读操作（组合逻辑）
    always @(*) begin
        case (addr)
            // 机器模式
            12'h300: rdata = mstatus;
            12'h301: rdata = misa;
            12'h304: rdata = mie;
            12'h305: rdata = mtvec;
            12'h340: rdata = mscratch;
            12'h341: rdata = mepc;
            12'h342: rdata = mcause;
            12'h343: rdata = mtval;
            12'h344: rdata = mip;
            // 监管者模式
            12'h100: rdata = sstatus;
            12'h104: rdata = sie;
            12'h105: rdata = stvec;
            12'h140: rdata = sscratch;
            12'h141: rdata = sepc;
            12'h142: rdata = scause;
            12'h143: rdata = stval;
            12'h144: rdata = sip;
            12'h180: rdata = satp;
            // 性能计数器
            12'hB00: rdata = mcycle;
            12'hB80: rdata = mcycleh;
            12'hB02: rdata = minstret;
            12'hB82: rdata = minstreth;
            12'hF14: rdata = mhartid;
            default: rdata = 32'h0;
        endcase
    end

    // CSR 写操作（时序逻辑）
    always @(posedge clk) begin
        if (we) begin
            case (addr)
                // 机器模式
                12'h300: if (privilege >= 3) mstatus <= wdata;
                12'h301: if (privilege >= 3) misa    <= wdata;
                12'h304: if (privilege >= 3) mie     <= wdata;
                12'h305: if (privilege >= 3) mtvec   <= wdata;
                12'h340: if (privilege >= 3) mscratch <= wdata;
                12'h341: if (privilege >= 1) mepc    <= wdata;
                12'h342: if (privilege >= 3) mcause  <= wdata;
                12'h343: if (privilege >= 3) mtval   <= wdata;
                12'h344: if (privilege >= 3) mip     <= wdata;
                // 监管者模式
                12'h100: if (privilege >= 1) sstatus <= wdata;
                12'h104: if (privilege >= 1) sie     <= wdata;
                12'h105: if (privilege >= 1) stvec   <= wdata;
                12'h140: if (privilege >= 1) sscratch <= wdata;
                12'h141: if (privilege >= 1) sepc    <= wdata;
                12'h142: if (privilege >= 1) scause  <= wdata;
                12'h143: if (privilege >= 1) stval   <= wdata;
                12'h144: if (privilege >= 1) sip     <= wdata;
                12'h180: if (privilege >= 1) satp    <= wdata;
                // 性能计数器等
                12'hB00: if (privilege >= 3) mcycle  <= wdata;
                12'hB80: if (privilege >= 3) mcycleh <= wdata;
                12'hB02: if (privilege >= 3) minstret <= wdata;
                12'hB82: if (privilege >= 3) minstreth <= wdata;
                12'hF14: if (privilege >= 3) mhartid <= wdata;
                default: ;
            endcase
        end
    end

    // 性能计数器递增
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mcycle  <= 32'h0;
            mcycleh <= 32'h0;
        end else begin
            {mcycleh, mcycle} <= {mcycleh, mcycle} + 64'h1;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            minstret  <= 32'h0;
            minstreth <= 32'h0;
        end else if (inst_retire) begin
            {minstreth, minstret} <= {minstreth, minstret} + 64'h1;
        end
    end

    // -------------------- 异常处理（支持页错误）--------------------
    wire take_exception = ex_ecall || ex_ebreak || ex_illegal || ex_page_fault;

    reg exception_pending;
    reg [31:0] exception_cause;
    reg [31:0] exception_pc;
    reg [31:0] exception_tval;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            exception_pending <= 1'b0;
            trap_taken        <= 1'b0;
            flush_pipeline    <= 1'b0;
            trap_pc_reg       <= 32'h0;
        end else begin
            trap_taken     <= 1'b0;
            flush_pipeline <= 1'b0;

            if (exception_pending) begin
                // 提交异常
                trap_taken     <= 1'b1;
                flush_pipeline <= 1'b1;
                trap_pc_reg    <= mtvec;
                mepc    <= exception_pc;
                mcause  <= exception_cause;
                mtval   <= exception_tval;
                // 更新 mstatus：保存当前特权级到 MPP，关闭 MIE
                mstatus <= {mstatus[31:13], privilege, mstatus[10:4], 1'b0, mstatus[2:0]};
                // 特权级切换到 M-mode
                privilege <= PRIV_M;
                exception_pending <= 1'b0;
            end else if (take_exception && !exception_pending) begin
                exception_pending <= 1'b1;
                exception_pc      <= current_pc;
                if (ex_ecall) begin
                    case (privilege)
                        PRIV_U: exception_cause <= CAUSE_ECALL_U;
                        PRIV_S: exception_cause <= CAUSE_ECALL_S;
                        PRIV_M: exception_cause <= CAUSE_ECALL_M;
                        default: exception_cause <= CAUSE_ECALL_M;
                    endcase
                    exception_tval <= 32'h0;
                end else if (ex_ebreak) begin
                    exception_cause <= CAUSE_BREAKPOINT;
                    exception_tval <= 32'h0;
                end else if (ex_illegal) begin
                    exception_cause <= CAUSE_ILLEGAL_INSTR;
                    exception_tval <= current_instr;
                end else if (ex_page_fault) begin
                    exception_cause <= is_store ? CAUSE_STORE_PAGE_FAULT : CAUSE_LOAD_PAGE_FAULT;
                    exception_tval <= ex_page_fault_addr;
                end else begin
                    exception_cause <= 32'h0;
                    exception_tval <= 32'h0;
                end
            end
        end
    end

    // -------------------- mret 和 sret 处理 --------------------
    reg mret_pending;
    reg sret_pending;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mret_pending <= 1'b0;
            sret_pending <= 1'b0;
            trap_pc_reg  <= 32'h0;
        end else begin
            // 注意：flush_pipeline 可能被多个源同时拉高，此处用或逻辑，但为简化，我们分别赋值
            // 由于异常和 mret/sret 不会同时发生（优先级已处理），可以直接赋值
            // 但为安全，将 flush_pipeline 的赋值放在各个分支，并用或逻辑合并？此处我们仍采用顺序，异常优先已在上面处理
            if (mret_pending) begin
                flush_pipeline <= 1'b1;
                trap_pc_reg    <= mepc;
                privilege      <= mstatus[12:11];
                mstatus        <= {mstatus[31:8], 1'b1, mstatus[6:4], mstatus[7], mstatus[2:0]};
                mret_pending   <= 1'b0;
            end else if (ex_mret && !exception_pending && !mret_pending && !sret_pending) begin
                mret_pending <= 1'b1;
            end

            if (sret_pending) begin
                flush_pipeline <= 1'b1;
                trap_pc_reg    <= sepc;
                privilege      <= sstatus[8] ? PRIV_S : PRIV_U;
                sstatus        <= {sstatus[31:6], 1'b1, sstatus[4:0]};
                sret_pending   <= 1'b0;
            end else if (ex_sret && !exception_pending && !mret_pending && !sret_pending) begin
                sret_pending <= 1'b1;
            end
        end
    end

    // 返回目标 PC（使用寄存器输出）
    assign trap_pc = trap_pc_reg;

    // 输出 mepc/sepc/satp 供顶层使用
    assign mepc_value = mepc;
    assign sepc_value = sepc;
    assign satp_value = satp;

endmodule