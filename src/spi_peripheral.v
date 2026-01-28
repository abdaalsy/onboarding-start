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
    localparam IDLE   = 2'b00;
    localparam RECV   = 2'b01;
    localparam FINISH = 2'b10;

    // Replace state_t with standard reg vectors
    reg [1:0] current_state;
    reg [1:0] next_state;
    
    // registers for deciding output
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
            current_state <= IDLE;
            copi_sreg <= 16'h0000;
            sclk_sreg       <= 3'b111;
            ncs_sreg        <= 3'b111;
            en_reg_out_7_0 <= 8'h00;
            en_reg_out_15_8 <= 8'h00;
            en_reg_pwm_7_0 <= 8'h00;
            en_reg_pwm_15_8 <= 8'h00;
            pwm_duty_cycle <= 8'h00;
        end else begin 
            current_state <= next_state;
            // shift our SCLK and nCS registers
            sclk_sreg <= {sclk_sreg[1:0], SCLK};
            ncs_sreg <= {ncs_sreg[1:0], nCS};
            
            case (current_state)
                IDLE: begin 
                    copi_sreg <= 16'h0000;
                end
                RECV: begin 
                    if (sclk_posedge) begin
                        copi_sreg <= {copi_sreg[14:0], COPI};
                    end
                end
                FINISH: begin 
                    if (copi_sreg[15]) begin
                        case (copi_sreg[14:8])
                            7'b0000000: en_reg_out_7_0 <= copi_sreg[7:0];
                            7'b0000001: en_reg_out_15_8 <= copi_sreg[7:0];
                            7'b0000010: en_reg_pwm_7_0 <= copi_sreg[7:0];
                            7'b0000011: en_reg_pwm_15_8 <= copi_sreg[7:0];
                            7'b0000100: pwm_duty_cycle <= copi_sreg[7:0];
                            default: ;
                        endcase
                    end
                end
                2'b11: ; // this state will never be encountered
            endcase
        end
    end
    
    // combinational logic to determine next state
    always @(*) begin
        next_state = current_state;
        if (ncs_posedge) begin 
            next_state = FINISH;
        end else begin 
            case (current_state)
                IDLE: if (ncs_negedge) next_state = RECV;
                RECV: if (ncs_posedge) next_state = FINISH;
                FINISH: next_state = IDLE;
                2'b11: ; // This state will never be encountered
            endcase
        end
    end
endmodule
