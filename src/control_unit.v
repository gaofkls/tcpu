module control_unit (
    input [6:0] opcode,
    input [2:0] funct3,
    input [6:0] funct7,
    input [31:0] instr,                // 新增：完整指令，用于区分 ecall/ebreak
    output reg reg_write,
    output reg alu_src,
    output reg mem_write,
    output reg mem_read,                // 用于load-use检测
    output reg branch,
    output reg jal,
    output reg jalr,
    output reg [1:0] alu_op,
    output reg [2:0] imm_sel,
    output reg [1:0] wb_sel,            // 00:ALU, 01:mem, 10:PC+4, 11:CSR
    output reg [1:0] alu_a_sel,
    // CSR 相关输出
    output reg [2:0] csr_op,
    output reg is_ecall,
    output reg is_ebreak,
    output reg is_mret,
    output reg is_csr,
    output reg is_sret
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
        // CSR 默认值
        csr_op    = 3'b000;
        is_ecall  = 1'b0;
        is_ebreak = 1'b0;
        is_mret   = 1'b0;
        is_csr    = 1'b0;
        is_sret = 1'b0;
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

            7'b1110011: begin // SYSTEM 类指令
                // 根据 funct3 和 instr 的高12位区分
                if (funct3 == 3'b000) begin
                    // ecall, ebreak, mret 等
                    if (instr[31:20] == 12'h000) begin
                        // ecall
                        is_ecall = 1'b1;
                    end else if (instr[31:20] == 12'h001) begin
                        // ebreak
                        is_ebreak = 1'b1;
                    end else if (instr[31:20] == 12'h302) begin
                        // mret (0x302)
                        is_mret = 1'b1;
                        // mret 实际上需要跳转，但控制信号保持默认，由 EX 阶段特殊处理
                          end else if (instr[31:20] == 12'h102) begin
                        is_sret = 1'b1;
                    end
                    // 其他 funct3=000 且非上述指令的，属于非法指令，这里先不处理
                end else begin
                    // CSR 指令 (funct3 != 000)
                    is_csr   = 1'b1;
                    csr_op   = funct3;          // CSR 操作类型
                    reg_write = 1'b1;            // 需要写目标寄存器
                    wb_sel    = 2'b11;            // 写回数据来自 CSR 读出值
                    // 其他控制信号清零（不需要 ALU 运算，也不访存）
                end
            end

            default: ;
        endcase
    end
endmodule