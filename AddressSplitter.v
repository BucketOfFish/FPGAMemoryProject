module AddressSplitter(
    clock,
    address,
    wordIndex,
    letterIndex
    );

`include "MyParameters.vh"

input clock;
input [LETTERINDEXBITS+WORDINDEXBITS-1:0] address;
output reg [WORDINDEXBITS-1:0] wordIndex=0;
output reg [LETTERINDEXBITS-1:0] letterIndex=0;

always @(posedge clock) begin
    wordIndex[WORDINDEXBITS-1:0] <= address[WORDINDEXBITS+LETTERINDEXBITS-1:LETTERINDEXBITS];
    letterIndex[LETTERINDEXBITS-1:0] <= address[LETTERINDEXBITS-1:0];
end

endmodule
