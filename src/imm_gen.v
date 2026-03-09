module imm_gen (
    input [31:0] instr,
    input [2:0] immsel,   // 用3位编码足够
    output reg [31:0] imm
);
    always @(*) begin
        case (immsel)
            3'b000:  // I-type
                imm = { {21{instr[31]}}, instr[30:20] };
            3'b001:  // S-type
                imm = { {21{instr[31]}}, instr[30:25], instr[11:7] };
            3'b010:  // B-type
                imm = { {20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0 };
            3'b011:  // U-type (lui, auipc)
                imm = { instr[31:12], 12'h0 };
            3'b100:  // J-type (jal)
                imm = { {12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0 };
            default: imm = 32'h0;
        endcase
    end
endmodule