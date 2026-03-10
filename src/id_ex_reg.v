// id_ex_reg.v
module id_ex_reg (
    input clk,
    input rst_n,
    input flush,
    input enable,          // 通常为1，当停顿为0时enable=1，此处简化：直接使用!stall
    // 输入来自ID阶段
    input [31:0] pc_plus4_i,
    input [31:0] rs1_data_i,
    input [31:0] rs2_data_i,
    input [31:0] imm_i,
    input [4:0] rs1_addr_i,
    input [4:0] rs2_addr_i,
    input [4:0] rd_addr_i,
    input [3:0] alu_ctrl_i,
    input       alu_src_i,
    input       mem_write_i,
    input       mem_to_reg_i,   // 来自wb_sel[0]?
    input       reg_write_i,
    input       branch_i,
    input       jal_i,
    input       jalr_i,
    input [1:0] alu_a_sel_i,
    input [2:0] funct3_i,
    // 输出
    output reg [31:0] pc_plus4_o,
    output reg [31:0] rs1_data_o,
    output reg [31:0] rs2_data_o,
    output reg [31:0] imm_o,
    output reg [4:0] rs1_addr_o,
    output reg [4:0] rs2_addr_o,
    output reg [4:0] rd_addr_o,
    output reg [3:0] alu_ctrl_o,
    output reg       alu_src_o,
    output reg       mem_write_o,
    output reg       mem_to_reg_o,
    output reg       reg_write_o,
    output reg       branch_o,
    output reg       jal_o,
    output reg       jalr_o,
    output reg [1:0] alu_a_sel_o,
    output reg [2:0] funct3_o
);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc_plus4_o    <= 32'h0;
            rs1_data_o    <= 32'h0;
            rs2_data_o    <= 32'h0;
            imm_o         <= 32'h0;
            rs1_addr_o    <= 5'h0;
            rs2_addr_o    <= 5'h0;
            rd_addr_o     <= 5'h0;
            alu_ctrl_o    <= 4'h0;
            alu_src_o     <= 1'b0;
            mem_write_o   <= 1'b0;
            mem_to_reg_o  <= 1'b0;
            reg_write_o   <= 1'b0;
            branch_o      <= 1'b0;
            jal_o         <= 1'b0;
            jalr_o        <= 1'b0;
            alu_a_sel_o   <= 2'b0;
            funct3_o      <= 3'b0;
        end else if (flush) begin
            reg_write_o   <= 1'b0;
            mem_write_o   <= 1'b0;
            branch_o      <= 1'b0;
            jal_o         <= 1'b0;
            jalr_o        <= 1'b0;
            // 其他信号可以保留或清零，但控制信号清零已足够形成气泡
        end else if (enable) begin
            pc_plus4_o    <= pc_plus4_i;
            rs1_data_o    <= rs1_data_i;
            rs2_data_o    <= rs2_data_i;
            imm_o         <= imm_i;
            rs1_addr_o    <= rs1_addr_i;
            rs2_addr_o    <= rs2_addr_i;
            rd_addr_o     <= rd_addr_i;
            alu_ctrl_o    <= alu_ctrl_i;
            alu_src_o     <= alu_src_i;
            mem_write_o   <= mem_write_i;
            mem_to_reg_o  <= mem_to_reg_i;
            reg_write_o   <= reg_write_i;
            branch_o      <= branch_i;
            jal_o         <= jal_i;
            jalr_o        <= jalr_i;
            alu_a_sel_o   <= alu_a_sel_i;
            funct3_o      <= funct3_i;
        end
    end
endmodule