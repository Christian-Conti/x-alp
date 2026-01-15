module uart_subsystem (
    input logic clk_i,
    input logic rst_ni,

    // UART register interface
    output core_v_mcu_reg_pkg::reg_req_t  uart_reg_req,
    input  core_v_mcu_reg_pkg::reg_resp_t uart_reg_rsp,

    // UART IO
    input  logic uart_rx_i,
    output logic uart_tx_o,

    // UART Interrupts
    output logic uart_intr_tx_watermark_o,
    output logic uart_intr_rx_watermark_o,
    output logic uart_intr_tx_empty_o,
    output logic uart_intr_rx_overflow_o,
    output logic uart_intr_rx_frame_err_o,
    output logic uart_intr_rx_break_err_o,
    output logic uart_intr_rx_timeout_o,
    output logic uart_intr_rx_parity_err_o
);

    tlul_pkg::tl_h2d_t uart_tl_h2d;
    tlul_pkg::tl_d2h_t uart_tl_d2h;

  reg_to_tlul #(
      .req_t(core_v_mcu_reg_pkg::reg_req_t),
      .rsp_t(core_v_mcu_reg_pkg::reg_rsp_t),
      .tl_h2d_t(tlul_pkg::tl_h2d_t),
      .tl_d2h_t(tlul_pkg::tl_d2h_t),
      .tl_a_user_t(tlul_pkg::tl_a_user_t),
      .tl_a_op_e(tlul_pkg::tl_a_op_e),
      .TL_A_USER_DEFAULT(tlul_pkg::TL_A_USER_DEFAULT),
      .PutFullData(tlul_pkg::PutFullData),
      .Get(tlul_pkg::Get)
  ) reg_to_tlul_uart_i (
      .tl_o(uart_tl_h2d),
      .tl_i(uart_tl_d2h),
      .reg_req_i(uart_reg_req),
      .reg_rsp_o(uart_reg_rsp)
  );

  uart uart_i (
      .clk_i(clk_i),
      .rst_ni(rst_ni),
      .tl_i(uart_tl_h2d),
      .tl_o(uart_tl_d2h),
      .cio_rx_i(uart_rx_i),
      .cio_tx_o(uart_tx_o),
      .cio_tx_en_o(),
      .intr_tx_watermark_o(uart_intr_tx_watermark),
      .intr_rx_watermark_o(uart_intr_rx_watermark),
      .intr_tx_empty_o(uart_intr_tx_empty),
      .intr_rx_overflow_o(uart_intr_rx_overflow),
      .intr_rx_frame_err_o(uart_intr_rx_frame_err),
      .intr_rx_break_err_o(uart_intr_rx_break_err),
      .intr_rx_timeout_o(uart_intr_rx_timeout),
      .intr_rx_parity_err_o(uart_intr_rx_parity_err)
  );

endmodule
