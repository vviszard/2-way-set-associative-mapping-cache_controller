`timescale 1ns/1ps

module two_way_cache_tb;

//signals to be driven
reg clk;
reg rst;
reg proc_req;
reg rd_wr;
reg [31:0] addr;
reg [31:0] proc_wr_data;
reg [127:0] mem_data;
reg mem_ready;
//signals to be observed
wire proc_stall;
wire mem_req;
wire mem_wr;
wire [31:0] mem_addr;
wire [31:0] proc_data;
//instantiating the top module
two_way_cache_top_module dut(.clk (clk), .rst(rst), .proc_req(proc_req), .rd_wr (rd_wr), .addr (addr), .proc_wr_data (proc_wr_data), .mem_data (mem_data), .mem_ready (mem_ready), .proc_stall (proc_stall), .mem_req (mem_req), .mem_wr (mem_wr), .mem_addr(mem_addr), .proc_data (proc_data));
//clock
initial clk = 0;
always #5 clk = ~clk;
//dumping for waveforms
initial
    begin
        $dumpfile("dump.vcd");
        $dumpvars(0, two_way_cache_tb);
        //default signals
        rst = 1;
        proc_req = 0;
        rd_wr = 1;
        addr = 32'h00000000;
        proc_wr_data = 32'h00000000;
        mem_data = 128'h00000000000000000000000000000000;
        mem_ready = 0;
        //apply reset
        #20;
        rst = 0;
        #10;
        //test case 1 read miss
        //reading at 0x00000013
        addr = 32'h00000013;
        rd_wr = 1; //when high -> read
        proc_req = 1;
        #10;
        proc_req = 0;
        //cache will detect miss and then fetch
        #30;
        mem_data = 128'hABCDEF12345678900987654321ABCDFE;
        mem_ready = 1;
        #10;
        mem_ready = 0;
        #30;
        //test case 2 read hit
        addr = 32'h00000013;
        rd_wr = 1;
        proc_req = 1;
        #10;
        proc_req = 0;
        #20;
        //test case 3 write hit
        addr = 32'h00000013;
        rd_wr = 0;
        proc_wr_data = 32'hABCDFF32;
        proc_req = 1;
        #10;
        proc_req = 0;
        #20;
        //test case 4 write miss
        addr = 32'h00001234;
        rd_wr = 0;
        proc_wr_data = 32'hABCD4321;
        proc_req = 1;
        #10;
        proc_req=0;
        #30;
        mem_data = 128'hAAAABBBBCCCCDDDDEEEEFFFF12341123;
        mem_ready = 1;
        #10;
        mem_ready = 0;
        #30;
        //test case 5 dirty bit read
        addr = 32'h0000FC10;
        rd_wr = 1;
        proc_req = 1;
        #10;
        proc_req = 0;
        #30;
        mem_data = 128'hAAAAAAAABBBBBBBB12345566778899AA;
        mem_ready = 1;
        #10;
        mem_ready = 0;
        #30;
        //test case 6 lru logic check
        addr = 32'hABCDE1D0;
        rd_wr = 1;
        proc_req = 1;
        #10;
        proc_req = 0;
        #30;
        mem_data = 128'h11111111111111111111111111111111;
        mem_ready = 1;
        #10;
        mem_ready = 0;
        #30;
        addr = 32'hF12453D0;
        rd_wr = 1;
        proc_req = 1;
        #10;
        proc_req = 0;
        #30;
        mem_data = 128'h11111111111111111111111111111111;
        mem_ready = 1;
        #10;
        mem_ready = 0;
        #30;
        addr = 32'hB00C51D0;
        rd_wr = 1;
        proc_req = 1;
        #10;
        proc_req = 0;
        #30;
        mem_data = 128'h11111111111111111111111111111111;
        mem_ready = 1;
        #10;
        mem_ready = 0;
        #30;
        addr = 32'hF12453D0;
        rd_wr = 1;
        proc_req = 1;
        #10;
        proc_req = 0;
        #20;
        addr = 32'hABCDE1D0;
        rd_wr = 1;
        proc_req = 1;
        #10;
        proc_req = 0;
        #30;
        mem_data = 128'h11111111111111111111111111111111;
        mem_ready = 1;
        #10;
        mem_ready = 0;
        #30;

        $finish;
    end
initial
    begin
        $monitor("t = %03t | addr = %h | hit = %b | stall = %b | mem_req = %b | mem_wr = %b | proc_data = %h", $time, addr, dut.hit, proc_stall, mem_req, mem_wr, proc_data);
    end
endmodule