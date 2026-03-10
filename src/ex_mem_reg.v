// ex_mem_reg.v
module ex_mem_reg (
    input clk,
    input rst_n,
    input flush,
    input enable,
    // 输入来自EX阶段
    input [31:0] pc_plus4_i,
    input [31:0] alu_result_i,
    input [31:0] rs2_data_i,    // 用于存储
    input [4:0] rd_addr_i,
    input       mem_write_i,
    input       mem_to_reg_i,
    input       reg_write_i,
    input       branch_taken_i,  // 分支是否实际发生
    input [31:0] branch_target_i,
    input [2:0] funct3_i,        // 用于存储器
    // 输出
    output reg [31:0] pc_plus4_o,
    output reg [31:0] alu_result_o,
    output reg [31:0] rs2_data_o,
    output reg [4:0] rd_addr_o,
    output reg       mem_write_o,
    output reg       mem_to_reg_o,
    output reg       reg_write_o,
    output reg       branch_taken_o,
    output reg [31:0] branch_target_o,
    output reg [2:0] funct3_o
);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc_plus4_o      <= 32'h0;
            alu_result_o    <= 32'h0;
            rs2_data_o      <= 32'h0;
            rd_addr_o       <= 5'h0;
            mem_write_o     <= 1'b0;
            mem_to_reg_o    <= 1'b0;
            reg_write_o     <= 1'b0;
            branch_taken_o  <= 1'b0;
            branch_target_o <= 32'h0;
            funct3_o        <= 3'b0;
        end else if (flush) begin
            reg_write_o     <= 1'b0;
            mem_write_o     <= 1'b0;
            branch_taken_o  <= 1'b0;
            // 其他可清零
        end else if (enable) begin
            pc_plus4_o      <= pc_plus4_i;
            alu_result_o    <= alu_result_i;
            rs2_data_o      <= rs2_data_i;
            rd_addr_o       <= rd_addr_i;
            mem_write_o     <= mem_write_i;
            mem_to_reg_o    <= mem_to_reg_i;
            reg_write_o     <= reg_write_i;
            branch_taken_o  <= branch_taken_i;
            branch_target_o <= branch_target_i;
            funct3_o        <= funct3_i;
        end
    end
endmodule