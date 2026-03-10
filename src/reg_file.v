module reg_file (
    input clk,
    input we,
    input [4:0] rs1_addr,
    input [4:0] rs2_addr,
    input [4:0] rd_addr,
    input [31:0] rd_data,
    output [31:0] rs1_data,
    output [31:0] rs2_data
);
    reg [31:0] regs [0:31];

    integer i;
    initial begin
        for (i = 0; i < 32; i = i + 1)
            regs[i] = 32'h0;
    end

    // 写优先：如果正在写同一个寄存器，直接旁路写数据
    assign rs1_data = (we && (rd_addr == rs1_addr) && (rs1_addr != 5'h0)) ? rd_data : 
                      (rs1_addr == 5'h0) ? 32'h0 : regs[rs1_addr];
    assign rs2_data = (we && (rd_addr == rs2_addr) && (rs2_addr != 5'h0)) ? rd_data : 
                      (rs2_addr == 5'h0) ? 32'h0 : regs[rs2_addr];

    // 写操作
    always @(posedge clk) begin
        if (we && (rd_addr != 5'h0))
            regs[rd_addr] <= rd_data;
    end
endmodule