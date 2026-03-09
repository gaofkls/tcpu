module alu (
    input [31:0] a,
    input [31:0] b,
    input [3:0] alu_ctrl,
    output reg [31:0] result,
    output zero
);
    assign zero = (result == 32'h0);

    always @(*) begin
        case (alu_ctrl)
            4'b0000: result = a + b;                    // add
            4'b0001: result = a - b;                    // sub
            4'b0010: result = a << b[4:0];               // sll
            4'b0011: result = ($signed(a) < $signed(b)) ? 32'h1 : 32'h0; // slt
            4'b0100: result = (a < b) ? 32'h1 : 32'h0;   // sltu
            4'b0101: result = a ^ b;                     // xor
            4'b0110: result = a >> b[4:0];                // srl (逻辑右移)
            4'b0111: result = $signed(a) >>> b[4:0];      // sra (算术右移)
            4'b1000: result = a | b;                     // or
            4'b1001: result = a & b;                     // and
            default: result = 32'h0;
        endcase
    end
endmodule