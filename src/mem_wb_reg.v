// mem_wb_reg.v
module mem_wb_reg (
    input clk,
    input rst_n,
    input flush,
    input enable,
    // 输入来自MEM阶段
    input [31:0] alu_result_i,
    input [31:0] mem_rdata_i,
    input [4:0] rd_addr_i,
    input       mem_to_reg_i,
    input       reg_write_i,
        // 新增输入
    input  [1:0] wb_sel_i,
    input [31:0] csr_rdata_i,
    input [31:0] pc_plus4_i,   // 如果原模块没有，需要添加
    // 输出
    output reg [31:0] alu_result_o,
    output reg [31:0] mem_rdata_o,
    output reg [4:0] rd_addr_o,
    output reg       mem_to_reg_o,
    output reg       reg_write_o,
        // 新增输出
    output reg [1:0] wb_sel_o,
    output reg [31:0] csr_rdata_o,
    output reg [31:0] pc_plus4_o
);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            alu_result_o  <= 32'h0;
            mem_rdata_o   <= 32'h0;
            rd_addr_o     <= 5'h0;
            mem_to_reg_o  <= 1'b0;
            reg_write_o   <= 1'b0;
              wb_sel_o     <= 2'b0;
        csr_rdata_o  <= 32'b0;
        pc_plus4_o   <= 32'b0;
        end else if (flush) begin
            reg_write_o   <= 1'b0;
            // 其他清零或保留，但reg_write清零已足够
        end else if (enable) begin
            alu_result_o  <= alu_result_i;
            mem_rdata_o   <= mem_rdata_i;
            rd_addr_o     <= rd_addr_i;
            mem_to_reg_o  <= mem_to_reg_i;
            reg_write_o   <= reg_write_i;
               wb_sel_o     <= wb_sel_i;
        csr_rdata_o  <= csr_rdata_i;
        pc_plus4_o   <= pc_plus4_i;
        end
    end
endmodule