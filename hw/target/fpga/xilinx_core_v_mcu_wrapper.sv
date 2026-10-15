// Copyright 2026 X-HEEP Contributors
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// FPGA wrapper for X-ALP. On ZCU104, the LLC master is connected to the
// PL-side DDR4 SODIMM through the AXI upsizer and DDR4 MIG.
//

`include "axi/typedef.svh"

module xilinx_core_v_mcu_wrapper #(
    parameter int unsigned CLK_LED_COUNT_LENGTH = 27,
    // For the 64-bit PL DDR4 SODIMM, PG150's MIG AXI UI is 512 bits wide.
    // Keep these values in sync with the generated xilinx_ddr4_ctrl_wizard IP.
    parameter int unsigned DDR_AXI_ADDR_WIDTH   = 32,
    parameter int unsigned DDR_AXI_DATA_WIDTH   = 512
) (

`ifdef FPGA_AUP_ZU3
    input logic clk_100mhz_n,
    input logic clk_100mhz_p,
`elsif FPGA_ZCU104
    input logic clk_300mhz_n,
    input logic clk_300mhz_p,

    output logic        ddr4_sdram_act_n,
    output logic [16:0] ddr4_sdram_adr,
    output logic [ 1:0] ddr4_sdram_ba,
    output logic [ 1:0] ddr4_sdram_bg,
    output logic        ddr4_sdram_ck_c,
    output logic        ddr4_sdram_ck_t,
    output logic        ddr4_sdram_cke,
    output logic        ddr4_sdram_cs_n,
    output logic [ 7:0] ddr4_sdram_dm_n,
    inout  logic [63:0] ddr4_sdram_dq,
    inout  logic [ 7:0] ddr4_sdram_dqs_c,
    inout  logic [ 7:0] ddr4_sdram_dqs_t,
    output logic        ddr4_sdram_odt,
    output logic        ddr4_sdram_reset_n,
`else
    input  logic        clk_i,
