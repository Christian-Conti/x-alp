// Copyright 2026 X-HEEP Contributors
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Top-level module for the X-ALP SoC FPGA wrapper.
// Author: Christian Conti, Luigi Giuffrida <{christian.conti, luigi.giuffrida}@polito.it>

module xilinx_core_v_mcu_wrapper #(
  parameter CLK_LED_COUNT_LENGTH = 27
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
  inout  wire  [63:0] ddr4_sdram_dq,
  inout  wire  [ 7:0] ddr4_sdram_dqs_c,
  inout  wire  [ 7:0] ddr4_sdram_dqs_t,
  output logic        ddr4_sdram_odt,
  output logic        ddr4_sdram_reset_n,
`else
  input logic clk_i,
`endif

  inout logic rst_i,

  output logic rst_led_o,
  output logic clk_led_o,

  inout logic jtag_tck_i,
  inout logic jtag_tms_i,
  inout logic jtag_trst_ni,
  inout logic jtag_tdi_i,
  inout logic jtag_tdo_o,

  inout logic uart_rx_i,
  inout logic uart_tx_o,

  output logic exit_value_o,
  inout logic exit_valid_o
);

  import core_v_mcu_pkg::*;

  wire                               clk_gen;
  wire                               rst_n;
  logic [                      31:0] exit_value;
  logic [CLK_LED_COUNT_LENGTH - 1:0] clk_count;

  axi_mst_req_t llc_req;
  axi_mst_rsp_t llc_rsp;
  axi_mst_rsp_t ext_mst_rsp_unused;

  // Active-low SoC and AXI reset; active-high DDR controller reset.
  assign rst_n     = !rst_i;
  assign rst_led_o = rst_n;
  assign clk_led_o = clk_count[CLK_LED_COUNT_LENGTH-1];

  always_ff @(posedge clk_gen or negedge rst_n) begin : clk_count_process
    if (!rst_n) begin
      clk_count <= '0;
    end else begin
      clk_count <= clk_count + 1'b1;
    end
  end

`ifdef FPGA_ZCU104
  xilinx_clk_wizard_wrapper xilinx_clk_wizard_wrapper_i (
    .CLK_IN1_D_0_clk_n(clk_300mhz_n),
    .CLK_IN1_D_0_clk_p(clk_300mhz_p),
    .clk_out1_0       (clk_gen)
  );
`elsif FPGA_AUP_ZU3
  xilinx_clk_wizard_wrapper xilinx_clk_wizard_wrapper_i (
    .CLK_IN1_D_0_clk_n(clk_100mhz_n),
    .CLK_IN1_D_0_clk_p(clk_100mhz_p),
    .clk_out1_0       (clk_gen)
  );
