# Copyright 2026 X-HEEP contibutors
#
# File: set_tcl_hooks.tcl
# Author: Christian Conti {christian.conti@polito.it}
# Date: 15/10/2026
#
# Sourced by FuseSoC/Edalize during project setup

set design_name xilinx_ddr4_ctrl_wizard

# Create block design
create_bd_design $design_name

# Create interface ports
set ddr4_sdram [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:ddr4_rtl:1.0 ddr4_sdram ]

set C0_DDR4_S_AXI [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 C0_DDR4_S_AXI ]
set_property -dict [ list \
  CONFIG.ADDR_WIDTH {32} \
  CONFIG.ARUSER_WIDTH {0} \
  CONFIG.AWUSER_WIDTH {0} \
  CONFIG.BUSER_WIDTH {0} \
  CONFIG.DATA_WIDTH {512} \
  CONFIG.HAS_BRESP {1} \
  CONFIG.HAS_BURST {1} \
  CONFIG.HAS_CACHE {1} \
  CONFIG.HAS_LOCK {1} \
  CONFIG.HAS_PROT {1} \
  CONFIG.HAS_QOS {1} \
  CONFIG.HAS_REGION {0} \
  CONFIG.HAS_RRESP {1} \
  CONFIG.HAS_WSTRB {1} \
  CONFIG.ID_WIDTH {4} \
  CONFIG.MAX_BURST_LENGTH {256} \
  CONFIG.NUM_READ_OUTSTANDING {2} \
  CONFIG.NUM_READ_THREADS {1} \
  CONFIG.NUM_WRITE_OUTSTANDING {2} \
  CONFIG.NUM_WRITE_THREADS {1} \
  CONFIG.PROTOCOL {AXI4} \
  CONFIG.READ_WRITE_MODE {READ_WRITE} \
  CONFIG.RUSER_BITS_PER_BYTE {0} \
  CONFIG.RUSER_WIDTH {0} \
  CONFIG.SUPPORTS_NARROW_BURST {1} \
  CONFIG.WUSER_BITS_PER_BYTE {0} \
  CONFIG.WUSER_WIDTH {0} \
  ] $C0_DDR4_S_AXI

# Create ports
set reset [ create_bd_port -dir I -type rst reset ]
set_property -dict [ list \
  CONFIG.POLARITY {ACTIVE_HIGH} \
] $reset
set addn_ui_clkout1 [ create_bd_port -dir O -type clk addn_ui_clkout1 ]
set c0_ddr4_aresetn [ create_bd_port -dir I -type rst c0_ddr4_aresetn ]
set c0_ddr4_ui_clk [ create_bd_port -dir O -type clk c0_ddr4_ui_clk ]
set_property -dict [ list \
  CONFIG.ASSOCIATED_BUSIF {C0_DDR4_S_AXI} \
] $c0_ddr4_ui_clk
set_property CONFIG.ASSOCIATED_BUSIF.VALUE_SRC DEFAULT $c0_ddr4_ui_clk

set c0_ddr4_ui_clk_sync_rst [ create_bd_port -dir O -type rst c0_ddr4_ui_clk_sync_rst ]
set c0_init_calib_complete [ create_bd_port -dir O c0_init_calib_complete ]
set c0_sys_clk_i [ create_bd_port -dir I -type clk c0_sys_clk_i ]

# Create instance: ddr4_0, and set properties
set ddr4_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:ddr4:2.2 ddr4_0 ]
set_property -dict [list \
  CONFIG.ADDN_UI_CLKOUT1_FREQ_HZ {100} \
  CONFIG.C0.BANK_GROUP_WIDTH {2} \
  CONFIG.C0.DDR4_AxiAddressWidth {32} \
  CONFIG.C0.DDR4_AxiIDWidth {4} \
  CONFIG.C0_DDR4_BOARD_INTERFACE {ddr4_sdram} \
  CONFIG.RESET_BOARD_INTERFACE {reset} \
  CONFIG.System_Clock {No_Buffer} \
] $ddr4_0

# Create interface connections
connect_bd_intf_net -intf_net C0_DDR4_S_AXI_0_1 [get_bd_intf_ports C0_DDR4_S_AXI] [get_bd_intf_pins ddr4_0/C0_DDR4_S_AXI]
connect_bd_intf_net -intf_net ddr4_0_C0_DDR4 [get_bd_intf_ports ddr4_sdram] [get_bd_intf_pins ddr4_0/C0_DDR4]

# Create port connections
connect_bd_net -net c0_ddr4_aresetn_0_1  [get_bd_ports c0_ddr4_aresetn] \
[get_bd_pins ddr4_0/c0_ddr4_aresetn]
connect_bd_net -net c0_sys_clk_i_0_1  [get_bd_ports c0_sys_clk_i] \
[get_bd_pins ddr4_0/c0_sys_clk_i]
connect_bd_net -net ddr4_0_addn_ui_clkout1  [get_bd_pins ddr4_0/addn_ui_clkout1] \
[get_bd_ports addn_ui_clkout1]
connect_bd_net -net ddr4_0_c0_ddr4_ui_clk  [get_bd_pins ddr4_0/c0_ddr4_ui_clk] \
[get_bd_ports c0_ddr4_ui_clk]
connect_bd_net -net ddr4_0_c0_ddr4_ui_clk_sync_rst  [get_bd_pins ddr4_0/c0_ddr4_ui_clk_sync_rst] \
[get_bd_ports c0_ddr4_ui_clk_sync_rst]
connect_bd_net -net ddr4_0_c0_init_calib_complete  [get_bd_pins ddr4_0/c0_init_calib_complete] \
[get_bd_ports c0_init_calib_complete]
connect_bd_net -net reset_1  [get_bd_ports reset] \
[get_bd_pins ddr4_0/sys_rst]

# Create address segments

# Save and close block design
save_bd_design
close_bd_design $design_name

# Create wrapper
set wrapper_path [ make_wrapper -fileset sources_1 -files [ get_files -norecurse xilinx_ddr4_ctrl_wizard.bd ] -top ]
add_files -norecurse -fileset sources_1 $wrapper_path
