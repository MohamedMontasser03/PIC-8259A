module PIC8259A(
    input VCC, // 5V power supply or 1 in simulation
    input A0, // address line 0 
    input INTA, // interrupt acknowledge
    input wire [7:0] IRBus, // interrupt request bus 
    output reg INT, // interrupt output 
    input SPEN, // Used for cascading and buffer control is ignored in this simulation
    inout wire [2:0] CASBus, // Cascade bus
    input CS, // chip select
    input WR, // write signal 
    input RD, // read signal 
    inout wire [7:0] DBus, // data bus 
    input GND // ground or 0 in simulation 
);

reg [7:0] DBusReg;
assign DBus = ~WR && ~CS ? DBusReg : 8'bz;

// internal registers
wire [7:0] ICW1;
wire [7:0] ICW2;
wire [7:0] ICW3;
wire [7:0] ICW4;
wire [7:0] OCW1;
wire [7:0] OCW2;
wire [7:0] OCW3;
wire shouldInitiateFlags;
wire [2:0] highestPriority;
reg currentPulse;
wire [7:0] irr;

wire LTIM = ICW1[3];
wire writeEnabled = ~WR && ~CS;

always @(shouldInitiateFlags) begin
    if(shouldInitiateFlags) begin
        currentPulse <= 1'b0;
        INT <= 1'b0;
    end
end

RWLogic rwLogic(
    .globalBus(DBus),
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
    .shouldInitiateFlags(shouldInitiateFlags)
);

IRR irrModule(
    .reset(shouldInitiateFlags),
    .LTIM(LTIM),
    .IRBus(IRBus),
    .highestPriority(highestPriority),
    .INTA(INTA),
    .currentPulse(currentPulse),
    .irr(irr)
);

