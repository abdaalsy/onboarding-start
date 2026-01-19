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
    output  reg [7:0] en_reg_out_7_0,
    output  reg [7:0] en_reg_out_15_8,
    output  reg [7:0] en_reg_pwm_7_0,
    output  reg [7:0] en_reg_pwm_15_8,
    output  reg [7:0] pwm_duty_cycle
);
    // states for peripheral
    typedef enum logic [1:0] {
        RESET,
        IDLE,
        RECV,
        FINISH
    } state_t;
    state_t current_state, next_state;
    
    // registers for deciding output
    reg [5:0] bit_count;
    reg [6:0] address;
    reg [7:0] value;
    reg transaction_ready;
    reg[2:0] sclk_sreg;         // shift reg for SCLK
    reg[2:0] ncs_sreg;          // shift reg for nCS
    reg[15:0] copi_sreg;        // shift reg for COPI

    // for both registers, the newest flip-flop was just sampled and thus needs time to settle
    // so we're gonna perform our condition on the 2 stable older values
    wire sclk_posedge = (sclk_sreg[1] == 1'b1 && sclk_sreg[2] == 1'b0);
    wire ncs_negedge = (ncs_sreg[1] == 1'b0 && ncs_sreg[2] == 1'b1);
    wire ncs_posedge = (ncs_sreg[1] == 1'b1 && ncs_sreg[2] == 1'b0);
    
    always @(posedge clk or negedge rst_n) begin
        // check if we're in the reset state
        if (!rst_n) begin
            current_state <= RESET;
        end
        // shift our SCLK and nCS registers
        current_state <= next_state;
        sclk_sreg <= {sclk_sreg[1:0], SCLK};
        ncs_sreg <= {ncs_sreg[1:0], nCS};
        
        case (current_state)
            RESET: begin 
                address <= 7'b0000000;
                value <= 8'h00;
                transaction_ready <= 1'b0;
                bit_count <= 5'h00;
                sclk_sreg <= 3'b111;
                ncs_sreg <= 3'b111;
                copi_sreg <= 16'h0000;
                en_reg_out_7_0 <= 8'h00;
                en_reg_out_15_8 <= 8'h00;
                en_reg_pwm_7_0 <= 8'h00;
                en_reg_pwm_15_8 <= 8'h00;
                pwm_duty_cycle <= 8'h00;
            end
            IDLE: begin 
                address <= 7'b0000000;
                value <= 8'h00;
                transaction_ready <= 1'b1;
                bit_count <= 5'h00;
                copi_sreg <= 16'h0000;
                en_reg_out_7_0 <= 8'h00;
                en_reg_out_15_8 <= 8'h00;
                en_reg_pwm_7_0 <= 8'h00;
                en_reg_pwm_15_8 <= 8'h00;
                pwm_duty_cycle <= 8'h00;
            end
            RECV: begin 
                address <= 7'b0000000;
                value <= 8'h00;
                transaction_ready <= 1'b0;
                if (sclk_posedge) begin
                    copi_sreg <= {copi_sreg[14:0], COPI};
                    bit_count <= bit_count + 1'b1;
                end
                en_reg_out_7_0 <= 8'h00;
                en_reg_out_15_8 <= 8'h00;
                en_reg_pwm_7_0 <= 8'h00;
                en_reg_pwm_15_8 <= 8'h00;
                pwm_duty_cycle <= 8'h00;
            end
            FINISH: begin 
                address <= copi_sreg[14:8];
                value <= copi_sreg[7:0];
                transaction_ready <= 1'b0;
                copi_sreg <= copi_sreg;
                bit_count <= 5'h00;
                case (address)
                    7'b0000000: en_reg_out_7_0 <= value;
                    7'b0000001: en_reg_out_15_8 <= value;
                    7'b0000010: en_reg_pwm_7_0 <= value;
                    7'b0000011: en_reg_pwm_15_8 <= value;
                    7'b0000100: pwm_duty_cycle <= value;
                    default: ;
                endcase
            end
        endcase
    end
    
    // combinational logic to determine next state
    always @(*) begin
        next_state = current_state;
        if (ncs_posedge) begin 
            next_state = FINISH;
        end else begin 
            case (current_state)
                RESET: next_state = IDLE;
                IDLE: if (ncs_negedge) next_state = RECV;
                RECV: if (bit_count = 5'b10000) next_state = FINISH;
                FINISH: next_state = IDLE;
            endcase
            if (ncs_negedge) next_state = IDLE;
        end
    end
endmodule
