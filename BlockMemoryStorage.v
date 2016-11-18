module BlockMemoryStorage(
    clock,
    clearStorage,
    storageReady,
    newAddress,
    wordIndex,
    letterIndex,
    readReady,
    inquiry,
    inquiryWordIndex,
    inquiryLetterIndex,
    storedValue
    );

`include "MyParameters.vh"

input clock, inquiry, clearStorage, newAddress;
input [WORDINDEXBITS-1:0] wordIndex, inquiryWordIndex;
input [LETTERINDEXBITS-1:0] letterIndex, inquiryLetterIndex;
output reg storageReady, storedValue, readReady;

reg [WORDLENGTH-1:0] retrievedWord, dataInputA, dataInputB, addToWord;
reg [WORDINDEXBITS-1:0] wordIndexA, wordIndexB;
//reg [LETTERINDEXBITS-1:0] queueA1, queueA2, queueB1, queueB2;
reg [WORDINDEXBITS-1:0] queueWordIndex1, queueWordIndex2;
//reg [LETTERINDEXBITS-1:0] queueLetterIndex1, queueLetterIndex2;
reg [WORDLENGTH-1:0] queueNewHits1, queueNewHits2;
reg skipNextAddress, writeEnableA, writeEnableB, itemInQueue1, itemInQueue2;
integer i, clearingIndex, readingIndex;
reg [2:0] stateA, stateB;
reg [MAXBACKLOG-1:0] collectedIndices [MEMORYDEPTH-1:0];
wire enable = 1;
wire [WORDLENGTH-1: 0] dataOutputA, dataOutputB;
//parameter IDLE=0, READING=1, PREWRITING=2, WRITING=3, WAITING=4, SECONDREAD=5, SECONDWRITE=6;

integer indexA, indexB;

initial begin
    for (i=0; i<MEMORYDEPTH; i=i+1) collectedIndices[i] <= -1;
    storageReady = 1;
    readReady = 1;
    skipNextAddress = 0;
    clearingIndex = -1;
    readingIndex = -1;
    writeEnableA = 0;
    writeEnableB = 0;
    itemInQueue1 = 0;
    itemInQueue2 = 0;
    //stateA = IDLE;
    //stateB = IDLE;
end

always @(posedge clock) begin

    // reset everything
    writeEnableA = 0;
    writeEnableB = 0;
    storageReady = 1;
    readReady = 1;
    //if (stateA == IDLE || stateB==IDLE) begin
        //storageReady = 1;
        //readReady = 1;
    //end
    //else begin
        //storageReady = 0;
        //readReady = 0;
    //end

    // if clearing or already in the processing of clearing the memory, keep clearing. keep storageReady=0 and readReady=0 during the process.
    if (clearStorage || clearingIndex >= 0) begin
        storageReady = 0;
        readReady = 0;
        if (clearingIndex < 0) clearingIndex = -1;
        clearingIndex = clearingIndex + 1;
        wordIndexA = clearingIndex;
        dataInputA = 0;
        writeEnableA = 1;
        //stateA = WRITING;
        if (clearingIndex < MEMORYDEPTH-1) begin
            clearingIndex = clearingIndex + 1;
            wordIndexB = clearingIndex;
            dataInputB = 0;
            writeEnableB = 1;
            //stateB = WRITING;
        end
        if (clearingIndex >= MEMORYDEPTH-1) begin
            clearingIndex = -1;
            //stateA = IDLE;
            //stateB = IDLE;
        end
    end

    //// test code - fill first word with successively increasing numbers
    //if (clearStorage || clearingIndex >= 0) begin
        //storageReady = 0;
        //readReady = 0;
        //if (clearingIndex < 0) clearingIndex = -1;
        //indexA = clearingIndex + 1;
        ////indexA = $urandom%10;
        //clearingIndex = indexA;
        //wordIndexA = clearingIndex;
        ////wordIndexA = 0;
        //dataInputA = clearingIndex;
        //writeEnableA = 1;
        ////stateA = WRITING;
        ////if (clearingIndex < MEMORYDEPTH-1) begin
            //////indexB = indexA;
            ////indexB = clearingIndex + 1;
            ////clearingIndex = indexB;
            ////wordIndexB = clearingIndex;
            //////wordIndexB = 0;
            ////dataInputB = clearingIndex;
            ////writeEnableB = 1;
            //////stateB = WRITING;
        ////end
        //if (clearingIndex >= MEMORYDEPTH-1) begin
            //clearingIndex = -1;
            ////stateA = IDLE;
            ////stateB = IDLE;
        //end
    //end

    // if storageReady turns off then on again, it will store the next address twice before AddressCounter can respond. This prevents that.
    if (!storageReady) skipNextAddress = 1;

    // store new address - second approach - read from B, write from A
    if (storageReady && (newAddress || itemInQueue1 || itemInQueue2)) begin
        storageReady = 0;
        if (!skipNextAddress) begin
            if ((wordIndex != queueWordIndex1) || !itemInQueue1) begin
                if (itemInQueue1) begin
                    // take what's currently in the read output and add in what's in the queue
                    wordIndexA = queueWordIndex1;
                    //addToWord = 1'b1<<queueLetterIndex1; // debugging
                    //dataInputA = dataOutputB | 1'b1<<queueLetterIndex1;
                    dataInputA = dataOutputB | queueNewHits1;
                    writeEnableA = 1;
                    itemInQueue1 = 0;
                end
                // move queue up
                queueWordIndex1 = queueWordIndex2;
                //queueLetterIndex1 = queueLetterIndex2;
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
                        //queueLetterIndex2 = letterIndex;
                        queueNewHits2 = 1'b1<<letterIndex;
                        itemInQueue2 = 1;
                    end
                    else begin
                        queueNewHits1 = queueNewHits1 | 1'b1<<letterIndex;
                    end
                end
            end
            else begin
                queueNewHits1 = queueNewHits1 | 1'b1<<letterIndex;
            end
        end
        else skipNextAddress = 0;
        storageReady = 1;
    end

    // test code - read out memory
    if (!newAddress && (readReady || readingIndex>=0)) begin
        storageReady = 0;
        readReady = 0;
        if (readingIndex < 0) readingIndex = -1;
        indexB = readingIndex + 1;
        //indexB = $urandom%10;
        readingIndex = indexB;
        wordIndexB = readingIndex;
        if (readingIndex >= MEMORYDEPTH-1) begin
            readingIndex = -1;
            storageReady = 1;
            readReady = 1;
        end
    end

    //// store new address - first attempt - read twice from A and write twice
    //to B, then switch
    //if (storageReady && newAddress) begin
        //storageReady = 0;
        //if (!skipNextAddress) begin
            //if (stateA == PREWRITING) stateA = WRITING;
            //if (stateB == PREWRITING) stateB = WRITING;
            //// if A or B is free, write. else, place in queue.
            //if (stateA == IDLE || stateA == SECONDREAD) begin
                //wordIndexA = wordIndex; // see what's stored in there
                //if (stateA == IDLE) begin
                    //queueA1 = letterIndex;
                    //stateA = SECONDREAD;
                //end
                //else begin
                    //queueA2 = letterIndex;
                    //stateA = PREWRITING;
                //end
            //end
            //else if (stateB == IDLE || stateB == SECONDREAD) begin
                //wordIndexB = wordIndex; // see what's stored in there
                //if (stateB == IDLE) begin
                    //queueB1 = letterIndex;
                    //stateB = SECONDREAD;
                //end
                //else begin
                    //queueB2 = letterIndex;
                    //stateB = PREWRITING;
                //end
            //end
            //// if A or B is writing, then keep writing
            //if (stateA == WRITING || stateA == SECONDWRITE) begin
                //if (stateA == WRITING) begin
                    //dataInputA = dataOutputA | 1'b1<<queueA1;
                    //stateA = SECONDWRITE;
                //end
                //else begin
                    //dataInputA = dataOutputA | 1'b1<<queueA2;
                    //stateA = IDLE;
                //end
                //writeEnableA = 1;
            //end
            //if (stateB == WRITING || stateB == SECONDWRITE) begin
                //if (stateB == WRITING) begin
                    //dataInputB = dataOutputB | 1'b1<<queueB1;
                    //stateB = SECONDWRITE;
                //end
                //else begin
                    //dataInputB = dataOutputB | 1'b1<<queueB2;
                    //stateB = IDLE;
                //end
                //writeEnableB = 1;
            //end
            //else begin
                //// both ports are writing? this shouldn't happen.
            //end
        //end
        //skipNextAddress = 0;
        //storageReady = 1;
    //end
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
