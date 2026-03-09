module imem (
    input [31:0] addr,
    output reg [31:0] instr
);
    // 定义一个深度为1024的存储器（可根据需要调整）
    reg [31:0] mem [0:1023];

initial begin
    $readmemh("program.hex", mem);
end

    always @(*) begin
        // 地址右移2位，因为按字节寻址，但指令按字对齐
        instr = mem[addr[31:2]];
    end
endmodule