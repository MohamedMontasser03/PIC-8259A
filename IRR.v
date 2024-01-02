module IRR (
    input reset, // Resets signal to initial state
    input LTIM, // For determining whether it will be edge or level triggered
    input [7:0] IRBus, // Vectorized input for interrupt signals
    input [2:0] highestPriority,      // Input priority signal
    input INTA,                       // Input active low signal
    input currentPulse,               // Input signal indicating current pulse
    output reg [7:0] irr, // Interrupt request register
    output interruptExists // Interrupt signal - 1 if any bit in irr is 1
);
    assign interruptExists = |irr;

    // Edge-triggered
    // only update the bit that had the edge
    genvar i;
    generate
        for (i = 0; i < 8; i = i + 1) begin
            always @(posedge IRBus[i]) begin
                if (!LTIM) begin
                    irr[i] <= IRBus[i];
                end
            end
        end
    endgenerate

    // Level-triggered
    always @(IRBus) begin
        if (LTIM) begin
            // If level-triggered, update the irr register with IRBus
            irr <= IRBus;
        end
    end

    always @(posedge reset) begin
        irr <= 8'b00000000;
    end

    // reset irr when INTA is high -> low on the second pulse
    always @(negedge INTA) begin
        if (currentPulse === 1) begin
            irr[highestPriority] <= 1'b0;
        end
    end
endmodule

// test both edge and level triggered
module IRR_tb;
    reg LTIM;
    reg [7:0] IRBus;
    reg reset;
    reg [2:0] highestPriority;
    reg INTA;
    reg currentPulse;
    wire [7:0] irr;
    wire interruptExists;

    // Instantiate the IRR module
    IRR dut (
        .LTIM(LTIM),
        .IRBus(IRBus),
        .irr(irr),
        .highestPriority(highestPriority),
        .INTA(INTA),
        .currentPulse(currentPulse),
        .interruptExists(interruptExists),
        .reset(reset)
    );

    // Stimulus and test cases
    initial begin
        reset = 0;
        INTA = 1;
        currentPulse = 1;
        highestPriority = 3'b101;
        #1
        reset = 1;
        #1
        // Edge-triggered
        LTIM = 0;
        IRBus = 8'b00000001;
        #10
        IRBus = 8'b00000010;
        #10
        IRBus = 8'b00000100;
        #10
        IRBus = 8'b00001000;
        #10
        IRBus = 8'b00010000;
        #10
        IRBus = 8'b00100000;
        #5
        INTA = 0;
        #10
        IRBus = 8'b11000001;
        #10

        // Level-triggered
        LTIM = 1;
        IRBus = 8'b00000001;
        #10
        IRBus = 8'b00000010;
        #10
        IRBus = 8'b00000100;
        #10
        IRBus = 8'b00001000;
        #10
        IRBus = 8'b00010000;
        #10
        IRBus = 8'b00100000;
        #10
        IRBus = 8'b01000000;
        #10
        IRBus = 8'b10000000;
    end
endmodule