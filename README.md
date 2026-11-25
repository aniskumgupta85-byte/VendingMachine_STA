# FPGA-Based Smart Vending Machine Controller

![Language](https://img.shields.io/badge/HDL-Verilog-blue.svg)
![EDA Tool](https://img.shields.io/badge/EDA-Xilinx%20Vivado-orange.svg)
![Verification](https://img.shields.io/badge/Testbench-10%2F10%20Passing-brightgreen.svg)
![Timing](https://img.shields.io/badge/STA-Timing%20Met%20(50%20MHz)-success.svg)

A synthesizable, glitch-free **Smart Vending Machine Controller** implemented in **Verilog HDL** and verified in **Xilinx Vivado**. The controller uses a 5-state one-hot Finite State Machine (FSM) to manage multi-denomination coin accumulation, per-item inventory tracking, exact change return, and mid-transaction cancellation.

---

## Table of Contents
- [Key Features](#key-features)
- [Repository Structure](#repository-structure)
- [Architecture & FSM Design](#architecture--fsm-design)
- [Module Interface & Parameters](#module-interface--parameters)
- [Verification & Self-Checking Testbench](#verification--self-checking-testbench)
- [Synthesis & Static Timing Analysis (STA)](#synthesis--static-timing-analysis-sta)
- [How to Run in Xilinx Vivado](#how-to-run-in-xilinx-vivado)

---

## Key Features
* **Multi-State One-Hot FSM:** Clean 3-always-block RTL architecture separating sequential state registers, combinational next-state logic, and registered datapath outputs (`S_IDLE`, `S_ACCUMULATE`, `S_CHECK_FUNDS`, `S_DISPENSE`, `S_RETURN`).
* **Glitch-Free Registered Outputs:** All control and actuator signals (`dispense`, `change_out`, `balance`, `out_of_stock`) are driven directly by clocked flip-flops to eliminate combinational switching glitches.
* **Dynamic Coin & Balance Management:** Accumulates multi-denomination inputs (`5` and `10` units) with 8-bit overflow protection and handles simultaneous coin insertion and item selection on the same clock cycle.
* **Per-Item Inventory Tracking:** Maintains independent stock counters for each item, automatically decrementing upon dispensing and asserting `out_of_stock` if an empty item is selected.
* **Exact Change & Refund Logic:** Computes exact excess change post-dispense and supports full balance refunds upon mid-transaction cancellation.
* **Self-Checking Verification & STA Closure:** Validated with an automated assertion-based testbench (`10 PASSED, 0 FAILED`) and closed timing in Xilinx Vivado with zero setup or hold violations.

---

## Repository Structure

```text
FPGA-Smart-Vending-Machine-Controller/
├── README.md
├── rtl/
│   └── vending_machine_controller.v   # Synthesizable 5-state FSM & datapath RTL
├── tb/
│   └── tb_vending_machine.v           # Automated self-checking Verilog testbench
├── constraints/
│   └── constraints.xdc                # Timing & I/O delay constraints (50 MHz)
└── docs/
    ├── vivado_schematic.png           # Synthesized/Implemented design schematic
    ├── simulation_results.png         # Waveform & Tcl console PASS/FAIL log
    └── timing_summary.png             # Vivado Design Timing Summary report
    Architecture & FSM Design
Hardware Design Choices
-> 3-Block FSM Partitioning: Separates sequential state registers (BLOCK 1), combinational next-state logic (BLOCK 2), and synchronous datapath/output registers (BLOCK 3) for clean synthesis and zero inferred latches.

->One-Hot State Encoding: Uses 5-bit one-hot encoding (5'b00001 – 5'b10000) to minimize next-state decoding LUT depth on flip-flop-rich FPGA architectures.

->Input Latching & Glitch-Free Outputs: Captures item_sel and decoded_price upon sel_valid so button releases do not corrupt active comparisons, while all external control/actuator outputs are registered on posedge clk to prevent combinational switching hazards.