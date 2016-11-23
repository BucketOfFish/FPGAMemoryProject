`timescale 1ns / 1ps

module Main();

`include "MyParameters.vh"

reg clock, clearMemory;
wire [SSIDBITS-1:0] SSID;
wire [NCOLS_HLM-1:0] hitInfo;
wire newAddress;
reg [31:0] randomArray;

initial begin
    clock <= 1;
    clearMemory <= 1;
end

always begin
    #1 clock = ~clock;
    if (clock) clearMemory = 0; // let clearMemory be high for one full cycle.
end

AddressCounter newCounter(
    .clock(clock),
    .SSID(SSID),
    .hitInfo(hitInfo),
    .newAddress(newAddress)
    );

BlockMemoryStorage newStorage(
    .clock(clock),
    .clearMemory(clearMemory),
    .newAddress(newAddress),
    .SSID(SSID),
    .hitInfo(hitInfo)
    );

endmodule
