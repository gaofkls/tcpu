module control_unit (
    input [6:0] opcode,
    input [2:0] funct3,
    input [6:0] funct7,
    output reg reg_write,
    output reg alu_src,
    output reg mem_write,
    output reg mem_to_reg,
    output reg branch,
    output reg [1:0] alu_op,
    output reg [2:0] imm_sel
);
    always @(*) begin
        reg_write = 1'b0; alu_src = 1'b0; mem_write = 1'b0; mem_to_reg = 1'b0; branch = 1'b0; alu_op = 2'b00; imm_sel = 3'b000;
        case (opcode)
            7'b0110011: begin // R-type
                reg_write = 1'b1;
                alu_op = 2'b10;
            end
            7'b0010011: begin // I-type (addi)
                reg_write = 1'b1;
                alu_src = 1'b1;
                alu_op = 2'b11;
                imm_sel = 3'b000;
            end
            7'b0000011: begin // lw
                reg_write = 1'b1;
                alu_src = 1'b1;
                mem_to_reg = 1'b1;
                alu_op = 2'b00;
                imm_sel = 3'b000;
            end
            7'b0100011: begin // sw
                alu_src = 1'b1;
                mem_write = 1'b1;
                alu_op = 2'b00;
                imm_sel = 3'b001;
            end
            7'b1100011: begin // beq
                branch = 1'b1;
                alu_op = 2'b01;  // 减法用于比较
                imm_sel = 3'b010;
            end
            default: ;
        endcase
    end
endmodule