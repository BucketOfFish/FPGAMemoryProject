`timescale 1ns / 1ps

module Main();

`include "MyParameters.vh"

reg clock, clearStorage;
wire [LETTERINDEXBITS+WORDINDEXBITS-1:0] address;
wire [WORDINDEXBITS-1:0] wordIndex;
wire [LETTERINDEXBITS-1:0] letterIndex;
wire storageReady, storedValue, newAddress, readReady;
reg inquiry;
integer inquiryCount;
reg [WORDINDEXBITS-1:0] inquiryWordIndex;
reg [LETTERINDEXBITS-1:0] inquiryLetterIndex;
reg [31:0] randomArray;

initial begin
    clock <= 1;
    clearStorage <= 1;
    inquiry <= 0;
    inquiryCount <= 0;
end

always begin
    #1 clock = ~clock;
    //#1; // it's necessary to put this stuff in the middle of a clock cycle to prevent race conditions.
    if (clock) clearStorage = 0; // let clearStorage be high for one full cycle.
    //inquiryCount = inquiryCount+1;
    //if (inquiryCount == 2) begin
        //inquiryCount = 0;
        //inquiry = ~inquiry;
        //randomArray = $random;
        //inquiryWordIndex[WORDINDEXBITS-1:0] = randomArray[WORDINDEXBITS-1:0];
        //inquiryLetterIndex[LETTERINDEXBITS-1:0] = randomArray[LETTERINDEXBITS+WORDINDEXBITS-1:WORDINDEXBITS];
    //end
end

AddressCounter newCounter(
    .clock(clock),
    .storageReady(storageReady),
    .address(address),
    .newAddress(newAddress)
    );

AddressSplitter newSplitter(
    .clock(clock),
    .address(address),
    .wordIndex(wordIndex),
    .letterIndex(letterIndex)
    );

BlockMemoryStorage newStorage(
    .clock(clock),
    .wordIndex(wordIndex),
    .letterIndex(letterIndex),
    //.wordIndex(letterIndex),
    //.letterIndex(wordIndex),
    .newAddress(newAddress),
    .inquiry(inquiry),
    .inquiryWordIndex(inquiryWordIndex),
    .inquiryLetterIndex(inquiryLetterIndex),
    .clearStorage(clearStorage),
    .storageReady(storageReady),
    .readReady(readReady),
    .storedValue(storedValue)
    );

endmodule
