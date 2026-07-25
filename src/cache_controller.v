`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Vishwas Paliwal
// Engineer: Vishwas Paliwal
// 
// Create Date: 06/06/2026 01:28:05 PM
// Design Name: cache_controller
// Module Name: cache_controller
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


module cache_controller( input clk,
                         input rst,
                         input proc_req,
                         input rd_wr,
                         input [31:0] addr,
                         input hit,
                         input dirty,
                         input mem_ready,
                         output reg proc_stall,
                         output reg mem_req,
                         output reg mem_wr,
                         output reg store_in,
                         output reg [31:0] mem_addr,
                         output reg wr_hit,
                         output reg rd_hit
                         );

parameter IDLE = 2'b00;
parameter COMPARE = 2'b01;
parameter FETCH = 2'b10;
parameter UPDATE = 2'b11;

reg [1:0] current_state, next_state;

always @(posedge clk or posedge rst)
    begin
        if (rst)
            current_state <= IDLE;
        else
            current_state <= next_state;
    end

always @(*)
    begin
        case (current_state)
            IDLE: 
                begin
                    if (proc_req)
                        next_state = COMPARE;
                    else
                        next_state = IDLE;
                end
            
            COMPARE: 
                begin
                    if (hit)
                        next_state = IDLE;
                    else
                        next_state = FETCH;
                end
            
            FETCH:
                begin
                    if (mem_ready)
                        next_state = UPDATE;
                    else
                        next_state = FETCH;
                end
            
            UPDATE: next_state = COMPARE;
            default: next_state = IDLE;
        endcase
    end
    
always @(*)
    begin
        mem_req = 0;
        store_in = 0;
        proc_stall = 0;
        mem_addr = 0;
        mem_wr = 0;
        wr_hit = 0;
        rd_hit = 0;
        
        case (current_state)
            IDLE: ;
             
            COMPARE: 
                begin
                    proc_stall = 1;
                    if (hit)
                        begin
                            proc_stall = 0;
                            if (rd_wr == 0)
                                wr_hit = 1;
                            else if (rd_wr == 1)
                                rd_hit = 1;
                        end 
                end 
            FETCH: 
                begin
                    proc_stall = 1;
                    mem_req = 1;
                    mem_addr = addr;
                end
            UPDATE: 
                begin
                    proc_stall = 1;
                    store_in = 1;
                    if (dirty)
                        begin
                            mem_req = 1;
                            mem_wr = 1;
                        end
                        
                end           
        endcase        
    end
endmodule