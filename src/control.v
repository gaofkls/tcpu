module control_unit (
    input [6:0] opcode,
    input [2:0] funct3,
    input [6:0] funct7,
    output reg reg_write,
    output reg alu_src,
    output reg mem_write,
    output reg branch,
    output reg jal,
    output reg jalr,
    output reg [1:0] alu_op,
    output reg [2:0] imm_sel,
    output reg [1:0] wb_sel,       // 写回数据选择：00=ALU结果，01=存储器数据，10=PC+4
    output reg [1:0] alu_a_sel     // ALU输入a选择：00=rs1，01=PC，10=0
);
    always @(*) begin
        // 默认值初始化
        reg_write = 1'b0;
        alu_src   = 1'b0;
        mem_write = 1'b0;
        branch    = 1'b0;
        jal       = 1'b0;
        jalr      = 1'b0;
        alu_op    = 2'b00;
        imm_sel   = 3'b000;
        wb_sel    = 2'b00;
        alu_a_sel = 2'b00;

        case (opcode)
            7'b0110011: begin // R-type (add, sub, slt, etc.)
                reg_write = 1'b1;
                alu_src   = 1'b0;
                alu_op    = 2'b10;      // 由 funct3/funct7 决定具体操作
                wb_sel    = 2'b00;      // 写回 ALU 结果
                // alu_a_sel 默认为 rs1
            end

            7'b0010011: begin // I-type arithmetic (addi, andi, etc.)
                reg_write = 1'b1;
                alu_src   = 1'b1;       // 使用立即数
                alu_op    = 2'b11;      // I型算术
                imm_sel   = 3'b000;      // I型立即数
                wb_sel    = 2'b00;
            end

            7'b0000011: begin // 加载指令 (lb, lh, lw, lbu, lhu)
                reg_write = 1'b1;
                alu_src   = 1'b1;       // 地址偏移
                mem_write = 1'b0;
                alu_op    = 2'b00;      // 加法（地址计算）
                imm_sel   = 3'b000;      // I型立即数
                wb_sel    = 2'b01;      // 写回存储器数据
            end

            7'b0100011: begin // 存储指令 (sb, sh, sw)
                reg_write = 1'b0;
                alu_src   = 1'b1;       // 地址偏移
                mem_write = 1'b1;
                alu_op    = 2'b00;      // 加法（地址计算）
                imm_sel   = 3'b001;      // S型立即数
                // wb_sel 无关
            end

            7'b1100011: begin // 分支指令 (beq, bne, blt, etc.)
                branch    = 1'b1;
                alu_src   = 1'b0;       // 使用寄存器值比较
                alu_op    = 2'b01;      // 减法（用于比较）
                imm_sel   = 3'b010;      // B型立即数
                // wb_sel 无关
            end

            7'b1101111: begin // jal
                reg_write = 1'b1;
                jal       = 1'b1;
                alu_src   = 1'b1;       // 立即数（用于计算目标地址）
                alu_op    = 2'b00;      // 加法（PC + imm）
                imm_sel   = 3'b100;      // J型立即数
                wb_sel    = 2'b10;      // 写回 PC+4
                alu_a_sel = 2'b01;      // ALU 输入 a 选择 PC
            end

            7'b1100111: begin // jalr
                reg_write = 1'b1;
                jalr      = 1'b1;
                alu_src   = 1'b1;       // 立即数
                alu_op    = 2'b00;      // 加法（rs1 + imm）
                imm_sel   = 3'b000;      // I型立即数
                wb_sel    = 2'b10;      // 写回 PC+4
                alu_a_sel = 2'b00;      // ALU 输入 a 选择 rs1
            end

            7'b0110111: begin // lui
                reg_write = 1'b1;
                alu_src   = 1'b1;       // 立即数
                alu_op    = 2'b00;      // 加法（0 + imm）
                imm_sel   = 3'b011;      // U型立即数
                wb_sel    = 2'b00;      // 写回 ALU 结果
                alu_a_sel = 2'b10;      // ALU 输入 a 选择 0
            end

            7'b0010111: begin // auipc
                reg_write = 1'b1;
                alu_src   = 1'b1;
                alu_op    = 2'b00;
                imm_sel   = 3'b011;      // U型立即数
                wb_sel    = 2'b00;
                alu_a_sel = 2'b01;      // ALU 输入 a 选择 PC
            end

            // 其他 opcode（如 fence, ecall, ebreak）可忽略或添加默认处理
            default: ;
        endcase
    end
endmodule