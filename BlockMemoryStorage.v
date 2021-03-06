module BlockMemoryStorage(
    clock,
    clearMemory,
    newAddress,
    SSID,
    hitInfo
    );

`include "MyParameters.vh"

// inputs and outputs
input clock, clearMemory, newAddress;
input [SSIDBITS-1:0] SSID;
input [HITINFOBITS-1:0] hitInfo;

// SSID splitting
reg [ROWINDEXBITS_HNM-1:0] rowIndex = 0;
reg [COLINDEXBITS_HNM-1:0] colIndex = 0, HCMColIndex = 0;

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
reg [ROWINDEXBITS_HNM-1:0] queueRowIndex_HNM [QUEUESIZE-1:0];
reg [NCOLS_HNM-1:0] queueNewHitsRow_HNM [QUEUESIZE-1:0];
reg [ROWINDEXBITS_HCM-1:0] queueAddress_HCM [QUEUESIZE-1:0];
reg [MAXHITNBITS-1:0] queueNewHitsN_HCM [QUEUESIZE-1:0];
reg [NCOLS_HLM-1:0] queueHitInfo_HCM [QUEUESIZE-1:0]; // not a typo
reg [ROWINDEXBITS_HLM-1:0] queueAddress_HLM [QUEUESIZE-1:0];
reg [MAXHITNBITS-1:0] queueNewHitsN_HLM [QUEUESIZE-1:0];
reg [NCOLS_HLM-1:0] queueHitInfo_HLM [QUEUESIZE-1:0];
reg [QUEUESIZE-1:0] queueNewSSID_HLM;
reg [QUEUESIZE-1:0] HNMInQueue, HCMInQueue, HLMInQueue;

// various tracking variables
reg SSIDAlreadyHit, loopFound;
integer clearingIndex, loopIndex;
reg [ROWINDEXBITS_HLM-1:0] nextAvailableHLMAddress;

initial begin
    clearingIndex = -1;
    for (loopIndex = 0; loopIndex < QUEUESIZE; loopIndex = loopIndex +1) begin
        HNMInQueue[loopIndex] = 0;
        HCMInQueue[loopIndex] = 0;
        HLMInQueue[loopIndex] = 0;
    end
    nextAvailableHLMAddress = 0;
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
    writeEnableA_HLM = 0;
    writeEnableB_HLM = 0;

    // clear the HNM and reset queue if clearMemory goes high
    if (clearMemory || clearingIndex >= 0) begin
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
            for (loopIndex = 0; loopIndex < QUEUESIZE; loopIndex = loopIndex +1) begin
                HNMInQueue[loopIndex] = 0;
                HCMInQueue[loopIndex] = 0;
                HLMInQueue[loopIndex] = 0;
            end
            nextAvailableHLMAddress = 0;
            clearingIndex = -1;
        end
    end

    // store new SSID - read from B, write from A
    // if there's a new SSID or something that still needs to be written
    if (newAddress || |HNMInQueue || |HCMInQueue || |HLMInQueue) begin

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
            // HCM - how many hits are at each SSID, and the HLM address where the info is stored //
            // HLM - hit info                                                                     //
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
        // HCM - how many hits are at each SSID, and the HLM address where the info is stored //
        ////////////////////////////////////////////////////////////////////////////////////////

        // if SSID hasn't been hit, use nextAvailableHLMAddress - else use existing address
        HCMColIndex[COLINDEXBITS_HNM-1:0] = queueAddress_HCM[0][COLINDEXBITS_HNM-1:0];
        SSIDAlreadyHit = dataOutputB_HNM[HCMColIndex];

        // write queue1 if it exists
        if (HCMInQueue[0]) begin
            rowIndexA_HCM = queueAddress_HCM[0];
            if (!SSIDAlreadyHit) begin
                dataInputA_HCM = queueNewHitsN_HCM[0];
                dataInputA_HCM[NCOLS_HCM-1:NCOLS_HCM-ROWINDEXBITS_HLM] = nextAvailableHLMAddress[ROWINDEXBITS_HLM-1:0];
                queueAddress_HLM[QUEUESIZE-1] = nextAvailableHLMAddress;
                nextAvailableHLMAddress = nextAvailableHLMAddress + 1;
                queueNewSSID_HLM[QUEUESIZE-1] = 1;
            end
            else begin
                dataInputA_HCM = dataOutputB_HCM + queueNewHitsN_HCM[0]; // assuming no overflow in number of hits
                queueAddress_HLM[QUEUESIZE-1] = dataOutputB_HCM[NCOLS_HCM-1:NCOLS_HCM-ROWINDEXBITS_HLM];
                queueNewSSID_HLM[QUEUESIZE-1] = 0;
            end
            writeEnableA_HCM = 1;
            rowIndexB_HLM = queueAddress_HLM[QUEUESIZE-1];
            queueNewHitsN_HLM[QUEUESIZE-1] = queueNewHitsN_HCM[0];
            queueHitInfo_HLM[QUEUESIZE-1] = queueHitInfo_HCM[0];
            HLMInQueue[QUEUESIZE-1] = 1;
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
        // HLM - hit info //
        ////////////////////

        // write queue1 if it exists
        if (HLMInQueue[0]) begin
            rowIndexA_HLM = queueAddress_HLM[0];
            if (queueNewSSID_HLM[0]) begin
                dataInputA_HLM = queueHitInfo_HLM[0];
            end
            else begin
                dataInputA_HLM = dataOutputB_HLM<<(HITINFOBITS * queueNewHitsN_HLM[0]) | queueHitInfo_HLM[0];
            end
            writeEnableA_HLM = 1;
            HLMInQueue[0] = 0;
        end
        // move queue up
        for (loopIndex = 1; loopIndex < QUEUESIZE; loopIndex = loopIndex +1) begin
            if (HLMInQueue[loopIndex]) begin
                queueAddress_HLM[loopIndex-1] = queueAddress_HLM[loopIndex];
                queueNewHitsN_HLM[loopIndex-1] = queueNewHitsN_HLM[loopIndex];
                queueHitInfo_HLM[loopIndex-1] = queueHitInfo_HLM[loopIndex];
                queueNewSSID_HLM[loopIndex-1] = queueNewSSID_HLM[loopIndex];
                HLMInQueue[loopIndex-1] = 1;
                HLMInQueue[loopIndex] = 0;
            end
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

blk_mem_gen_2 HitsInfoMemory (
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
