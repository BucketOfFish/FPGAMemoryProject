localparam NROWS_HNM = 16; //128;
localparam NCOLS_HNM = 16; //512;
localparam ROWINDEXBITS_HNM = $clog2(NROWS_HNM); // 7
localparam COLINDEXBITS_HNM = $clog2(NCOLS_HNM); // 9

localparam MAXHITN = 4; // max of 4 hits per SSID
localparam MAXHITNBITS = $clog2(MAXHITN); // 2

localparam NROWS_HIM = 2048; // can store this many hits per event
localparam ROWINDEXBITS_HIM = $clog2(NROWS_HIM); // 11
/*localparam HITINFOBITS = 32; // information stored about hit*/
/*localparam NCOLS_HIM = HITINFOBITS * MAXHITN;*/
localparam HITINFOBITS = 8; // information stored about hit
localparam NCOLS_HIM = HITINFOBITS * MAXHITN;

localparam NROWS_HCM = NROWS_HNM * NCOLS_HNM; //65536
localparam ROWINDEXBITS_HCM = $clog2(NROWS_HCM); // 16
localparam SSIDBITS = ROWINDEXBITS_HCM;
localparam NCOLS_HCM = ROWINDEXBITS_HIM + MAXHITNBITS; // info for number of hits, plus address where first hit is stored

localparam QUEUESIZE = 3;
