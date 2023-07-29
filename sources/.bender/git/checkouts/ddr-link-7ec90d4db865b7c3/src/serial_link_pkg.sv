// Copyright 2020 ETH Zurich
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Fabian Schuiki <fschuiki@iis.ee.ethz.ch>
// Florian Zaruba <zarubaf@iis.ee.ethz.ch>
// Stefan Mach <smach@iis.ee.ethz.ch>
// Thomas Benz <tbenz@iis.ee.ethz.ch>
// Paul Scheffler <paulsc@iis.ee.ethz.ch>
// Wolfgang Roenninger <wroennin@iis.ee.ethz.ch>

/// A simple serial link package
package serial_link_pkg;

  typedef enum logic [31:0] {
    SerialCfgStatus       = 32'h000,
    SerialCfgTrainingMask = 32'h008,
    SerialCfgDelay        = 32'h010
  } serial_cfg_addr_e;

endpackage : serial_link_pkg
