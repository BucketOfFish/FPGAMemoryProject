module AddressCounter(
    clock,
    storageReady,
    address,
    newAddress
    );

`include "MyParameters.vh"

input clock, storageReady;
output reg [ADDRESSBITS-1:0] address = -1;
output reg newAddress;

reg alreadyLooped = 0;

//// counts up through every address
//always @(posedge clock) begin
    //if (alreadyLooped) newAddress = 0;
    //if (storageReady && !alreadyLooped) begin
        //newAddress = 0; // this particular module is always sending stuff to memory, so right now this is not really necessary.
        //address = address + 1;
        //if (address == NROWS_HCM-1) alreadyLooped = 1;
        //newAddress = 1;
    //end
//end

// loops through all addresses in array
// bug where last two addresses are ignored - sending two sets of (0,0) to fix for now
reg [3:0] xPos[22:0] = {0, 0, 5, 8, 8, 8, 5, 11, 14, 11, 1, 7, 5, 15, 8, 12, 4, 4, 7, 2, 1, 13, 0};
reg [3:0] yPos[22:0] = {0, 0, 5, 4, 3, 8, 8, 8,  0, 11, 12, 12, 3, 3, 1, 1, 12, 7, 7, 11, 15, 0, 4};
integer count = 0;

always @(posedge clock) begin
    if (alreadyLooped) newAddress = 0;
    if (storageReady && !alreadyLooped) begin
        newAddress = 0; // this particular module is always sending stuff to memory, so right now this is not really necessary.
        address = {xPos[count], yPos[count]};
        count = count+1;
        if (count >= 22) begin
            alreadyLooped = 1;
        end
        newAddress = 1;
    end
end

endmodule
