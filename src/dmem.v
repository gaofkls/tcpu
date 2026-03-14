module dmem (
    input clk,
    input we,
    input [31:0] addr,
    input [31:0] wdata,
    input [2:0] funct3,       // 新增，来自指令的funct3
    output reg [31:0] rdata
);
   
reg [31:0] mem [0:8191];
    // 写操作
    always @(posedge clk) begin
        if (we) begin
            case (funct3)
                3'b000: // sb: 存储字节
                    case (addr[1:0])
                        2'b00: mem[addr[31:2]][7:0]   <= wdata[7:0];
                        2'b01: mem[addr[31:2]][15:8]  <= wdata[7:0];
                        2'b10: mem[addr[31:2]][23:16] <= wdata[7:0];
                        2'b11: mem[addr[31:2]][31:24] <= wdata[7:0];
                    endcase
                3'b001: // sh: 存储半字
                    case (addr[1])
                        1'b0: mem[addr[31:2]][15:0]  <= wdata[15:0];
                        1'b1: mem[addr[31:2]][31:16] <= wdata[15:0];
                    endcase
                3'b010: // sw: 存储字
                    mem[addr[31:2]] <= wdata;
                default: ; // 其他funct3在存储指令中不会出现
            endcase
        end
    end

    // 读操作（组合逻辑）
    always @(*) begin
        case (funct3)
            3'b000: // lb: 加载字节，符号扩展
                case (addr[1:0])
                    2'b00: rdata = {{24{mem[addr[31:2]][7]}},  mem[addr[31:2]][7:0]};
                    2'b01: rdata = {{24{mem[addr[31:2]][15]}}, mem[addr[31:2]][15:8]};
                    2'b10: rdata = {{24{mem[addr[31:2]][23]}}, mem[addr[31:2]][23:16]};
                    2'b11: rdata = {{24{mem[addr[31:2]][31]}}, mem[addr[31:2]][31:24]};
                endcase
            3'b001: // lh: 加载半字，符号扩展
                case (addr[1])
                    1'b0: rdata = {{16{mem[addr[31:2]][15]}}, mem[addr[31:2]][15:0]};
                    1'b1: rdata = {{16{mem[addr[31:2]][31]}}, mem[addr[31:2]][31:16]};
                endcase
            3'b010: // lw: 加载字
                rdata = mem[addr[31:2]];
            3'b100: // lbu: 加载字节，零扩展
                case (addr[1:0])
                    2'b00: rdata = {24'h0, mem[addr[31:2]][7:0]};
                    2'b01: rdata = {24'h0, mem[addr[31:2]][15:8]};
                    2'b10: rdata = {24'h0, mem[addr[31:2]][23:16]};
                    2'b11: rdata = {24'h0, mem[addr[31:2]][31:24]};
                endcase
            3'b101: // lhu: 加载半字，零扩展
                case (addr[1])
                    1'b0: rdata = {16'h0, mem[addr[31:2]][15:0]};
                    1'b1: rdata = {16'h0, mem[addr[31:2]][31:16]};
                endcase
            default: rdata = 32'h0;
        endcase
    end
endmodule