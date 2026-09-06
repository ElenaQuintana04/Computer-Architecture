# RV32I Single-Cycle Processor Core (`rv3608c.sv`)

An enhanced SystemVerilog implementation of an RV32I single-cycle processor featuring full data memory integration, S-type immediate decoding, and support for Load (`lw`) and Store (`sw`) instructions.

---

## Overview

This repository extends a basic RV32I core to support memory access and stack-based program execution. The hardware updates enable the processor to calculate effective memory addresses, read/write to data memory, forward loaded data back to the register file, and manage recursive function calls via the stack pointer (`sp`).

---

## Architectural Enhancements

* **S-Type Immediate Decoder:** Decodes and sign-extends 12-bit store offsets (`imm_s_sext`) from instruction fields `insn[31:25]` and `insn[11:7]`.
* **Data Memory Subsystem:** Integrates a memory unit tied to the ALU output (`alu_result`) for effective address calculation.
* **Write-Back Multiplexer (`WBSel`):** Adds a memory data forwarding path to write loaded values directly into destination registers (`rd`).
* **Stack Pointer Management:** Enables full stack frame manipulation (`sw`/`lw` of `ra`, `s0-s2`) for nested and recursive subroutines.

---

## Datapath & Control Signal Summary

| Instruction | Op2Sel | AluFunc | WBSel | RegWriteEn | MemWrite | PCSel |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **R-Type** | `RS2` | Decoded | `ALU` | True | False | `PC+4` |
| **I-Type (Arith)** | `IMI` | Decoded | `ALU` | True | False | `PC+4` |
| **LW** | `IMI` | `ADD` | `MemData` | True | False | `PC+4` |
| **SW** | `IMS` | `ADD` | `X` | False | True | `PC+4` |
| **Branches** | `IMB` | `SUB` / `SLT` | `X` | False | False | `PC+4` / `Br` |
| **JAL / JALR** | `IMJ` / `IMI` | `X` | `PC+4` | True | False | Target Address |

---

## Prerequisites

To compile and simulate the processor, ensure you have the following installed:

* **RISC-V Toolchain:** `riscv64-unknown-elf-gcc` (configured for `-march=rv32i -mabi=ilp32`)
* **Simulator:** `verilator` (v4.0+)
* **Python Environment:** `python3` with `pyverilator`

---

## Build & Run

### 1. Basic Memory Test (`test1.s`)
Validates single-word store (`sw 0xd0, 0(sp)`) and load (`lw x10, 4(sp)`) operations.

```bash
make
