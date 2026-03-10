module control_unit (
    input [6:0] opcode,
    input [2:0] funct3,
    input [6:0] funct7,
    output reg reg_write,
    output reg alu_src,
    output reg mem_write,
    output reg mem_read,        // 用于load-use检测
    output reg branch,
    output reg jal,
    output reg jalr,
    output reg [1:0] alu_op,
    output reg [2:0] imm_sel,
    output reg [1:0] wb_sel,    // 00:ALU, 01:mem, 10:PC+4
    output reg [1:0] alu_a_sel
);
    always @(*) begin
        // 默认值
        reg_write = 1'b0;
        alu_src   = 1'b0;
        mem_write = 1'b0;
        mem_read  = 1'b0;
        branch    = 1'b0;
        jal       = 1'b0;
        jalr      = 1'b0;
        alu_op    = 2'b00;
        imm_sel   = 3'b000;
        wb_sel    = 2'b00;
        alu_a_sel = 2'b00;

        case (opcode)
            7'b0110011: begin // R-type
                reg_write = 1'b1;
                alu_src   = 1'b0;
                alu_op    = 2'b10;
                wb_sel    = 2'b00;
            end

            7'b0010011: begin // I-type arithmetic
                reg_write = 1'b1;
                alu_src   = 1'b1;
                alu_op    = 2'b11;
                imm_sel   = 3'b000;
                wb_sel    = 2'b00;
            end

            7'b0000011: begin // load
                reg_write = 1'b1;
                alu_src   = 1'b1;
                mem_read  = 1'b1;
                alu_op    = 2'b00;
                imm_sel   = 3'b000;
                wb_sel    = 2'b01;
            end

            7'b0100011: begin // store
                reg_write = 1'b0;
                alu_src   = 1'b1;
                mem_write = 1'b1;
                alu_op    = 2'b00;
                imm_sel   = 3'b001;
            end

            7'b1100011: begin // branch
                branch    = 1'b1;
                alu_src   = 1'b0;
                alu_op    = 2'b01;
                imm_sel   = 3'b010;
            end

            7'b1101111: begin // jal
                reg_write = 1'b1;
                jal       = 1'b1;
                alu_src   = 1'b1;
                alu_op    = 2'b00;
                imm_sel   = 3'b100;
                wb_sel    = 2'b10;
                alu_a_sel = 2'b01;
            end

            7'b1100111: begin // jalr
                reg_write = 1'b1;
                jalr      = 1'b1;
                alu_src   = 1'b1;
                alu_op    = 2'b00;
                imm_sel   = 3'b000;
                wb_sel    = 2'b10;
                alu_a_sel = 2'b00;
            end

            7'b0110111: begin // lui
                reg_write = 1'b1;
                alu_src   = 1'b1;
                alu_op    = 2'b00;
                imm_sel   = 3'b011;
                wb_sel    = 2'b00;
                alu_a_sel = 2'b10;
            end

            7'b0010111: begin // auipc
                reg_write = 1'b1;
                alu_src   = 1'b1;
                alu_op    = 2'b00;
                imm_sel   = 3'b011;
                wb_sel    = 2'b00;
                alu_a_sel = 2'b01;
            end

            default: ;
        endcase
    end
endmodule