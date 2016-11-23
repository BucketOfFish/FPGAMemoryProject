module AddressCounter(
    clock,
    storageReady,
    SSID,
    hitInfo,
    newAddress
    );

`include "MyParameters.vh"

input clock, storageReady;
output reg [SSIDBITS-1:0] SSID = -1;
output reg [NCOLS_HLM-1:0] hitInfo = -1;
output reg newAddress;

reg alreadyLooped = 0;

//// counts up through every SSID
//always @(posedge clock) begin
    //if (alreadyLooped) newAddress = 0;
    //if (storageReady && !alreadyLooped) begin
        //newAddress = 0; // this particular module is always sending stuff to memory, so right now this is not really necessary.
        //SSID = SSID + 1;
        //if (SSID >= NROWS_HCM-1) alreadyLooped = 1;
        //newAddress = 1;
    //end
//end

// loops through all SSIDs in array
// bugs -  HNM ignores last SSID, HCM ignores first
reg [3:0] xPos[22:0] = {0, 3, 7, 8, 8, 8, 5, 11, 11, 7, 1, 7, 5, 15, 8, 12, 4, 4, 7, 2, 1, 13, 6};
reg [3:0] yPos[22:0] = {0, 3, 12, 4, 3, 8, 8, 8, 11, 12, 12, 12, 3, 3, 1, 1, 12, 7, 7, 11, 15, 0, 4};
integer count = -1;

always @(posedge clock) begin
    if (alreadyLooped) newAddress = 0;
    if (storageReady && !alreadyLooped) begin
        newAddress = 0; // this particular module is always sending stuff to memory, so right now this is not really necessary.
        count = count+1;
        SSID = {xPos[count], yPos[count]};
        hitInfo = 0;
        hitInfo[SSIDBITS-1:0] = SSID;
        if (count >= 22) alreadyLooped = 1;
        newAddress = 1;
    end
end

endmodule
