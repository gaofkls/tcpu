module dmem (
    input clk,
    input we,
    input [31:0] addr,
    input [31:0] wdata,
    output reg [31:0] rdata
);
    reg [31:0] mem [0:1023]; // 深度1024

    always @(posedge clk) begin
        if (we)
            mem[addr[31:2]] <= wdata;
    end

    always @(*) begin
        rdata = mem[addr[31:2]];
    end
endmodule