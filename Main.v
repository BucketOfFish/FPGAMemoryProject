`timescale 1ns / 1ps

module Main();

`include "MyParameters.vh"

reg clock, clearMemory, readMemory;
wire [SSIDBITS-1:0] SSID;
wire [NCOLS_HLM-1:0] hitInfo;
wire storageReady, newAddress, readReady;
reg [31:0] randomArray;

initial begin
    clock <= 1;
    clearMemory <= 1;
    readMemory <= 0;
end

always begin
    #1 clock = ~clock;
    if (clock) clearMemory = 0; // let clearMemory be high for one full cycle.
end

AddressCounter newCounter(
    .clock(clock),
    .storageReady(storageReady),
    .SSID(SSID),
    .hitInfo(hitInfo),
    .newAddress(newAddress)
    );

BlockMemoryStorage newStorage(
    .clock(clock),
    .clearMemory(clearMemory),
    .readMemory(readMemory),
    .newAddress(newAddress),
    .storageReady(storageReady),
    .SSID(SSID),
    .hitInfo(hitInfo),
    .readReady(readReady)
    );

endmodule
