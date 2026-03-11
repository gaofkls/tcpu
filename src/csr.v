// csr.v
// 机器模式完整 CSR 实现（支持异常、mret 和中断）
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
    input  wire [31:0] current_pc,    // 当前 PC
    input  wire [31:0] current_instr, // 当前指令（用于 mtval）

    // 指令退休信号（用于 minstret）
    input  wire        inst_retire,   // 指令完成（非气泡、非异常）

    // 中断输入
    input  wire        int_soft,      // 软件中断（由 CLINT 产生）
    input  wire        int_timer,     // 定时器中断
    input  wire        int_ext,       // 外部中断

    // 异常/中断处理结果
    output reg         trap_taken,    // 是否发生异常或中断（仅维持一个周期）
    output wire [31:0] trap_pc,       // 跳转地址（异常/中断时 = mtvec，mret 时 = mepc）
    output reg         flush_pipeline,// 冲刷流水线（用于异常、中断和 mret）

    // 当前特权级输出
    output reg  [1:0]  privilege,     // 当前特权级：0=U, 1=S, 3=M

    // 提供给顶层的 mepc 值（用于 mret 跳转）
    output wire [31:0] mepc_value
);

    // CSR 寄存器定义（机器模式）
    reg [31:0] mstatus;  // 0x300
    reg [31:0] misa;     // 0x301
    reg [31:0] mie;      // 0x304
    reg [31:0] mtvec;    // 0x305
    reg [31:0] mscratch; // 0x340
    reg [31:0] mepc;     // 0x341
    reg [31:0] mcause;   // 0x342
    reg [31:0] mtval;    // 0x343
    reg [31:0] mip;      // 0x344
    // 性能计数器
    reg [31:0] mcycle;   // 0xB00
    reg [31:0] mcycleh;  // 0xB80
    reg [31:0] minstret; // 0xB02
    reg [31:0] minstreth;// 0xB82
    // 机器硬件ID
    reg [31:0] mhartid;  // 0xF14

    reg [31:0] trap_pc_reg;

    // 特权级编码
    localparam PRIV_M = 2'b11;
    localparam PRIV_S = 2'b01;
    localparam PRIV_U = 2'b00;

    // 异常原因编码（低12位，最高位为0表示异常）
    localparam CAUSE_ECALL_U = 32'h8;
    localparam CAUSE_ECALL_S = 32'h9;
    localparam CAUSE_ECALL_M = 32'hB;
    localparam CAUSE_BREAKPOINT = 32'h3;
    localparam CAUSE_ILLEGAL_INSTR = 32'h2;
    localparam CAUSE_MISALIGN_FETCH = 32'h0;
    localparam CAUSE_FETCH_ACCESS   = 32'h1;
    localparam CAUSE_MISALIGN_LOAD  = 32'h4;
    localparam CAUSE_LOAD_ACCESS    = 32'h5;
    localparam CAUSE_MISALIGN_STORE = 32'h6;
    localparam CAUSE_STORE_ACCESS   = 32'h7;

    // 中断原因编码（最高位为1）
    localparam INT_SOFT    = 3;  // 机器软件中断
    localparam INT_TIMER   = 7;  // 机器定时器中断
    localparam INT_EXT     = 11; // 机器外部中断

    // 初始化
    integer i;
    initial begin
        mstatus = 32'h00001800; // MPP=3 (M-mode), MIE=0, MPIE=0
        misa    = 32'h40000100; // RV32I (MXL=1, I=1)
        mie     = 32'h0;
        mtvec   = 32'h0;
        mscratch = 32'h0;
        mepc    = 32'h0;
        mcause  = 32'h0;
        mtval   = 32'h0;
        mip     = 32'h0;
        mcycle  = 32'h0;
        mcycleh = 32'h0;
        minstret = 32'h0;
        minstreth = 32'h0;
        mhartid = 32'h0;        // 单核，hartid=0
        privilege = PRIV_M;
    end

    // CSR 读操作（组合逻辑）
    always @(*) begin
        case (addr)
            12'h300: rdata = mstatus;
            12'h301: rdata = misa;
            12'h304: rdata = mie;
            12'h305: rdata = mtvec;
            12'h340: rdata = mscratch;
            12'h341: rdata = mepc;
            12'h342: rdata = mcause;
            12'h343: rdata = mtval;
            12'h344: rdata = mip;
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
        if (we && (privilege == PRIV_M)) begin // 仅 M 模式可写
            case (addr)
                12'h300: mstatus <= wdata;
                12'h301: misa    <= wdata;
                12'h304: mie     <= wdata;
                12'h305: mtvec   <= wdata;
                12'h340: mscratch <= wdata;
                12'h341: mepc    <= wdata;
                12'h342: mcause  <= wdata;
                12'h343: mtval   <= wdata;
                12'h344: mip     <= wdata; // 软件写优先
                12'hB00: mcycle  <= wdata;
                12'hB80: mcycleh <= wdata;
                12'hB02: minstret <= wdata;
                12'hB82: minstreth <= wdata;
                12'hF14: mhartid <= wdata; // 通常只读，但允许写入
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

    // 更新 mip 寄存器的中断挂起位（软件写优先）
    always @(posedge clk) begin
        if (we && addr == 12'h344) begin
            // 软件写优先，保持原值
        end else begin
            mip[INT_SOFT] <= int_soft;
            mip[INT_TIMER] <= int_timer;
            mip[INT_EXT]   <= int_ext;
            // 其他位保持不变
        end
    end

    // 组合逻辑：计算当前是否有待处理中断
    wire soft_pending = mip[INT_SOFT] && mie[INT_SOFT];
    wire timer_pending = mip[INT_TIMER] && mie[INT_TIMER];
    wire ext_pending = mip[INT_EXT] && mie[INT_EXT];

    // 中断优先级：外部 > 定时器 > 软件（简单按位优先级）
    wire int_pending = (ext_pending || timer_pending || soft_pending);
    wire [31:0] int_cause = ext_pending ? (32'h80000000 | INT_EXT) :
                            timer_pending ? (32'h80000000 | INT_TIMER) :
                            soft_pending ? (32'h80000000 | INT_SOFT) : 32'h0;

    // 中断被响应的条件：特权级低于 M 且 MIE 使能（mstatus[3]）
    wire take_int = int_pending && (privilege < PRIV_M) && mstatus[3];

    // 异常检测
    wire take_exception = ex_ecall || ex_ebreak || ex_illegal;

    // 异常/中断总触发（异常优先级高于中断）
    wire take_trap = take_exception || take_int;

    // 异常/中断处理状态机
    reg trap_pending;
    reg [31:0] trap_cause;
    reg [31:0] trap_pc_val;
    reg [31:0] trap_tval;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            trap_pending <= 1'b0;
            trap_taken   <= 1'b0;
            flush_pipeline <= 1'b0;
            trap_pc_reg  <= 32'h0;
        end else begin
            // 默认清除脉冲信号
            trap_taken     <= 1'b0;
            flush_pipeline <= 1'b0;

            if (trap_pending) begin
                // 提交 trap：更新 CSR，跳转到 mtvec
                trap_taken     <= 1'b1;
                flush_pipeline <= 1'b1;
                trap_pc_reg    <= mtvec;
                mepc    <= trap_pc_val;
                mcause  <= trap_cause;
                mtval   <= trap_tval;
                // 更新 mstatus：保存当前特权级到 MPP，关闭 MIE
                mstatus <= {mstatus[31:13], privilege, mstatus[10:4], 1'b0, mstatus[2:0]};
                trap_pending <= 1'b0;
            end else if (take_trap && !trap_pending) begin
                // 记录 trap，下一周期提交
                trap_pending <= 1'b1;
                trap_pc_val  <= current_pc;
                if (take_exception) begin
                    // 异常处理
                    if (ex_ecall) begin
                        case (privilege)
                            PRIV_U: trap_cause <= CAUSE_ECALL_U;
                            PRIV_S: trap_cause <= CAUSE_ECALL_S;
                            PRIV_M: trap_cause <= CAUSE_ECALL_M;
                            default: trap_cause <= CAUSE_ECALL_M;
                        endcase
                        trap_tval <= 32'h0;
                    end else if (ex_ebreak) begin
                        trap_cause <= CAUSE_BREAKPOINT;
                        trap_tval <= 32'h0;
                    end else if (ex_illegal) begin
                        trap_cause <= CAUSE_ILLEGAL_INSTR;
                        trap_tval <= current_instr;
                    end else begin
                        trap_cause <= 32'h0;
                        trap_tval <= 32'h0;
                    end
                end else begin
                    // 中断处理
                    trap_cause <= int_cause;
                    trap_tval <= 32'h0;
                end
            end
        end
    end

    // mret 处理
    reg mret_pending;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mret_pending <= 1'b0;
        end else begin
            if (mret_pending) begin
                // 提交 mret 效果：恢复特权级，更新 mstatus，并冲刷流水线
                flush_pipeline <= 1'b1;
                privilege <= mstatus[12:11];
                // 更新 mstatus：MIE = MPIE, MPIE = 1
                mstatus <= {mstatus[31:8], 1'b1, mstatus[6:4], mstatus[7], mstatus[2:0]};
                mret_pending <= 1'b0;
            end else if (ex_mret && !trap_pending) begin
                // 检测到 mret，下一周期提交
                mret_pending <= 1'b1;
            end
        end
    end

    assign trap_pc = trap_pc_reg;

    // mepc_value 输出（供顶层 mret 跳转使用）
    assign mepc_value = mepc;

endmodule