`endif

    input logic rst_i,

    output logic rst_led_o,
    output logic clk_led_o,

    input  logic jtag_tck_i,
    input  logic jtag_tms_i,
    input  logic jtag_trst_ni,
    input  logic jtag_tdi_i,
    output logic jtag_tdo_o,

    input  logic uart_rx_i,
    output logic uart_tx_o,

    output logic exit_value_o,
    output logic exit_valid_o
);

    import core_v_mcu_pkg::*;

    wire                             clk_gen;
    wire                             soc_clk;
    wire                             soc_rst_n;
    logic [                    31:0] exit_value;
    logic [CLK_LED_COUNT_LENGTH-1:0] clk_count;

    // The X-ALP LLC emits 64-bit AXI requests. The DDR4 MIG for the board's
    // 64-bit memory interface emits a 512-bit AXI UI, so widen the data path.
    typedef logic [DDR_AXI_DATA_WIDTH-1:0] ddr_axi_data_t;
    typedef logic [DDR_AXI_DATA_WIDTH/8-1:0] ddr_axi_strb_t;
    `AXI_TYPEDEF_W_CHAN_T(ddr_axi_w_chan_t, ddr_axi_data_t, ddr_axi_strb_t, axi_user_t)
    `AXI_TYPEDEF_R_CHAN_T(ddr_axi_r_chan_t, ddr_axi_data_t, axi_mst_id_t, axi_user_t)
    `AXI_TYPEDEF_REQ_T(ddr_axi_req_t, axi_mst_aw_chan_t, ddr_axi_w_chan_t, axi_mst_ar_chan_t)
    `AXI_TYPEDEF_RESP_T(ddr_axi_rsp_t, axi_mst_b_chan_t, ddr_axi_r_chan_t)

    axi_mst_req_t llc_req;
    axi_mst_rsp_t llc_rsp;

    axi_mst_req_t ext_mst_req;
    axi_mst_rsp_t ext_mst_rsp;
    wire          jtag_tdo_oe_unused;

    assign ext_mst_req = '0;

    x_alp x_alp_system_i (
        .clk_i        (soc_clk),
        .rst_ni       (soc_rst_n),
        .jtag_tck_i   (jtag_tck_i),
        .jtag_tms_i   (jtag_tms_i),
        .jtag_trst_ni (jtag_trst_ni),
        .jtag_tdi_i   (jtag_tdi_i),
        .jtag_tdo_o   (jtag_tdo_o),
        .jtag_tdo_oe_o(jtag_tdo_oe_unused),
        .uart_rx_i    (uart_rx_i),
        .uart_tx_o    (uart_tx_o),
        .exit_valid_o (exit_valid_o),
        .exit_value_o (exit_value),
        .ext_slv_req_o(),
        .ext_slv_rsp_i('0),
        .ext_mst_req_i(ext_mst_req),
        .ext_mst_rsp_o(ext_mst_rsp),
        .ext_reg_req_o(),
        .ext_reg_rsp_i(),
        .ext_llc_req_o(llc_req),
        .ext_llc_rsp_i(llc_rsp),
        .test_mode_i  (1'b0)
    );

    assign exit_value_o = exit_value[0];
    assign clk_led_o    = clk_count[CLK_LED_COUNT_LENGTH-1];

    always_ff @(posedge soc_clk or negedge soc_rst_n) begin : clk_count_process
        if (!soc_rst_n) begin
            clk_count <= '0;
        end else begin
            clk_count <= clk_count + 1'b1;
        end
    end

`ifdef FPGA_ZCU104
    logic                                    c0_ddr4_ui_clk;
    logic                                    c0_ddr4_ui_clk_sync_rst;
    logic                                    c0_init_calib_complete;
    logic         [                     1:0] soc_rst_sync;

    ddr_axi_req_t                            ddr_axi_mst_req;
    ddr_axi_rsp_t                            ddr_axi_mst_rsp;

    logic         [  DDR_AXI_ADDR_WIDTH-1:0] C0_DDR4_S_AXI_araddr;
    logic         [                     1:0] C0_DDR4_S_AXI_arburst;
    logic         [                     3:0] C0_DDR4_S_AXI_arcache;
    logic         [       AxiMstIdWidth-1:0] C0_DDR4_S_AXI_arid;
    logic         [                     7:0] C0_DDR4_S_AXI_arlen;
    logic                                    C0_DDR4_S_AXI_arlock;
    logic         [                     2:0] C0_DDR4_S_AXI_arprot;
    logic         [                     3:0] C0_DDR4_S_AXI_arqos;
    logic                                    C0_DDR4_S_AXI_arready;
    logic         [                     2:0] C0_DDR4_S_AXI_arsize;
    logic                                    C0_DDR4_S_AXI_arvalid;
    logic         [  DDR_AXI_ADDR_WIDTH-1:0] C0_DDR4_S_AXI_awaddr;
    logic         [                     1:0] C0_DDR4_S_AXI_awburst;
    logic         [                     3:0] C0_DDR4_S_AXI_awcache;
    logic         [       AxiMstIdWidth-1:0] C0_DDR4_S_AXI_awid;
    logic         [                     7:0] C0_DDR4_S_AXI_awlen;
    logic                                    C0_DDR4_S_AXI_awlock;
    logic         [                     2:0] C0_DDR4_S_AXI_awprot;
    logic         [                     3:0] C0_DDR4_S_AXI_awqos;
    logic                                    C0_DDR4_S_AXI_awready;
    logic         [                     2:0] C0_DDR4_S_AXI_awsize;
    logic                                    C0_DDR4_S_AXI_awvalid;
    logic         [       AxiMstIdWidth-1:0] C0_DDR4_S_AXI_bid;
    logic                                    C0_DDR4_S_AXI_bready;
    logic         [                     1:0] C0_DDR4_S_AXI_bresp;
    logic                                    C0_DDR4_S_AXI_bvalid;
    logic         [  DDR_AXI_DATA_WIDTH-1:0] C0_DDR4_S_AXI_rdata;
    logic         [       AxiMstIdWidth-1:0] C0_DDR4_S_AXI_rid;
    logic                                    C0_DDR4_S_AXI_rlast;
    logic                                    C0_DDR4_S_AXI_rready;
    logic         [                     1:0] C0_DDR4_S_AXI_rresp;
    logic                                    C0_DDR4_S_AXI_rvalid;
    logic         [  DDR_AXI_DATA_WIDTH-1:0] C0_DDR4_S_AXI_wdata;
    logic                                    C0_DDR4_S_AXI_wlast;
    logic                                    C0_DDR4_S_AXI_wready;
    logic         [DDR_AXI_DATA_WIDTH/8-1:0] C0_DDR4_S_AXI_wstrb;
    logic                                    C0_DDR4_S_AXI_wvalid;

    // Synchronize release of the SoC reset to the MIG UI clock. The CPU stays
    // in reset until DDR calibration has completed.
    always_ff @(posedge c0_ddr4_ui_clk or posedge rst_i) begin : soc_reset_sync
        if (rst_i) begin
            soc_rst_sync <= '0;
        end else if (c0_ddr4_ui_clk_sync_rst || !c0_init_calib_complete) begin
            soc_rst_sync <= '0;
        end else begin
            soc_rst_sync <= {soc_rst_sync[0], 1'b1};
        end
    end

    assign soc_clk   = c0_ddr4_ui_clk;
    assign soc_rst_n = soc_rst_sync[1];
    assign rst_led_o = soc_rst_n;

    axi_dw_converter #(
        .AxiMaxReads        (16),
        .AxiSlvPortDataWidth(AxiDataWidth),
        .AxiMstPortDataWidth(DDR_AXI_DATA_WIDTH),
        .AxiAddrWidth       (AxiAddrWidth),
        .AxiIdWidth         (AxiMstIdWidth),
        .aw_chan_t          (axi_mst_aw_chan_t),
        .mst_w_chan_t       (ddr_axi_w_chan_t),
        .slv_w_chan_t       (axi_mst_w_chan_t),
        .b_chan_t           (axi_mst_b_chan_t),
        .ar_chan_t          (axi_mst_ar_chan_t),
        .mst_r_chan_t       (ddr_axi_r_chan_t),
        .slv_r_chan_t       (axi_mst_r_chan_t),
        .axi_mst_req_t      (ddr_axi_req_t),
        .axi_mst_resp_t     (ddr_axi_rsp_t),
        .axi_slv_req_t      (axi_mst_req_t),
        .axi_slv_resp_t     (axi_mst_rsp_t)
    ) axi_dw_converter_i (
        .clk_i     (soc_clk),
        .rst_ni    (soc_rst_n),
        .slv_req_i (llc_req),
        .slv_resp_o(llc_rsp),
        .mst_req_o (ddr_axi_mst_req),
        .mst_resp_i(ddr_axi_mst_rsp)
    );

    // Flatten the typed X-ALP AXI request into the DDR4 MIG AXI ports.
    assign C0_DDR4_S_AXI_araddr  = ddr_axi_mst_req.ar.addr[DDR_AXI_ADDR_WIDTH-1:0];
    assign C0_DDR4_S_AXI_arburst = ddr_axi_mst_req.ar.burst;
    assign C0_DDR4_S_AXI_arcache = ddr_axi_mst_req.ar.cache;
    assign C0_DDR4_S_AXI_arid    = ddr_axi_mst_req.ar.id;
    assign C0_DDR4_S_AXI_arlen   = ddr_axi_mst_req.ar.len;
    assign C0_DDR4_S_AXI_arlock  = ddr_axi_mst_req.ar.lock;
    assign C0_DDR4_S_AXI_arprot  = ddr_axi_mst_req.ar.prot;
    assign C0_DDR4_S_AXI_arqos   = ddr_axi_mst_req.ar.qos;
    assign C0_DDR4_S_AXI_arsize  = ddr_axi_mst_req.ar.size;
    assign C0_DDR4_S_AXI_arvalid = ddr_axi_mst_req.ar_valid;
    assign C0_DDR4_S_AXI_rready  = ddr_axi_mst_req.r_ready;

    assign C0_DDR4_S_AXI_awaddr  = ddr_axi_mst_req.aw.addr[DDR_AXI_ADDR_WIDTH-1:0];
    assign C0_DDR4_S_AXI_awburst = ddr_axi_mst_req.aw.burst;
    assign C0_DDR4_S_AXI_awcache = ddr_axi_mst_req.aw.cache;
    assign C0_DDR4_S_AXI_awid    = ddr_axi_mst_req.aw.id;
    assign C0_DDR4_S_AXI_awlen   = ddr_axi_mst_req.aw.len;
    assign C0_DDR4_S_AXI_awlock  = ddr_axi_mst_req.aw.lock;
    assign C0_DDR4_S_AXI_awprot  = ddr_axi_mst_req.aw.prot;
    assign C0_DDR4_S_AXI_awqos   = ddr_axi_mst_req.aw.qos;
    assign C0_DDR4_S_AXI_awsize  = ddr_axi_mst_req.aw.size;
    assign C0_DDR4_S_AXI_awvalid = ddr_axi_mst_req.aw_valid;
    assign C0_DDR4_S_AXI_bready  = ddr_axi_mst_req.b_ready;

    assign C0_DDR4_S_AXI_wdata   = ddr_axi_mst_req.w.data;
    assign C0_DDR4_S_AXI_wlast   = ddr_axi_mst_req.w.last;
    assign C0_DDR4_S_AXI_wstrb   = ddr_axi_mst_req.w.strb;
    assign C0_DDR4_S_AXI_wvalid  = ddr_axi_mst_req.w_valid;

    always_comb begin
        ddr_axi_mst_rsp          = '0;
        ddr_axi_mst_rsp.ar_ready = C0_DDR4_S_AXI_arready;
        ddr_axi_mst_rsp.aw_ready = C0_DDR4_S_AXI_awready;
        ddr_axi_mst_rsp.w_ready  = C0_DDR4_S_AXI_wready;
        ddr_axi_mst_rsp.b_valid  = C0_DDR4_S_AXI_bvalid;
        ddr_axi_mst_rsp.b.id     = C0_DDR4_S_AXI_bid;
        ddr_axi_mst_rsp.b.resp   = C0_DDR4_S_AXI_bresp;
        ddr_axi_mst_rsp.r_valid  = C0_DDR4_S_AXI_rvalid;
        ddr_axi_mst_rsp.r.id     = C0_DDR4_S_AXI_rid;
        ddr_axi_mst_rsp.r.data   = C0_DDR4_S_AXI_rdata;
        ddr_axi_mst_rsp.r.last   = C0_DDR4_S_AXI_rlast;
        ddr_axi_mst_rsp.r.resp   = C0_DDR4_S_AXI_rresp;
    end

    xilinx_clk_wizard_wrapper xilinx_clk_wizard_wrapper_i (
        .CLK_IN1_D_0_clk_n(clk_300mhz_n),
        .CLK_IN1_D_0_clk_p(clk_300mhz_p),
        .clk_out1_0       (clk_gen)
    );

    xilinx_ddr4_ctrl_wizard ddr4_ctrl_i (
        .ddr4_sdram_act_n  (ddr4_sdram_act_n),
        .ddr4_sdram_adr    (ddr4_sdram_adr),
        .ddr4_sdram_ba     (ddr4_sdram_ba),
        .ddr4_sdram_bg     (ddr4_sdram_bg),
        .ddr4_sdram_ck_c   (ddr4_sdram_ck_c),
        .ddr4_sdram_ck_t   (ddr4_sdram_ck_t),
        .ddr4_sdram_cke    (ddr4_sdram_cke),
        .ddr4_sdram_cs_n   (ddr4_sdram_cs_n),
        .ddr4_sdram_dm_n   (ddr4_sdram_dm_n),
        .ddr4_sdram_dq     (ddr4_sdram_dq),
        .ddr4_sdram_dqs_c  (ddr4_sdram_dqs_c),
        .ddr4_sdram_dqs_t  (ddr4_sdram_dqs_t),
        .ddr4_sdram_odt    (ddr4_sdram_odt),
        .ddr4_sdram_reset_n(ddr4_sdram_reset_n),

        .C0_DDR4_S_AXI_araddr (C0_DDR4_S_AXI_araddr),
        .C0_DDR4_S_AXI_arburst(C0_DDR4_S_AXI_arburst),
        .C0_DDR4_S_AXI_arcache(C0_DDR4_S_AXI_arcache),
        .C0_DDR4_S_AXI_arid   (C0_DDR4_S_AXI_arid),
        .C0_DDR4_S_AXI_arlen  (C0_DDR4_S_AXI_arlen),
        .C0_DDR4_S_AXI_arlock (C0_DDR4_S_AXI_arlock),
        .C0_DDR4_S_AXI_arprot (C0_DDR4_S_AXI_arprot),
        .C0_DDR4_S_AXI_arqos  (C0_DDR4_S_AXI_arqos),
        .C0_DDR4_S_AXI_arready(C0_DDR4_S_AXI_arready),
        .C0_DDR4_S_AXI_arsize (C0_DDR4_S_AXI_arsize),
        .C0_DDR4_S_AXI_arvalid(C0_DDR4_S_AXI_arvalid),
        .C0_DDR4_S_AXI_awaddr (C0_DDR4_S_AXI_awaddr),
        .C0_DDR4_S_AXI_awburst(C0_DDR4_S_AXI_awburst),
        .C0_DDR4_S_AXI_awcache(C0_DDR4_S_AXI_awcache),
        .C0_DDR4_S_AXI_awid   (C0_DDR4_S_AXI_awid),
        .C0_DDR4_S_AXI_awlen  (C0_DDR4_S_AXI_awlen),
        .C0_DDR4_S_AXI_awlock (C0_DDR4_S_AXI_awlock),
        .C0_DDR4_S_AXI_awprot (C0_DDR4_S_AXI_awprot),
        .C0_DDR4_S_AXI_awqos  (C0_DDR4_S_AXI_awqos),
        .C0_DDR4_S_AXI_awready(C0_DDR4_S_AXI_awready),
        .C0_DDR4_S_AXI_awsize (C0_DDR4_S_AXI_awsize),
        .C0_DDR4_S_AXI_awvalid(C0_DDR4_S_AXI_awvalid),
        .C0_DDR4_S_AXI_bid    (C0_DDR4_S_AXI_bid),
        .C0_DDR4_S_AXI_bready (C0_DDR4_S_AXI_bready),
        .C0_DDR4_S_AXI_bresp  (C0_DDR4_S_AXI_bresp),
        .C0_DDR4_S_AXI_bvalid (C0_DDR4_S_AXI_bvalid),
        .C0_DDR4_S_AXI_rdata  (C0_DDR4_S_AXI_rdata),
        .C0_DDR4_S_AXI_rid    (C0_DDR4_S_AXI_rid),
        .C0_DDR4_S_AXI_rlast  (C0_DDR4_S_AXI_rlast),
        .C0_DDR4_S_AXI_rready (C0_DDR4_S_AXI_rready),
        .C0_DDR4_S_AXI_rresp  (C0_DDR4_S_AXI_rresp),
        .C0_DDR4_S_AXI_rvalid (C0_DDR4_S_AXI_rvalid),
        .C0_DDR4_S_AXI_wdata  (C0_DDR4_S_AXI_wdata),
        .C0_DDR4_S_AXI_wlast  (C0_DDR4_S_AXI_wlast),
        .C0_DDR4_S_AXI_wready (C0_DDR4_S_AXI_wready),
        .C0_DDR4_S_AXI_wstrb  (C0_DDR4_S_AXI_wstrb),
        .C0_DDR4_S_AXI_wvalid (C0_DDR4_S_AXI_wvalid),

        .reset                  (rst_i),
        .addn_ui_clkout1        (),
        .c0_ddr4_aresetn        (),
        .c0_ddr4_ui_clk         (c0_ddr4_ui_clk),
        .c0_ddr4_ui_clk_sync_rst(c0_ddr4_ui_clk_sync_rst),
        .c0_init_calib_complete (c0_init_calib_complete),
        .c0_sys_clk_i           (clk_gen)
    );

`endif

`ifdef FPGA_AUP_ZU3
    xilinx_clk_wizard_wrapper xilinx_clk_wizard_wrapper_i (
        .CLK_IN1_D_0_clk_n(clk_100mhz_n),
        .CLK_IN1_D_0_clk_p(clk_100mhz_p),
        .clk_out1_0       (clk_gen)
    );
`else
    assign clk_gen = clk_i;
`endif

endmodule
