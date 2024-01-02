module RWLogic (
input [7:0] globalBus, // 8-bit global bus
input A0, // Indicates for the command words
input CS, // Chip select (active low)
input WR, // Write signal (active low)
input RD, // Read signal (active low)
output reg [7:0] ICW1, // ICW1 register
output reg [7:0] ICW2, // ICW2 register
output reg [7:0] ICW3, // ICW3 register
output reg [7:0] ICW4, // ICW4 register
output reg [7:0] OCW1, // OCW1 register
output reg [7:0] OCW2, // OCW2 register
output reg [7:0] OCW3, // OCW3 register
output reg [3:0] ICWFlags, // ICW flags to check if ICW1, ICW2, ICW3, ICW4 have been written to
output shouldInitiateFlags // flag to indicate if ICWFlags should be reset
);

wire chipSelected = ~CS;
wire writeSignal = ~WR;
wire readSignal = ~RD;

// initialize registers ICWFlags to 0
assign shouldInitiateFlags = ~A0 && globalBus[4] && chipSelected && readSignal;
always @(A0) begin
    if (shouldInitiateFlags) begin
        ICWFlags <= 0;
    end
end

// assign values to ICW registers
always @(globalBus or A0) begin
    // ICW1 is special case since it's the first command word
    if(shouldInitiateFlags) begin
        ICW1 <= globalBus;
        ICWFlags[0] <= 1;
        // handle case where ICW3 is not needed
        if(globalBus[1]) begin
            ICWFlags[2] <= 1;
        end
        // handle case where ICW4 is not needed
        if(~globalBus[0]) begin
            ICWFlags[3] <= 1;
        end
    end

    if(chipSelected && readSignal && ~&ICWFlags) begin
        if(A0 && ICWFlags[0] && ~ICWFlags[1]) begin
            ICW2 <= globalBus;
            ICWFlags[1] <= 1;
        end
        if(A0 && ICWFlags[0] && ICWFlags[1] && ~ICWFlags[2]) begin
            ICW3 <= globalBus;
            ICWFlags[2] <= 1;
        end
        if(A0 && ICWFlags[0] && ICWFlags[1] && ICWFlags[2] && ~ICWFlags[3]) begin
            ICW4 <= globalBus;
            ICWFlags[3] <= 1;
        end
    end
end

// assign values to OCW registers
always @(globalBus or A0) begin
    if(chipSelected && readSignal && &ICWFlags) begin
        if(A0) begin
            OCW1 <= globalBus;
        end
        if(~A0 && ~globalBus[3]) begin
            OCW2 <= globalBus;
        end
        if(~A0 && globalBus[3]) begin
            OCW3 <= globalBus;
        end
    end
end

endmodule


module RWLogicTB;
reg [7:0] globalBus;
reg A0;
reg CS = 1'b1;
reg WR = 1'b1;
reg RD = 1'b1;
wire [7:0] ICW1;
wire [7:0] ICW2;
wire [7:0] ICW3;
wire [7:0] ICW4;
wire [7:0] OCW1;
wire [7:0] OCW2;
wire [7:0] OCW3;
wire [3:0] ICWFlags;

RWLogic rwLogic(
.globalBus(globalBus),
.A0(A0),
.CS(CS),
.WR(WR),
.RD(RD),
.ICW1(ICW1),
.ICW2(ICW2),
.ICW3(ICW3),
.ICW4(ICW4),
.OCW1(OCW1),
.OCW2(OCW2),
.OCW3(OCW3),
.ICWFlags(ICWFlags)
);

initial begin
    CS = 1'b0;
    RD = 1'b0;
    globalBus <= 8'b00010001;
    A0 <= 1'b0;
    #10
    A0 <= 1'b1;
    globalBus <= 8'b00000000;
    #10
    A0 <= 1'b1;
    globalBus <= 8'b00000001;
    #10;
    A0 <= 1'b1;
    globalBus <= 8'b00100001;
    #10;
    // now all the ICW registers should be set
    // now we can test the OCW registers
    // start with OCW2 to show that they aren't ordered
    A0 <= 1'b0;
    globalBus <= 8'b00000000;
    #10;
    A0 <= 1'b0;
    globalBus <= 8'b00001001;
    #10;
    A0 <= 1'b0;
    globalBus <= 8'b00000001;
    #10;
    A0 <= 1'b1;
    globalBus <= 8'b00000000;
end
endmodule

module NoIC4RWLogicTB;
reg [7:0] globalBus;
reg A0;
reg CS = 1'b1;
reg WR = 1'b1;
reg RD = 1'b1;
wire [7:0] ICW1;
wire [7:0] ICW2;
wire [7:0] ICW3;
wire [7:0] ICW4;
wire [7:0] OCW1;
wire [7:0] OCW2;
wire [7:0] OCW3;
wire [3:0] ICWFlags;

RWLogic rwLogic(
.globalBus(globalBus),
.A0(A0),
.CS(CS),
.WR(WR),
.RD(RD),
.ICW1(ICW1),
.ICW2(ICW2),
.ICW3(ICW3),
.ICW4(ICW4),
.OCW1(OCW1),
.OCW2(OCW2),
.OCW3(OCW3),
.ICWFlags(ICWFlags)
);

initial begin
    CS = 1'b0;
    RD = 1'b0;
    globalBus <= 8'b00010000;
    A0 <= 1'b0;
    #10
    A0 <= 1'b1;
    globalBus <= 8'b00000000;
    #10
    A0 <= 1'b1;
    globalBus <= 8'b00000001;
    #10;
    // now all the ICW registers should be set
    // now we can test the OCW registers
    // start with OCW2 to show that they aren't ordered
    A0 <= 1'b0;
    globalBus <= 8'b00000000;
    #10;
    A0 <= 1'b0;
    globalBus <= 8'b00001001;
    #10;
    A0 <= 1'b0;
    globalBus <= 8'b00000001;
    #10;
    A0 <= 1'b1;
    globalBus <= 8'b00000000;
end
endmodule
