module pc_reg (
    input clk,
    input rst_n,
    input [31:0] next_pc,
    output reg [31:0] pc
);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            pc <= 32'h0;            // 复位地址设为0，可根据需要修改
        else
            pc <= next_pc;
    end
endmodule