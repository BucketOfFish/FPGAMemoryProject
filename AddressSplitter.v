module AddressSplitter(
    clock,
    address,
    wordIndex,
    letterIndex
    );

`include "MyParameters.vh"

input clock;
input [COLINDEXBITS+ROWINDEXBITS-1:0] address;
output reg [ROWINDEXBITS-1:0] wordIndex=0;
output reg [COLINDEXBITS-1:0] letterIndex=0;

always @(posedge clock) begin
    wordIndex[ROWINDEXBITS-1:0] <= address[ROWINDEXBITS+COLINDEXBITS-1:COLINDEXBITS];
    letterIndex[COLINDEXBITS-1:0] <= address[COLINDEXBITS-1:0];
end

endmodule
