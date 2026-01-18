/*
 * Copyright (c) 2024 Abdaal Sylani
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module spi_peripheral (
    input   wire    clk,
    input   wire    nCS,
    input   wire    SCLK,
    input   wire    COPI,
    output  wire    address,
    output  wire    value,
    output  wire    transaction_ready,
);
    // states for peripheral
    typedef enum logic [1:0] {
        IDLE,
        RECV,
        FINISH,
    } state_t;

    state_t current_state = IDLE;

    reg[2:0] sclk_sreg;         // shift reg for SCLK
    reg[2:0] ncs_sreg;          // shift reg for nCS
    reg[15:0] copi_sreg;        // shift reg for COPI

    assign address = copi_sreg[14:8];
    assign value = copi_sreg[7:0]; 

    always @(posedge clk) begin
        // shift our SCLK and nCS registers
        sclk_sreg <= {sclk_sreg[1:0], SCLK};
        ncs_sreg <= {ncs_sreg[1:0], nCS};
    end

    // for both registers, the newest flip-flop was just samples and thus needs time to settle
    // so we're gonna perform our condition on the 2 stable older values
    wire sclk_posedge = (sclk_sreg[1] == 1'b1 && sclk_sreg[2] == 1'b0);
    wire ncs_negedge = (ncs_sreg[1] == 1'b0 && ncs_sreg[2] == 1'b1);
    wire ncs_posedge = (ncs_sreg[1] == 1'b1 && ncs_sreg[2] == 1'b0);
    assign transaction_ready = (current_state == IDLE);
    
    // this is where our state logic is gonna happen
    reg [3:0] bit_count;
    always @(*) begin
        if (ncs_posedge) begin
            current_state = FINISH;
        end
        case (current_state)
            IDLE: begin
                assign address = copi_sreg[14:8];
                assign value = copi_sreg[7:0];
                assign transaction_ready = 1'b1;
                bit_count = 4'b0000;
                if (ncs_negedge) begin
                    current_state = RECV;
                end
            end
            RECV: begin
                assign transaction_ready = 1'b0;
                assign address = 7'b0000000;
                assign value = 8'h00;
                if (sclk_posedge) begin
                    copi_sreg = {copi_sreg[14:0], COPI};
                    bit_count = bit_count + 1'b1;
                    if (bit_count == 4'b0000) begin
                        current_state = FINISH;
                    end else begin
                        current_state = RECV;
                    end
                end else begin
                    current_state = RECV;
                end
            end
            FINISH: begin
                assign address = copi_sreg[14:8];
                assign value = copi_sreg[7:0];
                assign transaction_ready = 1'b1;
                current_state = IDLE;
            end
        endcase
    end

