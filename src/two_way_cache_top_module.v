`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06/06/2026 03:04:37 PM
// Design Name: two_way_cache_top_module
// Module Name: two_way_top_module
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


module two_way_cache_top_module(input clk,
                    input rst,
                    input proc_req,
                    input rd_wr,
                    input [31:0] addr,
                    input [31:0] proc_wr_data,
                    input [127:0] mem_data,
                    input mem_ready,
                    output proc_stall,
                    output mem_req,
                    output mem_wr,
                    output [31:0] mem_addr,
                    output [31:0] proc_data
                    );

wire hit;
wire dirty;
wire store_in;
wire wr_hit;
wire rd_hit;
wire [127:0] rd_data;

cache_array c_array(.clk (clk),
                    .rst (rst),
                    .addr (addr),
                    .rd_wr (rd_wr),
                    .wr_data (mem_data),
                    .proc_wr_data (proc_wr_data),
                    .store_in (store_in),
                    .wr_hit (wr_hit),
                    .rd_hit (rd_hit),
                    .rd_data (rd_data),
                    .hit (hit),
                    .dirty (dirty)
                    );                  
                   
cache_controller c_controller(.clk (clk),
                              .rst (rst),
                              .proc_req (proc_req),
                              .rd_wr (rd_wr),
                              .addr (addr),
                              .hit (hit),
                              .dirty (dirty),
                              .mem_ready (mem_ready),
                              .proc_stall (proc_stall),
                              .mem_req (mem_req),
                              .mem_wr (mem_wr),
                              .mem_addr (mem_addr),
                              .store_in (store_in),
                              .wr_hit (wr_hit),
                              .rd_hit (rd_hit)                              
                              );
wire [3:0] offset = addr[3:0];
assign proc_data = rd_data[offset[3:2]*32 +: 32];

endmodule