Priority_resolver priority_resolver(
    .autoRotateMode(1'b0),
    .irr(irr),
    .imr(OCW1),
    .highestPriority(highestPriority)
);

wire [7:0] ISROutput;
ISR isr(
    .highestPriority(highestPriority),
    .AddressBase(ICW2),
    .INTA(INTA),
    .currentPulse(currentPulse),
    .currentAddress(ISROutput)
);

// set interrupt output
wire interruptExists = |(irr & ~OCW1);
always @(highestPriority or INT) begin
    if(~INT && interruptExists) begin
        INT <= 1'b1;
    end
end

// set current pulse
always @(posedge INTA) begin
    currentPulse <= ~currentPulse;
end

// reset interrupt output
always @(posedge INTA) begin
    if(currentPulse === 1) begin
        INT <= 1'b0;
        DBusReg <= 8'bzzzzzzzz;
    end
end

// send address to data bus
always @(negedge INTA) begin
    if(currentPulse === 1 && writeEnabled) begin
        if(interruptExists) begin
            DBusReg <= ISROutput;
        end else begin
            // make it look like interrupt is from pin 7, first 5 bits from ISR
            DBusReg <= {ISROutput[4:0], 3'b111};
        end
    end
end

endmodule

// shows basic operation of the PIC8259A interrupt handling
module PIC8259A_tb;
reg [7:0] globalBus;
wire [7:0] globalBusWire;
assign globalBusWire = globalBus;

reg [7:0] IRBus = 8'b00000000;
reg A0;
reg CS = 1'b1;
reg WR = 1'b1;
reg RD = 1'b1;
reg INTA = 1'b1;
wire INT;

PIC8259A pic8259A(
    .VCC(1'b1),
    .A0(A0),
    .INTA(INTA),
    .IRBus(IRBus),
    .INT(INT),
    .SPEN(1'b1),
    .CS(CS),
    .WR(WR),
    .RD(RD),
    .DBus(globalBusWire),
    .GND(1'b0)
);

initial begin
    CS = 1'b0;
    RD = 1'b0;
    // ICW1
    globalBus <= 8'b00010011;
    A0 <= 1'b0;
    #10
    A0 <= 1'b1;
    // ICW2
    globalBus <= 8'b11011000;
    #10;
    A0 <= 1'b1;
    // ICW4
    globalBus <= 8'b00000011;
    #10;

    // OCW1
    A0 <= 1'b1;
    globalBus <= 8'b00000001; // bit 0 is masked
    #10;
    // OCW2
    A0 <= 1'b0;
    globalBus <= 8'b01000000;
    #10;
    // OCW3
    A0 <= 1'b0;
    globalBus <= 8'b00001000; // last two bits are for read status
    #1;
    CS <= 1'b1;
    RD <= 1'b1;
    globalBus <= 8'bzzzzzzzz;

    // trigger interrupt
    #10;
    IRBus <= 8'b10001001;
    #50;
    // reset mask to test programmability
    CS <= 1'b0;
    RD <= 1'b0;
    A0 <= 1'b1;
    globalBus <= 8'b00000000;
    #1;
    CS <= 1'b1;
    RD <= 1'b1;
    globalBus <= 8'bzzzzzzzz;
end

always @(posedge INT) begin
    #5;
    // acknowledge interrupt pulse 1
    INTA <= 1'b0;
    #5;
    INTA <= 1'b1;
    #5;
    // acknowledge interrupt pulse 2
    INTA <= 1'b0;
    WR <= 1'b0;
    CS <= 1'b0;
    #5;
    INTA <= 1'b1;
    WR <= 1'b1;
    CS <= 1'b1;
end
endmodule

// test level triggerring
module PIC8259A_tb_level_trigger;
reg [7:0] globalBus;
wire [7:0] globalBusWire;
assign globalBusWire = globalBus;

reg [7:0] IRBus = 8'b00000000;
reg A0;
reg CS = 1'b1;
reg WR = 1'b1;
reg RD = 1'b1;
reg INTA = 1'b1;
wire INT;

PIC8259A pic8259A(
    .VCC(1'b1),
    .A0(A0),
    .INTA(INTA),
    .IRBus(IRBus),
    .INT(INT),
    .SPEN(1'b1),
    .CS(CS),
    .WR(WR),
    .RD(RD),
    .DBus(globalBusWire),
    .GND(1'b0)
);

initial begin
    CS = 1'b0;
    RD = 1'b0;
    // ICW1
    globalBus <= 8'b00011011;
    A0 <= 1'b0;
    #10
    A0 <= 1'b1;
    // ICW2
    globalBus <= 8'b11011000;
    #10;
    A0 <= 1'b1;
    // ICW4
    globalBus <= 8'b00000011;
    #10;

    // OCW1
    A0 <= 1'b1;
    globalBus <= 8'b00000000;
    #10;
    // OCW2
    A0 <= 1'b0;
    globalBus <= 8'b01000000;
    #10;
    // OCW3
    A0 <= 1'b0;
    globalBus <= 8'b00001000; // last two bits are for read status
    #1;
    CS <= 1'b1;
    RD <= 1'b1;
    globalBus <= 8'bzzzzzzzz;

    // trigger interrupt
    #10;
    IRBus <= 8'b00000001;
end

always @(posedge INT) begin
    #5;
    // acknowledge interrupt pulse 1
    INTA <= 1'b0;
    #5;
    INTA <= 1'b1;
    #5;
    // acknowledge interrupt pulse 2
    INTA <= 1'b0;
    WR <= 1'b0;
    CS <= 1'b0;
    #5;
    IRBus <= 8'b00000000; // reset interrupt since it is level triggered
    INTA <= 1'b1;
    WR <= 1'b1;
    CS <= 1'b1;
end
endmodule

// test when interrupt is lowered too soon
module PIC8259A_tb_too_soon;
reg [7:0] globalBus;
wire [7:0] globalBusWire;
assign globalBusWire = globalBus;

reg [7:0] IRBus = 8'b00000000;
reg A0;
reg CS = 1'b1;
reg WR = 1'b1;
reg RD = 1'b1;
reg INTA = 1'b1;
wire INT;

PIC8259A pic8259A(
    .VCC(1'b1),
    .A0(A0),
    .INTA(INTA),
    .IRBus(IRBus),
    .INT(INT),
    .SPEN(1'b1),
    .CS(CS),
    .WR(WR),
    .RD(RD),
    .DBus(globalBusWire),
    .GND(1'b0)
);

initial begin
    CS = 1'b0;
    RD = 1'b0;
    // ICW1
    globalBus <= 8'b00011011;
    A0 <= 1'b0;
    #10
    A0 <= 1'b1;
    // ICW2
    globalBus <= 8'b11011000;
    #10;
    A0 <= 1'b1;
    // ICW4
    globalBus <= 8'b00000011;
    #10;

    // OCW1
    A0 <= 1'b1;
    globalBus <= 8'b00000000;
    #10;
    // OCW2
    A0 <= 1'b0;
    globalBus <= 8'b01000000;
    #10;
    // OCW3
    A0 <= 1'b0;
    globalBus <= 8'b00001000; // last two bits are for read status
    #1;
    CS <= 1'b1;
    RD <= 1'b1;
    globalBus <= 8'bzzzzzzzz;

    // trigger interrupt
    #10;
    IRBus <= 8'b00000001;
end

always @(posedge INT) begin
    #5;
    // acknowledge interrupt pulse 1
    INTA <= 1'b0;
    #5;
    INTA <= 1'b1;
    IRBus <= 8'b00000000; // reset interrupt since it is level triggered
    #5;
    // acknowledge interrupt pulse 2
    INTA <= 1'b0;
    WR <= 1'b0;
    CS <= 1'b0;
    #5;
    INTA <= 1'b1;
    WR <= 1'b1;
    CS <= 1'b1;
end
endmodule

