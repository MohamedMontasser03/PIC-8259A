module Priority_resolver(
  input autoRotateMode,      // auto rotate mode
  input [7:0] irr,            // interrupt request register // 7 6 5 4 ........
  input [7:0] imr,            // interrupt mask register
  output reg[2:0] highestPriority  // the highest priority interrupt location
);
  wire [7:0] maskedIRR;
  reg dataHighImpedance;
  reg  [2:0] highestPriorityPos;

  assign maskedIRR = irr & (~imr);

  always @(maskedIRR) begin
    highestPriorityPos = 3'b000;

    if(highestPriority == 0) begin
      highestPriorityPos = 7;
    end 
    else begin
      highestPriorityPos = highestPriority - 1;
    end
  end

  integer i;
  // fully nested mode
  always @(maskedIRR) begin
    for (i = 7; i >= 0; i = i - 1) begin
      if (maskedIRR[i] && (~autoRotateMode || dataHighImpedance)) begin
        highestPriority = i;
        if (~dataHighImpedance)
          dataHighImpedance = 0;
      end
    end
  end

  // get the highest priority interrupt while taking into account the
  // value of highestPriorityPos
  // start the loop from highestPriorityPos + 1 to 7 and then from 0 to highestPriorityPos
  // this way we will get the highest priority interrupt
  always @(maskedIRR) begin
    for (i = highestPriorityPos + 1; i <= 7; i = i + 1) begin
      if (maskedIRR[i] && autoRotateMode) begin
        highestPriority = i;
        dataHighImpedance = 0;
      end
    end
    for (i = 0; i <= highestPriorityPos; i = i + 1) begin
      if (maskedIRR[i] && autoRotateMode) begin
        highestPriority = i;
        dataHighImpedance = 0;
      end
    end
  end

  always @(maskedIRR) begin
    if(~|maskedIRR) begin
      highestPriority = 3'bzzz;
      dataHighImpedance = 1;
    end
  end

endmodule



module Priority_resolver_tb;

  reg autoRotateMode;
  reg [7:0] irr, imr;
  wire [7:0]maskedIRR = irr & (~imr);
  wire [2:0] highestPriority;


  // Instantiate the Priority_resolver module
  Priority_resolver dut (
    .autoRotateMode(autoRotateMode),
    .irr(irr),
    .imr(imr),
    .highestPriority(highestPriority)
  );

  // Stimulus and test cases
  initial begin
    // Test case 1: Priority on IR7
    autoRotateMode = 0;
    irr = 8'b10000000;
    imr = 8'b00000000;
    #10;
    $display("Priority ISR: %b", highestPriority);

    // Test case 2: Priority on IR3
    irr = 8'b00001000;
    imr = 8'b00000000;
    #10;
    $display("Priority ISR: %b", highestPriority);

    // Test case 3: Priority on IR5
    irr = 8'b00100000;
    imr = 8'b11011111;
    #10;
    $display("Priority ISR: %b", highestPriority);

    // Test case 4: Priority on IR2
    irr = 8'b00000100;
    imr = 8'b00000000;
    #10;
    $display("Priority ISR: %b", highestPriority);

    // Test case 5: No priority, all interrupts masked
    irr = 8'b11001100;
    imr = 8'b11111111;
    #10;
    $display("Priority ISR: %b", highestPriority);
    
    // Test case 6: All interrupts are high
    irr = 8'b11111111;
    imr = 8'b00000000;
    #10;
    $display("Priority ISR: %b", highestPriority);

    // Test case 7: Priority on IR1
    irr = 8'b11010010;
    imr = 8'b00000000;
    #10;
    $display("Priority ISR: %b", highestPriority);

    #10;
    autoRotateMode = 1;
    irr = 8'b10000000;
    imr = 8'b00000000;
    #10;
    $display("Priority ISR: %b", highestPriority);

    // Test case 2: Priority on IR3
    irr = 8'b00001000;
    imr = 8'b00000000;
    #10;
    $display("Priority ISR: %b", highestPriority);

    // Test case 3: Priority on IR5
    irr = 8'b00100000;
    imr = 8'b11011111;
    #10;
    $display("Priority ISR: %b", highestPriority);

    // Test case 4: Priority on IR2
    irr = 8'b00000100;
    imr = 8'b00000000;
    #10;
    $display("Priority ISR: %b", highestPriority);

    // Test case 5: No priority, all interrupts masked
    irr = 8'b11001100;
    imr = 8'b11111111;
    #10;
    $display("Priority ISR: %b", highestPriority);
    
    // Test case 6: All interrupts are high
    irr = 8'b11111111;
    imr = 8'b00000000;
    #10;
    $display("Priority ISR: %b", highestPriority);

    // Test case 7: Priority on IR7
    irr = 8'b11010010;
    imr = 8'b00000000;
    #10;
    $display("Priority ISR: %b", highestPriority);

  end
endmodule

    


