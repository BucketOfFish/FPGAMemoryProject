localparam MEMNROWS_HNM = 128;
localparam MEMNCOLS_HNM = 512;
localparam ROWINDEXBITS_HNM = log2(MEMNROWS_HNM); // 7
localparam COLINDEXBITS_HNM = log2(MEMNCOLS_HNM); // 9

localparam MAXHITN = 4; // max of 4 hits per SSID
localparam MAXHITNBITS = log2(MAXHITN); // 2

localparam MEMNROWS_HLM = 8192; // can store this many hits per event (4 hits per SSID)
localparam ROWINDEXBITS_HLM = log2(MEMNROWS_HLM); // 13
localparam COLINDEXBITS_HLM = 32; // information stored about hit

localparam MEMNROWS_HCM = MEMNROWS_HNM * MEMNCOLS_HNM;
localparam ROWINDEXBITS_HCM = ROWINDEXBITS_HNM + COLINDEXBITS_HNM;
localparam ADDRESSNBITS = ROWINDEXBITS_HCM;
localparam COLINDEXBITS_HCM = ROWINDEXBITS_HLM + MAXHITNBITS; // info for number of hits, plus address where first hit is stored
