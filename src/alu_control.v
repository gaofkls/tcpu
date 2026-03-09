module alu_control (
    input [1:0] alu_op,
    input [2:0] funct3,
    input [6:0] funct7,
    output reg [3:0] alu_ctrl
);
    always @(*) begin
        case (alu_op)
            2'b00: alu_ctrl = 4'b0000; // add
            2'b01: alu_ctrl = 4'b0001; // sub (用于beq)
            2'b10: begin // R-type
                case (funct3)
                    3'b000: alu_ctrl = (funct7[5] ? 4'b0001 : 4'b0000); // sub if funct7[5]=1, else add
                    3'b001: alu_ctrl = 4'b0010; // sll
                    3'b010: alu_ctrl = 4'b0011; // slt
                    3'b011: alu_ctrl = 4'b0100; // sltu
                    3'b100: alu_ctrl = 4'b0101; // xor
                    3'b101: alu_ctrl = (funct7[5] ? 4'b0111 : 4'b0110); // sra if funct7[5]=1, else srl
                    3'b110: alu_ctrl = 4'b1000; // or
                    3'b111: alu_ctrl = 4'b1001; // and
                endcase
            end
            2'b11: begin // I-type arithmetic (addi, etc.) - 基本同R-type，但无sub，且移位需要特殊处理
                case (funct3)
                    3'b000: alu_ctrl = 4'b0000; // addi
                    3'b001: alu_ctrl = 4'b0010; // slli (但需要检查funct7[5]==0)
                    3'b010: alu_ctrl = 4'b0011; // slti
                    3'b011: alu_ctrl = 4'b0100; // sltiu
                    3'b100: alu_ctrl = 4'b0101; // xori
                    3'b101: alu_ctrl = (funct7[5] ? 4'b0111 : 4'b0110); // srai if funct7[5]=1, else srli
                    3'b110: alu_ctrl = 4'b1000; // ori
                    3'b111: alu_ctrl = 4'b1001; // andi
                endcase
            end
            default: alu_ctrl = 4'b0000;
        endcase
    end
endmodule