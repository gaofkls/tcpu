// hazard_detection_unit.v
module hazard_detection (
    input [4:0] id_ex_rd,
    input id_ex_mem_read,          // load指令标志（由控制单元产生，可复用mem_to_reg或单独信号）
    input [4:0] if_id_rs1,
    input [4:0] if_id_rs2,
    input branch_taken,             // 来自EX/MEM的分支结果
    input jump_taken,                // 来自EX/MEM的跳转结果（jal或jalr）
    output reg stall_pc,
    output reg stall_if_id,
    output reg flush_id_ex,
    output reg flush_if_id          // 用于控制冒险时冲刷IF/ID
);
    always @(*) begin
        stall_pc     = 1'b0;
        stall_if_id  = 1'b0;
        flush_id_ex  = 1'b0;
        flush_if_id  = 1'b0;

        // load-use 数据冒险
        if (id_ex_mem_read && id_ex_rd != 5'b0 && (id_ex_rd == if_id_rs1 || id_ex_rd == if_id_rs2)) begin
            stall_pc     = 1'b1;
            stall_if_id  = 1'b1;
            flush_id_ex  = 1'b1; // 将当前ID/EX指令置为气泡
        end

        // 控制冒险：分支或跳转发生时，需要冲刷IF/ID和ID/EX中的错误指令
        if (branch_taken || jump_taken) begin
            flush_id_ex  = 1'b1;
            flush_if_id  = 1'b1; // IF/ID也需要冲刷
        end
    end
endmodule