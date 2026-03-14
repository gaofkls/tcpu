// timer.v
// 机器模式定时器 (MTIME/MTIMECMP) 内存映射
module timer (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        we,           // 写使能
    input  wire [31:0] addr,         // 物理地址
    input  wire [31:0] wdata,
    output reg  [31:0] rdata,
   output wire        irq_timer      // 改为 wire 类型
);

    // 寄存器定义
    reg [31:0] mtime;        // 当前计数器（低32位，可扩展为64位）
    reg [31:0] mtimecmp;     // 比较值（低32位）

    // 地址偏移（基址 0x2000000）
wire sel_mtime     = (addr == 32'h20000000);
wire sel_mtimecmp  = (addr == 32'h20000004);

    // 读操作
    always @(*) begin
        if (sel_mtime)      rdata = mtime;
        else if (sel_mtimecmp) rdata = mtimecmp;
        else                rdata = 32'h0;
    end

    // 写操作
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mtime <= 32'h0;
            mtimecmp <= 32'hFFFFFFFF;  // 初始不产生中断
        end else begin
            mtime <= mtime + 1'b1;      // 每个时钟周期递增
            if (we && sel_mtime)    mtime <= wdata;
            if (we && sel_mtimecmp) mtimecmp <= wdata;
        end
    end

    // 中断产生（当 mtime >= mtimecmp 时）
    assign irq_timer = (mtime >= mtimecmp);

endmodule