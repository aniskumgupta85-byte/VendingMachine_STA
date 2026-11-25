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
    └── timing_summary.png         # Vivado Design Timing Summary report
```
## Architecture & FSM Design

### Hardware Design Choices
* **3-Block FSM Partitioning:** Separates sequential state registers (BLOCK 1), combinational next-state logic (BLOCK 2), and synchronous datapath/output registers (BLOCK 3) for clean synthesis and zero inferred latches.
* **One-Hot State Encoding:** Uses 5-bit one-hot encoding (`5'b00001` – `5'b10000`) to minimize next-state decoding LUT depth on flip-flop-rich FPGA architectures.
* **Input Latching & Glitch-Free Outputs:** Captures `item_sel` and `decoded_price` upon `sel_valid` so button releases do not corrupt active comparisons, while all external control/actuator outputs are registered on `posedge clk` to prevent combinational switching hazards.
### State Descriptions
1. **`S_IDLE` (`5'b00001`):** Default reset state. Waits for a valid coin strobe (`coin_valid`) or item selection strobe (`sel_valid`), clearing previous change and status flags when a new transaction begins.
2. **`S_ACCUMULATE` (`5'b00010`):** Adds incoming coin values (5 or 10 units) to the running balance register (with 8-bit overflow protection) while monitoring `sel_valid` or `cancel_btn`.
3. **`S_CHECK_FUNDS` (`5'b00100`):** Evaluates stock availability (`stock[latched_item] > 0`) and compares effective balance against `latched_price`. Routes to `S_DISPENSE` if valid, or returns to `S_ACCUMULATE`/`S_IDLE` if funds are insufficient or the item is out of stock.
4. **`S_DISPENSE` (`5'b01000`):** Pulses the one-hot dispense actuator for the selected item, deducts `latched_price` from `balance`, and decrements the item's inventory counter.
5. **`S_RETURN` (`5'b10000`):** Transfers any remaining balance (excess change or cancelled refund) to `change_out`, resets `balance` to `0`, and returns to `S_IDLE`.
### State Transition Diagram

```text
[ S_IDLE ] ──(coin_valid)──> [ S_ACCUMULATE ] <──(insufficient / out_of_stock)──┐
     │                              │                                            │
 (sel_valid)               (sel_valid) / (cancel_btn)                            │
     │                        │               │                                  │
     └──────────────> [ S_CHECK_FUNDS ]       │                                  │
                              │               │                                  │
                    (in_stock & bal >= price) │                                  │
                              │               │                                  │
                              v               │                                  │
                       [ S_DISPENSE ]         │                                  │
                              │               │                                  │
                              v               v                                  │
                       [ S_RETURN ] <─────────┘                                  │
                              │                                                  │
                              └────────────────────> [ S_IDLE ] ─────────────────┘
```
## Module Interface & Parameters

### Configurable Parameters

| Parameter | Default Value | Description |
| :--- | :--- | :--- |
| `PRICE_A` | `8'd10` | Price of Item A (`item_sel = 2'b00`) |
| `PRICE_B` | `8'd15` | Price of Item B (`item_sel = 2'b01`) |
| `PRICE_C` | `8'd20` | Price of Item C (`item_sel = 2'b10`) |
| `INIT_STOCK` | `4'd5` | Initial stock quantity per item on reset |

### Port Specification

| Port Name | Direction | Width | Description |
| :--- | :--- | :--- | :--- |
| `clk` | Input | 1-bit | System clock (50 MHz / 20.000 ns period) |
| `rst_n` | Input | 1-bit | Active-low asynchronous reset |
| `coin_in` | Input | 2-bit | Coin denomination encoding (`2'b01` = 5 units, `2'b10` = 10 units) |
| `coin_valid` | Input | 1-bit | Clean 1-cycle strobe indicating coin insertion |
| `item_sel` | Input | 2-bit | Item selection (`2'b00`: A, `2'b01`: B, `2'b10`: C) |
| `sel_valid` | Input | 1-bit | Clean 1-cycle strobe indicating item selection |
| `cancel_btn` | Input | 1-bit | Clean 1-cycle strobe to abort transaction and refund balance |
| `dispense` | Output | 3-bit | Registered one-hot dispense actuator signals (`[0]`: A, `[1]`: B, `[2]`: C) |
| `change_out` | Output | 8-bit | Registered exact change or refund amount |
| `balance` | Output | 8-bit | Registered live accumulated credit |
| `out_of_stock` | Output | 1-bit | Registered flag asserted when selected item inventory is 0 |

---

## Verification & Self-Checking Testbench

The self-checking testbench (`tb/tb_vending_machine.v`) drives stimulus tasks and automatically compares actual outputs against expected values across 10 assertion checkpoints, achieving **10 PASSED, 0 FAILED**:

| Test Case | Scenario Tested | Expected Behavior | Result |
| :--- | :--- | :--- | :--- |
| **Test 1a / 1b** | Exact Payment (10 + 5 for Item B) | `dispense = 3'b010`, `change_out = 0`, `balance = 0` | PASS |
| **Test 2a / 2b** | Overpayment (10 + 10 for Item A) | `dispense = 3'b001`, `change_out = 10` returned in `S_RETURN` | PASS |
| **Test 3a / 3b** | Insufficient Funds & Top-Up (10 then +10 for Item C) | Holds `balance = 10` until topped up, then dispenses `3'b100` | PASS |
| **Test 4** | Mid-Transaction Cancellation (10 + 5 + `cancel_btn`) | Aborts dispense and refunds `change_out = 15` | PASS |
| **Test 5** | Simultaneous Coin + Selection | Captures 10 units and Item A on the same clock edge and dispenses | PASS |
| **Test 6a / 6b** | Out-of-Stock Detection & Refund | Asserts `out_of_stock = 1` when stock hits 0, then refunds 10 on cancel | PASS |

---

## Synthesis & Static Timing Analysis (STA)

Synthesized and implemented in Xilinx Vivado using `constraints/constraints.xdc` with a 50 MHz (20.000 ns period) primary clock, 2.000 ns max input/output delay, and 0.500 ns min input/output delay:

| Timing Metric | Slack / Value | Failing Endpoints | Total Endpoints | Status |
| :--- | :--- | :--- | :--- | :--- |
| **Worst Negative Slack (WNS - Setup)** | +7.913 ns | 0 | 146 | MET |
| **Total Negative Slack (TNS)** | 0.000 ns | 0 | 146 | MET |
| **Worst Hold Slack (WHS - Hold)** | +0.150 ns | 0 | 146 | MET |
| **Total Hold Slack (THS)** | 0.000 ns | 0 | 146 | MET |
| **Worst Pulse Width Slack (WPWS)** | +9.500 ns | 0 | 43 | MET |

---

## How to Run in Xilinx Vivado

1. **Create Project:** Open Xilinx Vivado and create a new RTL project targeting your FPGA device (e.g., Artix-7).
2. **Add Sources:**
   * Add `rtl/vending_machine_controller.v` under **Design Sources** and set it as the Top Module for synthesis.
   * Add `tb/tb_vending_machine.v` under **Simulation Sources** and set it as the Top Module for simulation.
   * Add `constraints/constraints.xdc` under **Constraints**.
3. **Run Behavioral Simulation:** Click **Run Simulation → Run Behavioral Simulation** to execute all 10 automated checks and inspect the Tcl Console output (`10 PASSED, 0 FAILED`).
4. **Run Synthesis & Implementation:** Click **Run Synthesis**, then **Run Implementation**, and open **Report Timing Summary** to verify zero setup and hold timing violations at 50 MHz.