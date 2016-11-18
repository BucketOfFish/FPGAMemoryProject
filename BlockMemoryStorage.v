module BlockMemoryStorage(
    clock,
    clearMemory,
    readMemory,
    storageReady,
    newAddress,
    address,
    readReady,
    //inquiry,
    //inquiryWordIndex,
    //inquiryLetterIndex,
    storedValue
    );

`include "MyParameters.vh"

input clock, clearMemory, readMemory, newAddress;
input [COLINDEXBITS+ROWINDEXBITS-1:0] address;
reg [ROWINDEXBITS-1:0] wordIndex = 0;
reg [COLINDEXBITS-1:0] letterIndex = 0;
output reg storageReady, storedValue, readReady;

reg [WORDLENGTH-1:0] retrievedWord, dataInputA, dataInputB, addToWord, queueNewHits1, queueNewHits2;
wire [WORDLENGTH-1:0] dataOutputA, dataOutputB;
reg [ROWINDEXBITS-1:0] wordIndexA, wordIndexB, queueWordIndex1, queueWordIndex2;
reg skipNextAddress, writeEnableA, writeEnableB, itemInQueue1, itemInQueue2;
integer i, clearingIndex, readingIndex;
wire enable = 1;

initial begin
    for (i=0; i<MEMNROWS; i=i+1) collectedIndices[i] <= -1;
    storageReady = 1;
    readReady = 1;
    skipNextAddress = 0;
    clearingIndex = -1;
    readingIndex = -1;
    writeEnableA = 0;
    writeEnableB = 0;
    itemInQueue1 = 0;
    itemInQueue2 = 0;
end

always @(posedge clock) begin

    // split address
    wordIndex[ROWINDEXBITS-1:0] <= address[ROWINDEXBITS+COLINDEXBITS-1:COLINDEXBITS];
    letterIndex[COLINDEXBITS-1:0] <= address[COLINDEXBITS-1:0];

    // reset everything
    writeEnableA = 0;
    writeEnableB = 0;
    storageReady = 1;
    readReady = 1;

    // clear the memory if clearMemory goes high - don't read or write during this time
    if (clearMemory || clearingIndex >= 0) begin
        storageReady = 0;
        readReady = 0;
        if (clearingIndex < 0) clearingIndex = -1;
        clearingIndex = clearingIndex + 1;
        wordIndexA = clearingIndex;
        dataInputA = 0;
        writeEnableA = 1;
        if (clearingIndex < MEMNROWS-1) begin
            clearingIndex = clearingIndex + 1;
            wordIndexB = clearingIndex;
            dataInputB = 0;
            writeEnableB = 1;
        end
        if (clearingIndex >= MEMNROWS-1) begin
            clearingIndex = -1;
        end
    end

    // read out the memory if readMemory goes high - don't read or write during this time
    // if (readMemory || readingIndex >= 0) begin
    if (!newAddress && (readReady || readingIndex>=0)) begin
        storageReady = 0;
        readReady = 0;
        if (readingIndex < 0) readingIndex = -1;
        indexB = readingIndex + 1;
        readingIndex = indexB;
        wordIndexB = readingIndex;
        if (readingIndex >= MEMNROWS-1) begin
            readingIndex = -1;
            storageReady = 1;
            readReady = 1;
        end
    end

    // if storageReady turns off then on again, it will store the next address twice before AddressCounter can respond. This prevents that.
    if (!storageReady) skipNextAddress = 1;

    // store new address - read from B, write from A
    // if there's a new address or something that still needs to be written
    if (storageReady && (newAddress || itemInQueue1 || itemInQueue2)) begin
        storageReady = 0;
        if (!skipNextAddress) begin
            // if there's a row to be written to, and the current address is not in that row
            if ((wordIndex != queueWordIndex1) || !itemInQueue1) begin
                if (itemInQueue1) begin
                    // take what's currently in the read output and add in what's in the queue
                    wordIndexA = queueWordIndex1;
                    dataInputA = dataOutputB | queueNewHits1;
                    writeEnableA = 1;
                    itemInQueue1 = 0;
                end
                // move queue up
                queueWordIndex1 = queueWordIndex2;
                queueNewHits1 = queueNewHits2;
                if (itemInQueue2) begin
                    itemInQueue1 = 1;
                    itemInQueue2 = 0;
                end
                if (newAddress) begin
                    // next item
                    if ((wordIndex != queueWordIndex1) || !itemInQueue1) begin
                        wordIndexB = wordIndex;
                        queueWordIndex2 = wordIndex;
                        queueNewHits2 = 1'b1<<letterIndex;
                        itemInQueue2 = 1;
                    end
                    else begin
                        queueNewHits1 = queueNewHits1 | 1'b1<<letterIndex;
                    end
                end
            end
            else begin // if the new address is in the row that's currently about to be written
                queueNewHits1 = queueNewHits1 | 1'b1<<letterIndex;
            end
        end
        else skipNextAddress = 0;
        storageReady = 1;
    end
end

blk_mem_gen_0 BlockMemAlpha (
    .clka(clock),    // input wire clka
    .ena(enable),      // input wire ena
    .wea(writeEnableA),      // input wire [0 : 0] wea
    .addra(wordIndexA),  // input wire [3 : 0] addra
    .dina(dataInputA),    // input wire [15 : 0] dina
    .douta(dataOutputA),  // output wire [15 : 0] douta
    .clkb(clock),    // input wire clkb
    .enb(enable),      // input wire enb
    .web(writeEnableB),      // input wire [0 : 0] web
    .addrb(wordIndexB),  // input wire [3 : 0] addrb
    .dinb(dataInputB),    // input wire [15 : 0] dinb
    .doutb(dataOutputB)  // output wire [15 : 0] doutb
    );

endmodule
