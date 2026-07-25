`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Vishwas Paliwal
// Engineer: Vishwas Paliwal
// 
// Create Date: 06/06/2026 09:59:37 AM
// Design Name: cache_array
// Module Name: cache_array
// Project Name: two way set associative mapping cache controller
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

//for a 32 bit address, 1KB of cache memory, each cache line is 128 bits that is 4 words. it is byte addressable
//addres => [22-bit tag | 6-bit index | 4-bit offset]
module cache_array(input clk, 
                   input rst, 
                   input rd_wr, 
                   input wr_hit, 
                   input [31:0] addr, 
                   input [127:0] wr_data, //from memory
                   input [31:0] proc_wr_data, //from processor during cache write
                   input store_in, //tells the cache array to write in from the memory during the update state 
                   input rd_hit,
                   output hit, 
                   output dirty, 
                   output reg [127:0] rd_data
                   );

wire hit_way0, hit_way1, hit_way, evict_way;

//splitting up the address into fields
wire [3:0] offset_in = addr[3:0];
wire [4:0] index_in = addr[8:4];
wire [22:0] tag_in = addr[31:9];
//setting up the various arrays
reg valid_arr [1:0][31:0];
reg dirty_arr [1:0][31:0];
reg [22:0] tag_arr [1:0][31:0]; //3D array with 2 row and 32 coloumn and with each element 23 bits long
reg [127:0] data_arr [1:0][31:0]; //3D array with 2 row and 32 coloumn and with each element 128 bits long
reg lru [31:0]; // 1 bit per set
//assigning hit and dirty output to drive the FSM states
assign hit_way0 = valid_arr[0][index_in] & (tag_arr[0][index_in] == tag_in); //when cache hit is in 0 index way of the set
assign hit_way1 = valid_arr[1][index_in] & (tag_arr[1][index_in] == tag_in); //when cache hit is in 1 index way of the set
assign hit = hit_way0 | hit_way1;
assign hit_way = hit_way1; // hit_way will tell from which line rd_data should be filled. when 0 = read hit_way0, when 1 = read hit_way 1;
assign dirty = dirty_arr[evict_way][index_in];
assign evict_way = lru[index_in];
integer j;
integer i; // variable for loop

always @(posedge clk or posedge rst)
    begin
        if (rst)
            for (j = 0; j < 2; j = j + 1)
                begin
                for (i = 0; i < 32; i = i +1)
                    begin 
                        valid_arr[j][i] <= 1'b0;
                        dirty_arr[j][i] <= 1'b0;
                        lru[i] <= 1'b0;
                    end
                end
        else if (store_in)
            begin
                valid_arr[evict_way][index_in] <= 1'b1;
                dirty_arr[evict_way][index_in] <= 1'b0; //freshly out from memory so 0
                tag_arr[evict_way][index_in] <= tag_in;
                data_arr[evict_way][index_in] <= wr_data;
                lru[index_in] <= ~evict_way;
            end
        else if (wr_hit)
            begin
                data_arr[hit_way][index_in][offset_in[3:2]*32 +: 32] <= proc_wr_data; //selecting one single word to write in 
                dirty_arr[hit_way][index_in] <= 1'b1; //block is modified, so now its dirty.
                lru[index_in] <= ~hit_way;
            end
        else if (rd_hit)
            begin
                lru[index_in] <= ~hit_way;
            end            
    end

always @(*)
    begin
        if (hit)
            rd_data = data_arr[hit_way][index_in];
        else
            rd_data = 128'b0;
    end
    
endmodule