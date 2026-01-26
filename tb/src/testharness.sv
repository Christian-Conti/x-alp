// Copyright 2025 EPFL and Politecnico di Torino.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 2.0 (the "License"); you may not use this file except in
// compliance with the License. You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-2.0. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//
// File: x_alp_testharness.sv
// Author: Flavia Guella
// Date: 03/12/2025
// Inspired by x-heep testharness.sv

module testharness #(
    /// The selected simulation configuration from the `tb_x_alp_pkg`.
    // parameter int unsigned SelectedCfg  = 32'd0,
    // parameter bit          UseDramSys   = 1'b0,
    // parameter int unsigned DRAM_LATENCY = 32'd1,
    parameter int unsigned CLK_FREQUENCY = 'd100_000,  //KHz
    parameter bit USE_JTAG_DPI = 1'b0
) (
    input logic       clk_i,
    input logic       rst_ni,
    // input logic       test_mode_i,
    // Boot mode
    //----------
    input logic [1:0] boot_mode_i,

    // RTC Clic clock
    // --------------
    input logic rtc_i,

    // ELF to be loaded
    // ----------------
    //input string      preload_elf,

    // JTAG
    // ----
    input  logic        jtag_tck_i,
    input  logic        jtag_tms_i,
    input  logic        jtag_trst_ni,
    input  logic        jtag_tdi_i,
    output logic        jtag_tdo_o,
    // Exit sim
    // --------
    output logic [31:0] exit_value_o,
    output logic        exit_valid_o
);

    // Includes
    // --------
    `include "tb_util.svh"

    // Internal signals
    // ----------------

    // JTAG
    logic       sim_jtag_enable;
    logic       sim_jtag_tck;
    logic       sim_jtag_trst_n;
    logic       sim_jtag_tms;
    logic       sim_jtag_tdi;
    logic       sim_jtag_tdo;

    logic       jtag_tck;
    logic       jtag_trst_n;
    logic       jtag_tms;
    logic       jtag_tdi;
    logic       jtag_tdo;

    // UART
    logic       uart_tx;
    logic       uart_rx;
    // I2C
    logic       i2c_sda;
    logic       i2c_scl;
    // SPI
    logic [3:0] spih_sd;
    // Serial Link
    // logic         [SlinkNumChan-1:0]                    slink_rcv_clk;
    // logic         [SlinkNumChan-1:0][SlinkNumLanes-1:0] slink;

    // DRAM
    // axi_llc_req_t                                       axi_llc_mst_req;
    // axi_llc_rsp_t                                       axi_llc_mst_rsp;

    //----
    // DUT
    //----
    x_alp u_x_alp (
        .clk_i       (clk_i),
        .rst_ni      (rst_ni),
        .uart_tx_o   (uart_tx),
        .uart_rx_i   (uart_rx),
        .exit_valid_o(exit_valid_o),
        .exit_value_o(exit_value_o)
    );

    // UNSUPPORTED FEATURES in VERILATOR
`ifdef VERILATOR
    // I2C
    // ---
    assign i2c_sda = 1'b0;
    assign i2c_scl = 1'b0;
    // SPI
    // ---
    assign spih_sd = 4'b0;
    // Serial Link
    // -----------
    // assign slink_rcv_clk = '0;
    // assign slink         = '0;

`endif


    uartdpi #(
        .BAUD('d256000),
        .FREQ(CLK_FREQUENCY * 1000),  //Hz
        .NAME("uart0")
    ) i_uart0 (
        .clk_i,
        .rst_ni,
        .tx_o(uart_rx),
        .rx_i(uart_tx)
    );



    // JTAG BOOT MODE
    // --------------
    assign sim_jtag_enable = (boot_mode_i == 0 && USE_JTAG_DPI) ? 1'b1 : 1'b0;
    assign jtag_tck        = (sim_jtag_enable) ? sim_jtag_tck : jtag_tck_i;
    assign jtag_trst_n     = (sim_jtag_enable) ? sim_jtag_trst_n : jtag_trst_ni;
    assign jtag_tms        = (sim_jtag_enable) ? sim_jtag_tms : jtag_tms_i;
    assign jtag_tdi        = (sim_jtag_enable) ? sim_jtag_tdi : jtag_tdi_i;
    assign sim_jtag_tdo    = (sim_jtag_enable) ? jtag_tdo : 1'b0;
    assign jtag_tdo_o      = (sim_jtag_enable) ? 1'b0 : jtag_tdo;


    //------------
    // Exit values
    //------------
    // assign exit_valid_o = i_x_alp_soc.i_regs.u_scratch_2.q[0];
    // assign exit_value_o = (exit_valid_o) ? {1'b0, i_x_alp_soc.i_regs.u_scratch_2.q[31:1]} : 32'd1;

endmodule

