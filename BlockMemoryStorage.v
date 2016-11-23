module BlockMemoryStorage(
    clock,
    clearMemory,
    newAddress,
    storageReady,
    SSID,
    hitInfo
    );

`include "MyParameters.vh"

// inputs and outputs
input clock, clearMemory, newAddress;
output reg storageReady;
input [SSIDBITS-1:0] SSID;
input [HITINFOBITS-1:0] hitInfo;

// SSID splitting
reg [ROWINDEXBITS_HNM-1:0] rowIndex = 0;
reg [COLINDEXBITS_HNM-1:0] colIndex = 0, HCMColIndex = 0;

// block memory inputs and outputs
wire enable = 1;
reg writeEnableA_HNM, writeEnableB_HNM, writeEnableA_HCM, writeEnableB_HCM, writeEnableA_HIM, writeEnableB_HIM;
reg [ROWINDEXBITS_HNM-1:0] rowIndexA_HNM, rowIndexB_HNM;
reg [ROWINDEXBITS_HCM-1:0] rowIndexA_HCM, rowIndexB_HCM;
reg [ROWINDEXBITS_HIM-1:0] rowIndexA_HIM, rowIndexB_HIM;
reg [NCOLS_HNM-1:0] dataInputA_HNM, dataInputB_HNM;
reg [NCOLS_HCM-1:0] dataInputA_HCM, dataInputB_HCM;
reg [NCOLS_HIM-1:0] dataInputA_HIM, dataInputB_HIM;
wire [NCOLS_HNM-1:0] dataOutputA_HNM, dataOutputB_HNM;
wire [NCOLS_HCM-1:0] dataOutputA_HCM, dataOutputB_HCM;
wire [NCOLS_HIM-1:0] dataOutputA_HIM, dataOutputB_HIM;

// queues used for reading and writing
reg [ROWINDEXBITS_HNM-1:0] queueRowIndex_HNM [QUEUESIZE-1:0];
reg [NCOLS_HNM-1:0] queueNewHitsRow_HNM [QUEUESIZE-1:0];
reg [ROWINDEXBITS_HIM-1:0] queueAddress_HCM [QUEUESIZE-1:0]; // not a typo
reg [MAXHITNBITS-1:0] queueNewHitsN_HCM [QUEUESIZE-1:0];
reg [NCOLS_HIM-1:0] queueHitInfo_HCM [QUEUESIZE-1:0]; // not a typo
reg [ROWINDEXBITS_HIM-1:0] queueAddress_HIM [QUEUESIZE-1:0];
reg [MAXHITNBITS-1:0] queueNewHitsN_HIM [QUEUESIZE-1:0];
reg [NCOLS_HIM-1:0] queueHitInfo_HIM [QUEUESIZE-1:0];
reg [QUEUESIZE-1:0] queueNewSSID_HIM;
reg [QUEUESIZE-1:0] HNMInQueue, HCMInQueue, HIMInQueue;

// various tracking variables
reg SSIDAlreadyHit, loopFound;
integer clearingIndex, readingIndex, loopIndex;
reg [ROWINDEXBITS_HIM-1:0] nextAvailableHIMAddress;

initial begin
    storageReady = 1;
    clearingIndex = -1;
    readingIndex = -1;
    writeEnableA_HNM = 0;
    writeEnableB_HNM = 0;
    writeEnableA_HCM = 0;
    writeEnableB_HCM = 0;
    writeEnableA_HIM = 0;
    writeEnableB_HIM = 0;
    for (loopIndex = 0; loopIndex < QUEUESIZE; loopIndex = loopIndex +1) begin
        HNMInQueue[loopIndex] = 0;
        HCMInQueue[loopIndex] = 0;
        HIMInQueue[loopIndex] = 0;
    end
    nextAvailableHIMAddress = 0;
end

always @(posedge clock) begin

    // split SSID
    rowIndex[ROWINDEXBITS_HNM-1:0] = SSID[SSIDBITS-1:COLINDEXBITS_HNM];
    colIndex[COLINDEXBITS_HNM-1:0] = SSID[COLINDEXBITS_HNM-1:0];

    // reset everything
    writeEnableA_HNM = 0;
    writeEnableB_HNM = 0;
    writeEnableA_HCM = 0;
    writeEnableB_HCM = 0;
    writeEnableA_HIM = 0;
    writeEnableB_HIM = 0;
    storageReady = 1;

    // clear the HNM if clearMemory goes high - don't read or write during this time
    if (clearMemory || clearingIndex >= 0) begin
        storageReady = 0;
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
            nextAvailableHIMAddress = 0;
            clearingIndex = -1;
        end
    end

    // store new SSID - read from B, write from A
    // if there's a new SSID or something that still needs to be written
    if (storageReady && (newAddress || |HNMInQueue || |HCMInQueue || |HIMInQueue)) begin

        storageReady = 0;

        // if there's a new SSID, move it into the queue
        if (newAddress) begin

            /////////////////////////////////////////////
            // HNM - whether the hits at SSIDs are new //
            /////////////////////////////////////////////

            rowIndexB_HNM = rowIndex;
            queueRowIndex_HNM[QUEUESIZE-1] = rowIndex;
            loopFound = 0;
            for (loopIndex = 0; loopIndex < QUEUESIZE-1; loopIndex = loopIndex +1) begin
                // if it's in a repeat row, merge
                if (rowIndex == queueRowIndex_HNM[loopIndex] && HNMInQueue[loopIndex]) begin
                    queueNewHitsRow_HNM[loopIndex] = queueNewHitsRow_HNM[loopIndex] | 1'b1<<colIndex;
                    loopFound = 1;
                end
            end
            // if SSID is in new row, add to end of queue
            if (!loopFound) begin
                queueNewHitsRow_HNM[QUEUESIZE-1] = 1'b1<<colIndex;
                HNMInQueue[QUEUESIZE-1] = 1;
            end

            ////////////////////////////////////////////////////////////////////////////////////////
            // HCM - how many hits are at each SSID, and the HIM address where the info is stored //
            // HIM - hit info                                                                     //
            ////////////////////////////////////////////////////////////////////////////////////////

            rowIndexB_HCM = SSID;
            queueAddress_HCM[QUEUESIZE-1] = SSID;
            loopFound = 0;
            for (loopIndex = 0; loopIndex < QUEUESIZE-1; loopIndex = loopIndex +1) begin
                // if it's a repeat SSID, merge
                if (SSID == queueAddress_HCM[loopIndex] && HCMInQueue[loopIndex]) begin
                    queueHitInfo_HCM[loopIndex] = queueHitInfo_HCM[loopIndex]<<HITINFOBITS | hitInfo;
                    queueNewHitsN_HCM[loopIndex] = queueNewHitsN_HCM[loopIndex] + 1;
                    loopFound = 1;
                end
            end
            // if SSID is new, add to end of queue
            if (!loopFound) begin
                queueNewHitsN_HCM[QUEUESIZE-1] = 1;
                HCMInQueue[QUEUESIZE-1] = 1;
                queueHitInfo_HCM[QUEUESIZE-1] = hitInfo;
            end
        end

        /////////////////////////////////////////////
        // HNM - whether the hits at SSIDs are new //
        /////////////////////////////////////////////

        // write queue1 if it exists
        if (HNMInQueue[0]) begin
            rowIndexA_HNM = queueRowIndex_HNM[0];
            dataInputA_HNM = dataOutputB_HNM | queueNewHitsRow_HNM[0];
            writeEnableA_HNM = 1;
            HNMInQueue[0] = 0;
        end
        // move queue up
        for (loopIndex = 1; loopIndex < QUEUESIZE; loopIndex = loopIndex +1) begin
            if (HNMInQueue[loopIndex]) begin
                queueRowIndex_HNM[loopIndex-1] = queueRowIndex_HNM[loopIndex];
                queueNewHitsRow_HNM[loopIndex-1] = queueNewHitsRow_HNM[loopIndex];
                HNMInQueue[loopIndex-1] = 1;
                HNMInQueue[loopIndex] = 0;
            end
        end

        ////////////////////////////////////////////////////////////////////////////////////////
        // HCM - how many hits are at each SSID, and the HIM address where the info is stored //
        ////////////////////////////////////////////////////////////////////////////////////////

        // if SSID hasn't been hit, use nextAvailableHIMAddress - else use existing address
        HCMColIndex[COLINDEXBITS_HNM-1:0] = queueAddress_HCM[0][COLINDEXBITS_HNM-1:0];
        SSIDAlreadyHit = dataOutputB_HNM[HCMColIndex];

        // write queue1 if it exists
        if (HCMInQueue[0]) begin
            rowIndexA_HCM = queueAddress_HCM[0];
            if (!SSIDAlreadyHit) begin
                dataInputA_HCM = queueNewHitsN_HCM[0];
                dataInputA_HCM[NCOLS_HCM-1:NCOLS_HCM-ROWINDEXBITS_HIM] = nextAvailableHIMAddress[ROWINDEXBITS_HIM-1:0];
                queueAddress_HIM[QUEUESIZE-1] = nextAvailableHIMAddress;
                nextAvailableHIMAddress = nextAvailableHIMAddress + 1;
                queueNewSSID_HIM[QUEUESIZE-1] = 1;
            end
            else begin
                dataInputA_HCM = dataOutputB_HCM + queueNewHitsN_HCM[0]; // assuming no overflow in number of hits
                queueAddress_HIM[QUEUESIZE-1] = dataOutputB_HCM[NCOLS_HCM-1:NCOLS_HCM-ROWINDEXBITS_HIM];
                queueNewSSID_HIM[QUEUESIZE-1] = 0;
            end
            writeEnableA_HCM = 1;
            rowIndexB_HIM = queueAddress_HIM[QUEUESIZE-1];
            queueNewHitsN_HIM[QUEUESIZE-1] = queueNewHitsN_HCM[0];
            queueHitInfo_HIM[QUEUESIZE-1] = queueHitInfo_HCM[0];
            HIMInQueue[QUEUESIZE-1] = 1;
            HCMInQueue[0] = 0;
        end
        // move queue up
        for (loopIndex = 1; loopIndex < QUEUESIZE; loopIndex = loopIndex +1) begin
            if (HCMInQueue[loopIndex]) begin
                queueAddress_HCM[loopIndex-1] = queueAddress_HCM[loopIndex];
                queueNewHitsN_HCM[loopIndex-1] = queueNewHitsN_HCM[loopIndex];
                queueHitInfo_HCM[loopIndex-1] = queueHitInfo_HCM[loopIndex];
                HCMInQueue[loopIndex-1] = 1;
                HCMInQueue[loopIndex] = 0;
            end
        end

        ////////////////////
        // HIM - hit info //
        ////////////////////

        // write queue1 if it exists
        if (HIMInQueue[0]) begin
            rowIndexA_HIM = queueAddress_HIM[0];
            if (queueNewSSID_HIM[0]) begin
                dataInputA_HIM = queueHitInfo_HIM[0];
            end
            else begin
                dataInputA_HIM = dataOutputB_HIM<<(HITINFOBITS * queueNewHitsN_HIM[0]) | queueHitInfo_HIM[0];
            end
            writeEnableA_HIM = 1;
            HIMInQueue[0] = 0;
        end
        // move queue up
        for (loopIndex = 1; loopIndex < QUEUESIZE; loopIndex = loopIndex +1) begin
            if (HIMInQueue[loopIndex]) begin
                queueAddress_HIM[loopIndex-1] = queueAddress_HIM[loopIndex];
                queueNewHitsN_HIM[loopIndex-1] = queueNewHitsN_HIM[loopIndex];
                queueHitInfo_HIM[loopIndex-1] = queueHitInfo_HIM[loopIndex];
                queueNewSSID_HIM[loopIndex-1] = queueNewSSID_HIM[loopIndex];
                HIMInQueue[loopIndex-1] = 1;
                HIMInQueue[loopIndex] = 0;
            end
        end

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
    .wea(writeEnableA_HIM),
    .addra(rowIndexA_HIM),
    .dina(dataInputA_HIM),
    .douta(dataOutputA_HIM),
    .clkb(clock),
    .enb(enable),
    .web(writeEnableB_HIM),
    .addrb(rowIndexB_HIM),
    .dinb(dataInputB_HIM),
    .doutb(dataOutputB_HIM)
    );

endmodule
