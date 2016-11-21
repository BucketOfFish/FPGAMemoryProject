module BlockMemoryStorage(
    clock,
    clearMemory,
    readMemory,
    newAddress,
    storageReady,
    address,
    readReady
    );

`include "MyParameters.vh"

// inputs and outputs
input clock, clearMemory, readMemory, newAddress;
output reg storageReady, readReady;
input [ADDRESSBITS-1:0] address;

// address splitting
reg [ROWINDEXBITS_HNM-1:0] rowIndex = 0;
reg [COLINDEXBITS_HNM-1:0] colIndex = 0;

// block memory inputs and outputs
wire enable = 1;
reg writeEnableA_HNM, writeEnableB_HNM, writeEnableA_HCM, writeEnableB_HCM, writeEnableA_HLM, writeEnableB_HLM;
reg [ROWINDEXBITS_HNM-1:0] rowIndexA_HNM, rowIndexB_HNM;
reg [ROWINDEXBITS_HCM-1:0] rowIndexA_HCM, rowIndexB_HCM;
reg [ROWINDEXBITS_HLM-1:0] rowIndexA_HLM, rowIndexB_HLM;
reg [NCOLS_HNM-1:0] dataInputA_HNM, dataInputB_HNM;
reg [NCOLS_HCM-1:0] dataInputA_HCM, dataInputB_HCM;
reg [NCOLS_HLM-1:0] dataInputA_HLM, dataInputB_HLM;
wire [NCOLS_HNM-1:0] dataOutputA_HNM, dataOutputB_HNM;
wire [NCOLS_HCM-1:0] dataOutputA_HCM, dataOutputB_HCM;
wire [NCOLS_HLM-1:0] dataOutputA_HLM, dataOutputB_HLM;

// queues used for reading and writing
reg [NCOLS_HNM-1:0] queueNewHitsRow1_HNM, queueNewHitsRow2_HNM, queueNewHitsRow3_HNM;
reg [ROWINDEXBITS_HNM-1:0] queueRowIndex1_HNM, queueRowIndex2_HNM, queueRowIndex3_HNM;
reg [ROWINDEXBITS_HLM-1:0] queueAddress1_HCM, queueAddress2_HCM;
reg [MAXHITNBITS-1:0] queueNewHitsN1_HCM, queueNewHitsN2_HCM;
reg [NCOLS_HCM-1:0] queueWriteInfo1_HCM, queueWriteInfo2_HCM;
reg HNMInQueue1, HNMInQueue2, HNMInQueue3, HCMInQueue1, HCMInQueue2;

// variables for tracking reading, writing, and clearing memory
reg skipNextAddress;
integer clearingIndex, readingIndex;
reg [ROWINDEXBITS_HLM-1:0] nextAvailableHLM;

initial begin
    storageReady = 1;
    readReady = 1;
    skipNextAddress = 0;
    clearingIndex = -1;
    readingIndex = -1;
    writeEnableA_HNM = 0;
    writeEnableB_HNM = 0;
    writeEnableA_HCM = 0;
    writeEnableB_HCM = 0;
    writeEnableA_HLM = 0;
    writeEnableB_HLM = 0;
    HNMInQueue1 = 0;
    HNMInQueue2 = 0;
    HNMInQueue3 = 0;
    HCMInQueue1 = 0;
    HCMInQueue2 = 0;
    nextAvailableHLM = 0;
end

always @(posedge clock) begin

    // split address
    rowIndex[ROWINDEXBITS_HNM-1:0] <= address[ADDRESSBITS-1:COLINDEXBITS_HNM];
    colIndex[COLINDEXBITS_HNM-1:0] <= address[COLINDEXBITS_HNM-1:0];

    // reset everything
    writeEnableA_HNM = 0;
    writeEnableB_HNM = 0;
    writeEnableA_HCM = 0;
    writeEnableB_HCM = 0;
    writeEnableA_HLM = 0;
    writeEnableB_HLM = 0;
    storageReady = 1;
    readReady = 1;

    // clear the HNM if clearMemory goes high - don't read or write during this time
    if (clearMemory || clearingIndex >= 0) begin
        storageReady = 0;
        readReady = 0;
        if (clearingIndex < 0) clearingIndex = -1;
        clearingIndex = clearingIndex + 1;
        rowIndexA_HNM = clearingIndex;
        dataInputA_HNM = 0;
        writeEnableA_HNM = 1;
        if (clearingIndex < NROWS_HNM-1) begin
            clearingIndex = clearingIndex + 1;
            rowIndexB_HNM = clearingIndex;
            dataInputB_HNM = 0;
            writeEnableB_HNM = 1;
        end
        if (clearingIndex >= NROWS_HNM-1) begin
            nextAvailableHLM = 0;
            clearingIndex = -1;
        end
    end

    // if storageReady turns off then on again, it will store the next address twice before AddressCounter can respond. This prevents that.
    if (!storageReady) skipNextAddress = 1;

    // store new address - read from B, write from A
    // if there's a new address or something that still needs to be written
    if (storageReady && (newAddress || HNMInQueue1 || HNMInQueue2 || HNMInQueue3 || HCMInQueue1 || HCMInQueue2)) begin // || HLMInQueue1 || HLMInQueue2)) begin
        storageReady = 0;
        if (!skipNextAddress) begin

            /////////////////////////////////////////////
            // HNM - whether the hits at SSIDs are new //
            /////////////////////////////////////////////

            // if there's a new address...
            if (newAddress) begin
                rowIndexB_HNM = rowIndex;
                queueRowIndex3_HNM = rowIndex;
                // if it's in a repeat row
                if (rowIndex == queueRowIndex1_HNM && HNMInQueue1) begin
                    queueNewHitsRow1_HNM = queueNewHitsRow1_HNM | 1'b1<<colIndex;
                end
                else if (rowIndex == queueRowIndex2_HNM && HNMInQueue2) begin
                    queueNewHitsRow2_HNM = queueNewHitsRow2_HNM | 1'b1<<colIndex;
                end
                // if address is in new row
                else begin
                    queueNewHitsRow3_HNM = 1'b1<<colIndex;
                    HNMInQueue3 = 1;
                end
            end
            // write queue1 if it exists
            if (HNMInQueue1) begin
                rowIndexA_HNM = queueRowIndex1_HNM;
                dataInputA_HNM = dataOutputB_HNM | queueNewHitsRow1_HNM;
                writeEnableA_HNM = 1;
                HNMInQueue1 = 0;
            end
            // move queue up
            if (HNMInQueue2) begin
                queueRowIndex1_HNM = queueRowIndex2_HNM;
                queueNewHitsRow1_HNM = queueNewHitsRow2_HNM;
                HNMInQueue1 = 1;
                HNMInQueue2 = 0;
            end
            if (HNMInQueue3) begin
                queueRowIndex2_HNM = queueRowIndex3_HNM;
                queueNewHitsRow2_HNM = queueNewHitsRow3_HNM;
                HNMInQueue2 = 1;
                HNMInQueue3 = 0;
            end

            ////////////////////////////////////////////////////////////////////////////////////////
            //// HCM - how many hits are at each SSID, and the addresses where the info is stored //
            ////////////////////////////////////////////////////////////////////////////////////////

            //// write queue1 if it exists
            //if (HCMInQueue1) begin
                //rowIndexA_HCM = queueAddress1_HCM;
                //if (newSSID) begin
                    //dataInputA_HCM = nextAvailableHLM<<MAXHITNBITS;
                    //dataInputA_HCM[MAXHITNBITS-1:0] = queueNewHitsN1_HCM;
                //end
                //else begin
                    //dataInputA_HCM = dataOutputB_HCM;
                    //dataInputA_HCM[MAXHITNBITS-1:0] = queueNewHitsN1_HCM;
                //end
                //writeEnableA_HCM = 1;
                //HCMInQueue1 = 0;
            //end
            //// move queue up
            //if (HCMInQueue2) begin
                //queueRowIndex1 = queueRowIndex2;
                //queueAddress1_HCM = queueAddress2_HCM;
                //HCMInQueue1 = 1;
                //HCMInQueue2 = 0;
            //end
            //// if there's a new address...
            //if (newAddress) begin
                //rowIndexB_HCM = rowIndex;
                //queueRowIndex2 = rowIndex;
                //// if it's in a repeat row
                //if (rowIndex == queueRowIndex1 && HCMInQueue1) begin
                    //queueNewHitsN1_HCM = queueNewHitsN1_HCM + 1;
                //end
                //// if address is in new row
                //else begin
                    //queueNewHitsN2 = 1;
                    //HCMInQueue2 = 1;
                //end
            //end

            //////////////////////
            //// HLM - hit info //
            //////////////////////

            //// if there's a new address, and the row of the address is already in queue
            //if (newAddress && ((rowIndex == queueRowIndex1 && HNMInQueue1) || (rowIndex == queueRowIndex2 && HNMInQueue2))) begin
                //if (rowIndex == queueRowIndex1 && HNMInQueue1) begin
                    //queueNewHitsRow1_HNM = queueNewHitsRow1_HNM | 1'b1<<colIndex;
                //end
                //if (rowIndex == queueRowIndex2 && HNMInQueue2) begin
                    //queueNewHitsRow2_HNM = queueNewHitsRow2_HNM | 1'b1<<colIndex;
                //end
            //end
            //// no new address, or address is in new row
            //else begin
                //// write queue1 if it exists
                //if (HNMInQueue1) begin
                    //rowIndexA_HNM = queueRowIndex1;
                    //dataInputA_HNM = dataOutputB_HNM | queueNewHitsRow1_HNM;
                    //writeEnableA_HNM = 1;
                    //HNMInQueue1 = 0;
                //end
                //// move queue up
                //if (HNMInQueue2) begin
                    //queueRowIndex1 = queueRowIndex2;
                    //queueNewHitsRow1_HNM = queueNewHitsRow2_HNM;
                    //HNMInQueue1 = 1;
                    //HNMInQueue2 = 0;
                //end
                //// read new address if it exists
                //if (newAddress) begin
                    //rowIndexB_HNM = rowIndex;
                    //queueRowIndex2 = rowIndex;
                    //queueNewHitsRow2_HNM = 1'b1<<colIndex;
                    //queueNewHitsN2 = 1;
                    //HNMInQueue2 = 1;
                //end
            //end
        end
        else skipNextAddress = 0;
        storageReady = 1;
    end

    // read out the HNM if readMemory goes high - don't read or write during this time
    // if (readMemory || readingIndex >= 0) begin
    if (!newAddress && (readReady || readingIndex>=0)) begin
        storageReady = 0;
        readReady = 0;
        if (readingIndex < 0) readingIndex = -1;
        readingIndex = readingIndex + 1;
        rowIndexB_HNM = readingIndex;
        if (readingIndex >= NROWS_HNM-1) begin
            readingIndex = -1;
            storageReady = 1;
            readReady = 1;
        end
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

//blk_mem_gen_1 HitsCountMemory (
    //.clka(clock),
    //.ena(enable),
    //.wea(writeEnableA_HCM),
    //.addra(rowIndexA_HCM),
    //.dina(dataInputA_HCM),
    //.douta(dataOutputA_HCM),
    //.clkb(clock),
    //.enb(enable),
    //.web(writeEnableB_HCM),
    //.addrb(rowIndexB_HCM),
    //.dinb(dataInputB_HCM),
    //.doutb(dataOutputB_HCM)
    //);

//blk_mem_gen_2 HitsListMemory (
    //.clka(clock),
    //.ena(enable),
    //.wea(writeEnableA_HLM),
    //.addra(rowIndexA_HLM),
    //.dina(dataInputA_HLM),
    //.douta(dataOutputA_HLM),
    //.clkb(clock),
    //.enb(enable),
    //.web(writeEnableB_HLM),
    //.addrb(rowIndexB_HLM),
    //.dinb(dataInputB_HLM),
    //.doutb(dataOutputB_HLM)
    //);

endmodule
