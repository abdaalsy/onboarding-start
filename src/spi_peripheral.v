/*
 * Copyright (c) 2024 Abdaal Sylani
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module spi_peripheral (
    input   wire    rst_n,
    input   wire    clk,
    input   wire    nCS,
    input   wire    SCLK,
    input   wire    COPI,
    output  wire [7:0] en_reg_out_7_0,
    output  wire [7:0] en_reg_out_15_8,
    output  wire [7:0] en_reg_pwm_7_0,
    output  wire [7:0] en_reg_pwm_15_8,
    output  wire [7:0] pwm_duty_cycle
);
    // states for peripheral
    typedef enum logic [1:0] {
        RESET,
        IDLE,
        RECV,
        FINISH
    } state_t;

    reg [6:0] address;
    reg [7:0] value;
    reg transaction_ready;

    reg[2:0] sclk_sreg;         // shift reg for SCLK
    reg[2:0] ncs_sreg;          // shift reg for nCS
    reg[15:0] copi_sreg;        // shift reg for COPI

    always @(posedge clk or negedge rst_n) begin
        // check if we're in the reset state
        if (!rst_n) begin 
            current_state <= RESET;
        end
        // shift our SCLK and nCS registers
        sclk_sreg <= {sclk_sreg[1:0], SCLK};
        ncs_sreg <= {ncs_sreg[1:0], nCS};
    end

    // for both registers, the newest flip-flop was just samples and thus needs time to settle
    // so we're gonna perform our condition on the 2 stable older values
    wire sclk_posedge = (sclk_sreg[1] == 1'b1 && sclk_sreg[2] == 1'b0);
    wire ncs_negedge = (ncs_sreg[1] == 1'b0 && ncs_sreg[2] == 1'b1);
    wire ncs_posedge = (ncs_sreg[1] == 1'b1 && ncs_sreg[2] == 1'b0);
    
    // this is where our state logic is gonna happen
    reg [3:0] bit_count;
    always @(*) begin
        if (ncs_posedge) begin
            current_state = FINISH;
        end
        case (current_state)
            RESET: begin 
                en_reg_out_7_0 = 8'h00;
                en_reg_out_15_8 = 8'h00;
                en_reg_pwm_7_0 = 8'h00;
                en_reg_pwm_15_8 = 8'h00;
                pwm_duty_cycle = 8'h00;
                address = 7'b0000000;
                value = 8'h00;
                transaction_ready = 1'b0;
                current_state = IDLE;
            end
            IDLE: begin
                address = copi_sreg[14:8];
                value = copi_sreg[7:0];
                transaction_ready = 1'b1;
                bit_count = 4'b0000;
                if (ncs_negedge) begin
                    current_state = RECV;
                end
            end
            RECV: begin
                transaction_ready = 1'b0;
                address = 7'b0000000;
                value = 8'h00;
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
                address = copi_sreg[14:8];
                value = copi_sreg[7:0];
                transaction_ready = 1'b1;
                case (address) 
                    7'b0000000: en_reg_out_7_0 = value;   // address 0x00
                    7'b0000001: en_reg_out_15_8 = value;  // address 0x01
                    7'b0000010: en_reg_pwm_7_0 = value;   // address 0x02
                    7'b0000011: en_reg_pwm_15_8 = value;  // address 0x03
                    7'b0000100: pwm_duty_cycle = value;   // address 0x04
                    default: current_state = IDLE;              // this will catch out of bounds address
                endcase
                current_state = IDLE;
            end
        endcase
    end
endmodule
