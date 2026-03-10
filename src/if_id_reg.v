// if_id_reg.v
module if_id_reg (
    input clk,
    input rst_n,
    input flush,          // 冲刷信号：将寄存器置为nop
    input stall,          // 停顿信号：保持当前值
    input [31:0] pc_plus4_in,
    input [31:0] instr_in,
    output reg [31:0] pc_plus4_out,
    output reg [31:0] instr_out
);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc_plus4_out <= 32'h0;
            instr_out    <= 32'h00000013; // nop (addi x0,x0,0)
        end else if (!stall) begin
            if (flush) begin
                pc_plus4_out <= 32'h0;
                instr_out    <= 32'h00000013; // 插入nop
            end else begin
                pc_plus4_out <= pc_plus4_in;
                instr_out    <= instr_in;
            end
        end
    end
endmodule