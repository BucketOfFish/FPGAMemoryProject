module BlockMemoryStorage(
    clock,
    clearMemory,
    readMemory,
    storageReady,
    newAddress,
    address,
    readReady,
    storedValue
    );

`include "MyParameters.vh"

input clock, clearMemory, readMemory, newAddress;
input [COLINDEXBITS+ROWINDEXBITS-1:0] address;
reg [ROWINDEXBITS-1:0] rowIndex = 0;
reg [COLINDEXBITS-1:0] colIndex = 0;
output reg storageReady, storedValue, readReady;

reg [WORDLENGTH-1:0] retrievedRow, dataInputA_HNM, dataInputB_HNM, addToRow, queueNewHitsRow1, queueNewHitsRow2;
wire [WORDLENGTH-1:0] dataOutputA_HNM, dataOutputB_HNM;
reg [ROWINDEXBITS-1:0] rowIndexA_HNM, rowIndexB_HNM, queueRowIndex1, queueRowIndex2;
reg skipNextAddress, writeEnableA_HNM, writeEnableB_HNM, itemInQueue1, itemInQueue2;
integer i, clearingIndex, readingIndex, queueNewHitsN1, queueNewHitsN2;
wire enable = 1;

initial begin
    for (i=0; i<MEMNROWS; i=i+1) collectedIndices[i] <= -1;
    storageReady = 1;
    readReady = 1;
    skipNextAddress = 0;
    clearingIndex = -1;
    readingIndex = -1;
    writeEnableA_HNM = 0;
    writeEnableB_HNM = 0;
    itemInQueue1 = 0;
    itemInQueue2 = 0;
end

always @(posedge clock) begin

    // split address
    rowIndex[ROWINDEXBITS-1:0] <= address[ROWINDEXBITS+COLINDEXBITS-1:COLINDEXBITS];
    colIndex[COLINDEXBITS-1:0] <= address[COLINDEXBITS-1:0];

    // reset everything
    writeEnableA_HNM = 0;
    writeEnableB_HNM = 0;
    storageReady = 1;
    readReady = 1;

    // clear the memory if clearMemory goes high - don't read or write during this time
    if (clearMemory || clearingIndex >= 0) begin
        storageReady = 0;
        readReady = 0;
        if (clearingIndex < 0) clearingIndex = -1;
        clearingIndex = clearingIndex + 1;
        rowIndexA_HNM = clearingIndex;
        dataInputA_HNM = 0;
        writeEnableA_HNM = 1;
        if (clearingIndex < MEMNROWS-1) begin
            clearingIndex = clearingIndex + 1;
            rowIndexB_HNM = clearingIndex;
            dataInputB_HNM = 0;
            writeEnableB_HNM = 1;
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
        rowIndexB_HNM = readingIndex;
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
            // if there's a new address, and the row of the address is already in queue
            if (newAddress && ((rowIndex == queueRowIndex1 && itemInQueue1) || (rowIndex == queueRowIndex2 && itemInQueue2))) begin
                if (rowIndex == queueRowIndex1 && itemInQueue1) begin
                    queueNewHitsRow1 = queueNewHitsRow1 | 1'b1<<colIndex;
                end
                if (rowIndex == queueRowIndex2 && itemInQueue2) begin
                    queueNewHitsRow2 = queueNewHitsRow2 | 1'b1<<colIndex;
                end
            end
            // no new address, or address is in new row
            else begin
                // write queue1 if it exists
                if (itemInQueue1) begin
                    rowIndexA_HNM = queueRowIndex1;
                    dataInputA_HNM = dataOutputB_HNM | queueNewHitsRow1;
                    writeEnableA_HNM = 1;
                    itemInQueue1 = 0;
                end
                // move queue up
                queueRowIndex1 = queueRowIndex2;
                queueNewHitsRow1 = queueNewHitsRow2;
                if (itemInQueue2) begin
                    itemInQueue1 = 1;
                    itemInQueue2 = 0;
                end
                // read new address if it exiss
                if (newAddress) begin
                    rowIndexB_HNM = rowIndex;
                    queueRowIndex2 = rowIndex;
                    queueNewHitsRow2 = 1'b1<<colIndex;
                    queueNewHitsN2 = 1;
                    itemInQueue2 = 1;
                end
            end
        end
        else skipNextAddress = 0;
        storageReady = 1;
    end
end

blk_mem_gen_0 HitsNewMemory (
    .clka(clock),
    .ena(enable),
    .wea(writeEnableA_HNM),
    .addra(rowIndexA_HNM),
    .dina(dataInputA_HNM),
    .douta(dataOutputA_HNM),
    .clkb(clock),
    .enb(enable),
    .web(writeEnableB_HNM),
    .addrb(rowIndexB_HNM),
    .dinb(dataInputB_HNM),
    .doutb(dataOutputB_HNM)
    );

blk_mem_gen_1 HitsCountMemory (
    .clka(clock),
    .ena(enable),
    .wea(writeEnableA_HCM),
    .addra(rowIndexA_HCM),
    .dina(dataInputA_HCM),
    .douta(dataOutputA_HCM),
    .clkb(clock),
    .enb(enable),
    .web(writeEnableB_HCM),
    .addrb(rowIndexB_HCM),
    .dinb(dataInputB_HCM),
    .doutb(dataOutputB_HCM)
    );

blk_mem_gen_2 HitsListMemory (
    .clka(clock),
    .ena(enable),
    .wea(writeEnableA_HLM),
    .addra(rowIndexA_HLM),
    .dina(dataInputA_HLM),
    .douta(dataOutputA_HLM),
    .clkb(clock),
    .enb(enable),
    .web(writeEnableB_HLM),
    .addrb(rowIndexB_HLM),
    .dinb(dataInputB_HLM),
    .doutb(dataOutputB_HLM)
    );

endmodule
