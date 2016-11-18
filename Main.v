`timescale 1ns / 1ps

module Main();

`include "MyParameters.vh"

reg clock, clearMemory, readMemory;
wire [COLINDEXBITS+ROWINDEXBITS-1:0] address;
wire storageReady, storedValue, newAddress, readReady;
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
    .address(address),
    .newAddress(newAddress)
    );

BlockMemoryStorage newStorage(
    .clock(clock),
    .address(address),
    .newAddress(newAddress),
    .clearMemory(clearMemory),
    .readMemory(readMemory),
    .storageReady(storageReady),
    .readReady(readReady),
    .storedValue(storedValue)
    );

endmodule
