module ISR(
    input [2:0] highestPriority,      // Input priority signal
    input [7:0] AddressBase,          // Input address base signal coming from the ICW2 T7-T3 pins
    input INTA,                       // Input active low signal
    input currentPulse,               // Input signal indicating current pulse
    output reg [7:0] currentAddress // Output address signal
);
    
    always @(posedge INTA) begin
        // if this is the end of the first pulse, then save the highest priority
        if (currentPulse === 0) begin
            currentAddress <= AddressBase | highestPriority;
        end else begin
            // if this is the end of the second pulse, then reset the current address
            currentAddress <= 8'bzzzzzzzz;
        end
    end
    
endmodule


module ISR_tb;

reg [2:0] highestPriority;
reg INTA;
reg currentPulse;
wire [7:0] currentAddress;

ISR ISR(
    .highestPriority(highestPriority),
    .AddressBase(8'b00100000),
    .INTA(INTA),
    .currentPulse(currentPulse),
    .currentAddress(currentAddress)
);

initial begin
  highestPriority = 3'bzzz;
  INTA = 1'b1;
  #10;
  INTA = 1'b0;
  currentPulse = 1'b0;
  highestPriority = 3'b010;
  #10;
  INTA = 1'b1;
  #10;
  INTA = 1'b0;
  currentPulse = 1'b1;
  #10;
  INTA = 1'b1;
end

endmodule


