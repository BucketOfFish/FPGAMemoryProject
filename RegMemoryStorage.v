// Register-based memory. Used in initial tests.

module RegMemoryStorage(
    clock,
    wordIndex,
    letterIndex,
    newAddress,
    inquiry,
    inquiryWordIndex,
    inquiryLetterIndex,
    clearStorage,
    storageReady,
    storedValue
    );

`include "MyParameters.vh"

input clock, inquiry, clearStorage, newAddress;
input [WORDINDEXBITS-1:0] wordIndex, inquiryWordIndex;
input [LETTERINDEXBITS-1:0] letterIndex, inquiryLetterIndex;
output reg storageReady, storedValue;

reg [WORDLENGTH-1:0] memory [MEMORYDEPTH-1:0];
reg [WORDLENGTH-1:0] alteredWord;
reg skipNextAddress;
integer i;

initial begin
    for (i=0; i<MEMORYDEPTH; i=i+1) memory[i] <= 0;
    storageReady = 1;
    skipNextAddress = 0;
end

always @(posedge clock) begin
    if (inquiry) begin
        storageReady = 0;
        alteredWord = memory[inquiryWordIndex];
        storedValue = alteredWord[inquiryLetterIndex];
        storageReady = 1;
    end
    if (clearStorage) begin
        for (i=0; i<MEMORYDEPTH; i=i+1) memory[i] <= 0;
    end
    // If storageReady turns off then on again, it will store the next address twice before AddressCounter can respond. This prevents that.
    if (!storageReady) skipNextAddress = 1;
    if (storageReady && newAddress) begin
        storageReady = 0;
        if (!skipNextAddress) begin
            alteredWord = memory[wordIndex];
            alteredWord[letterIndex] = 1;
            memory[wordIndex] = alteredWord;
        end
        skipNextAddress = 0;
        storageReady = 1;
    end
end

endmodule