`else
  assign clk_gen = clk_i;
`endif

  x_alp x_alp_system_i (
    .clk_i        (clk_gen),
    .rst_ni       (rst_n),
    .jtag_tck_i   (jtag_tck_i),
    .jtag_tms_i   (jtag_tms_i),
    .jtag_trst_ni (jtag_trst_ni),
    .jtag_tdi_i   (jtag_tdi_i),
    .jtag_tdo_o   (jtag_tdo_o),
    .jtag_tdo_oe_o(),
    .uart_rx_i    (uart_rx_i),
    .uart_tx_o    (uart_tx_o),
    .exit_valid_o (exit_valid_o),
    .exit_value_o (exit_value),
    .ext_slv_req_o(),
    .ext_slv_rsp_i('0),
    .ext_mst_req_i('0),
    .ext_mst_rsp_o(ext_mst_rsp_unused),
    .ext_llc_req_o(llc_req),
    .ext_llc_rsp_i(llc_rsp),
    .ext_reg_req_o(),
    .ext_reg_rsp_i('0),
    .test_mode_i  (1'b0)
  );

  assign exit_value_o = exit_value[0];

`ifdef FPGA_ZCU104
  localparam int unsigned DDR_AXI_ADDR_WIDTH = 32;

  // The DDR AXI slave exposes no transaction ID signals.
  // Allow one outstanding read and one outstanding write to preserve IDs.
  logic                     wr_pending;
  logic                     rd_pending;
  logic [AxiMstIdWidth-1:0] wr_id;
  logic [AxiMstIdWidth-1:0] rd_id;

  logic                     ddr_awready;
  logic                     ddr_wready;
  logic [              1:0] ddr_bresp;
  logic                     ddr_bvalid;
  logic                     ddr_arready;
  logic [AxiDataWidth-1:0] ddr_rdata;
  logic [              1:0] ddr_rresp;
  logic                     ddr_rlast;
  logic                     ddr_rvalid;

  always_ff @(posedge clk_gen or negedge rst_n) begin : axi_id_process
    if (!rst_n) begin
      wr_pending <= 1'b0;
      rd_pending <= 1'b0;
      wr_id      <= '0;
      rd_id      <= '0;
    end else begin
      if (llc_req.aw_valid && llc_rsp.aw_ready) begin
        wr_pending <= 1'b1;
        wr_id      <= llc_req.aw.id;
      end else if (llc_rsp.b_valid && llc_req.b_ready) begin
        wr_pending <= 1'b0;
      end

      if (llc_req.ar_valid && llc_rsp.ar_ready) begin
        rd_pending <= 1'b1;
        rd_id      <= llc_req.ar.id;
      end else if (llc_rsp.r_valid && llc_req.r_ready && llc_rsp.r.last) begin
        rd_pending <= 1'b0;
      end
    end
  end

  always_comb begin
    llc_rsp          = '0;
    llc_rsp.aw_ready = ddr_awready && !wr_pending;
    llc_rsp.w_ready  = ddr_wready && wr_pending;
    llc_rsp.b_valid  = ddr_bvalid && wr_pending;
    llc_rsp.b.id     = wr_id;
    llc_rsp.b.resp   = ddr_bresp;
    llc_rsp.ar_ready = ddr_arready && !rd_pending;
    llc_rsp.r_valid  = ddr_rvalid && rd_pending;
    llc_rsp.r.id     = rd_id;
    llc_rsp.r.data   = ddr_rdata;
    llc_rsp.r.resp   = ddr_rresp;
    llc_rsp.r.last   = ddr_rlast;
  end

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

    // Route the board's raw 300 MHz reference clock to the MIG.
    // Keep the Clock Wizard output on the SoC/AXI side only.
    .c0_sys_clk_p      (clk_300mhz_p),
    .c0_sys_clk_n      (clk_300mhz_n),

    .S_AXI_awaddr  (llc_req.aw.addr[DDR_AXI_ADDR_WIDTH-1:0]),
    .S_AXI_awlen   (llc_req.aw.len),
    .S_AXI_awsize  (llc_req.aw.size),
    .S_AXI_awburst (llc_req.aw.burst),
    .S_AXI_awlock  (llc_req.aw.lock),
    .S_AXI_awcache (llc_req.aw.cache),
    .S_AXI_awprot  (llc_req.aw.prot),
    .S_AXI_awregion(llc_req.aw.region),
    .S_AXI_awqos   (llc_req.aw.qos),
    .S_AXI_awvalid (llc_req.aw_valid && !wr_pending),
    .S_AXI_awready (ddr_awready),

    .S_AXI_wdata   (llc_req.w.data),
    .S_AXI_wstrb   (llc_req.w.strb),
    .S_AXI_wlast   (llc_req.w.last),
    .S_AXI_wvalid  (llc_req.w_valid && wr_pending),
    .S_AXI_wready  (ddr_wready),

    .S_AXI_bresp   (ddr_bresp),
    .S_AXI_bvalid  (ddr_bvalid),
    .S_AXI_bready  (llc_req.b_ready && wr_pending),

    .S_AXI_araddr  (llc_req.ar.addr[DDR_AXI_ADDR_WIDTH-1:0]),
    .S_AXI_arlen   (llc_req.ar.len),
    .S_AXI_arsize  (llc_req.ar.size),
    .S_AXI_arburst (llc_req.ar.burst),
    .S_AXI_arlock  (llc_req.ar.lock),
    .S_AXI_arcache (llc_req.ar.cache),
    .S_AXI_arprot  (llc_req.ar.prot),
    .S_AXI_arregion(llc_req.ar.region),
    .S_AXI_arqos   (llc_req.ar.qos),
    .S_AXI_arvalid (llc_req.ar_valid && !rd_pending),
    .S_AXI_arready (ddr_arready),

    .S_AXI_rdata   (ddr_rdata),
    .S_AXI_rresp   (ddr_rresp),
    .S_AXI_rlast   (ddr_rlast),
    .S_AXI_rvalid  (ddr_rvalid),
    .S_AXI_rready  (llc_req.r_ready && rd_pending),

    .s_axi_aclk    (clk_gen),
    .s_axi_aresetn (rst_n),
    .sys_rst       (rst_i)
  );
`else
  assign llc_rsp = '0;
`endif

endmodule
