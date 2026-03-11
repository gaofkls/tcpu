// csr.v
// 机器模式核心 CSR 实现（支持异常和 mret，不含中断）
module csr (
    input  wire        clk,
    input  wire        rst_n,

    // 来自 EX 阶段的 CSR 操作请求
    input  wire [11:0] addr,          // CSR 地址
    input  wire [31:0] wdata,         // 写入数据
    input  wire [2:0]  op,            // CSR 操作类型（来自 funct3）
    input  wire        we,            // 写使能（由译码产生）
    output reg  [31:0] rdata,         // 读出数据（改为 reg 类型）

    // 异常相关
    input  wire        ex_ecall,      // 当前指令是 ecall
    input  wire        ex_ebreak,     // 当前指令是 ebreak
    input  wire        ex_illegal,    // 当前指令非法
    input  wire        ex_mret,       // 当前指令是 mret

    // 当前 PC（用于异常时保存到 mepc）
    input  wire [31:0] current_pc,

    // 异常处理结果
    output reg         trap_taken,    // 是否发生异常（仅维持一个周期）
    output wire [31:0] trap_pc,       // 跳转地址（异常时 = mtvec，mret 时 = mepc）
    output reg         flush_pipeline,// 冲刷流水线（用于异常和 mret）

    // 当前特权级输出
    output reg  [1:0]  privilege,     // 当前特权级：0=U, 1=S, 3=M

    // 提供给顶层的 mepc 值（用于 mret 跳转）
    output wire [31:0] mepc_value
);

    // CSR 寄存器定义（机器模式）
    reg [31:0] mstatus;  // 0x300
    reg [31:0] mtvec;    // 0x305
    reg [31:0] mepc;     // 0x341
    reg [31:0] mcause;   // 0x342
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

    // 初始化
    integer i;
    initial begin
        mstatus = 32'h00001800; // MPP=3 (M-mode), MIE=0, MPIE=0
        mtvec   = 32'h0;
        mepc    = 32'h0;
        mcause  = 32'h0;
        privilege = PRIV_M;
    end

    // CSR 读操作（组合逻辑）
    always @(*) begin
        case (addr)
            12'h300: rdata = mstatus;
            12'h305: rdata = mtvec;
            12'h341: rdata = mepc;
            12'h342: rdata = mcause;
            default: rdata = 32'h0;
        endcase
    end

    // CSR 写操作（时序逻辑）
    always @(posedge clk) begin
        if (we && (privilege == PRIV_M)) begin // 仅 M 模式可写
            case (addr)
                12'h300: mstatus <= wdata;
                12'h305: mtvec   <= wdata;
                12'h341: mepc    <= wdata;
                12'h342: mcause  <= wdata;
                default: ;
            endcase
        end
    end

    // 异常检测与处理
    wire take_exception = ex_ecall || ex_ebreak || ex_illegal;

    reg exception_pending;
    reg [31:0] exception_cause;
    reg [31:0] exception_pc;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            exception_pending <= 1'b0;
            trap_taken        <= 1'b0;
            flush_pipeline    <= 1'b0;
              trap_pc_reg <= 32'h0;
        end else begin
            // 默认清除脉冲信号
            trap_taken     <= 1'b0;
            flush_pipeline <= 1'b0;

            if (exception_pending) begin
                // 提交异常：更新 CSR，跳转到 mtvec
                trap_taken     <= 1'b1;
                flush_pipeline <= 1'b1;
            trap_pc_reg    <= mtvec;   // 锁存跳转目标
                mepc    <= exception_pc;
                mcause  <= exception_cause;
                // 更新 mstatus：保存当前特权级到 MPP，关闭 MIE
                // mstatus[12:11] = privilege, mstatus[3] = 0 (MIE 关)
                mstatus <= {mstatus[31:13], privilege, mstatus[10:4], 1'b0, mstatus[2:0]};
                // 特权级切换到 M 模式（已在 M 模式，不变）
                exception_pending <= 1'b0;
            end else if (take_exception && !exception_pending) begin
                // 记录异常，下一周期提交
                exception_pending <= 1'b1;
                exception_pc      <= current_pc;
                if (ex_ecall) begin
                    case (privilege)
                        PRIV_U: exception_cause <= CAUSE_ECALL_U;
                        PRIV_S: exception_cause <= CAUSE_ECALL_S;
                        PRIV_M: exception_cause <= CAUSE_ECALL_M;
                        default: exception_cause <= CAUSE_ECALL_M;
                    endcase
                end else if (ex_ebreak) begin
                    exception_cause <= CAUSE_BREAKPOINT;
                end else if (ex_illegal) begin
                    exception_cause <= CAUSE_ILLEGAL_INSTR;
                end else begin
                    exception_cause <= 32'h0;
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
            end else if (ex_mret && !exception_pending) begin
                // 检测到 mret，下一周期提交
                mret_pending <= 1'b1;
            end
        end
    end

    assign trap_pc = trap_pc_reg;

    // mepc_value 输出（供顶层 mret 跳转使用）
    assign mepc_value = mepc;

endmodule