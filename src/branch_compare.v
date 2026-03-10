module branch_compare (
    input [2:0] funct3,
    input [31:0] rs1_data,
    input [31:0] rs2_data,
    output reg br_taken
);
    always @(*) begin
        case (funct3)
            3'b000: br_taken = (rs1_data == rs2_data); // beq
            3'b001: br_taken = (rs1_data != rs2_data); // bne
            3'b100: br_taken = ($signed(rs1_data) < $signed(rs2_data)); // blt
            3'b101: br_taken = ($signed(rs1_data) >= $signed(rs2_data)); // bge
            3'b110: br_taken = (rs1_data < rs2_data); // bltu
            3'b111: br_taken = (rs1_data >= rs2_data); // bgeu
            default: br_taken = 1'b0;
        endcase
    end
endmodule