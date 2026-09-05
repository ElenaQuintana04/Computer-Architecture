# Single-Cycle RV32I Processor in SystemVerilog

A single-cycle RISC-V (RV32I) processor implementation supporting R-type
and I-type instructions, with trap detection for `ebreak`. Written in
SystemVerilog and verified with Verilator + pyverilator.

## What it does

The processor (`rv3608a.sv`) reads a precompiled RISC-V assembly program
(`firmware.s` → `firmware.hex`), executes it instruction by instruction, and
exposes the contents of register `x10` through the `return_reg` port —
useful for automatically verifying that the final result is correct without
manually inspecting the register file.

Supported instructions:
- **R-type**: ADD, SUB, SLL, SLT, SLTU, XOR, SRL, SRA, OR, AND
- **I-type**: ADDI, SLLI, SLTI, SLTIU, XORI, SRLI, SRAI, ORI, ANDI
- **SYSTEM**: `ebreak` (triggers a trap and halts the simulation)

The design also respects the RISC-V convention that `x0` is a fixed constant
equal to 0, regardless of what is written to it.

## Requirements

- Docker
- An X11 display on the host, needed to view waveforms in GTKWave:
  - **Linux**: native X11, usually requires no extra setup.
  - **macOS**: [XQuartz](https://www.xquartz.org/). After installing it, go
    to **XQuartz → Settings → Security** and enable *"Allow connections from
    network clients"*, then restart XQuartz for the change to take effect.

## How to run it

1. Clone the repository and enter the project folder:
   ```bash
   git clone <your-fork-url>
   cd <project-folder>
   ```

2. **On macOS**, before launching Docker, authorize the graphical connection
   from a terminal on your Mac (outside Docker):
   ```bash
   xhost + 127.0.0.1
   ```
   You'll need to repeat this every time you restart XQuartz or your Mac.

3. Launch the Docker container from the project folder:
   ```bash
   docker run --platform linux/amd64 -it -e DISPLAY=host.docker.internal:0 -v `pwd`:/config phwl/elec3608-base:latest
   ```
   > On Linux, replace `host.docker.internal:0` with `$DISPLAY`.

4. Inside the container, check that the graphical connection works:
   ```bash
   xeyes
   ```
   If a window with a pair of eyes tracking your cursor opens, you're good
   to go. Close it and continue.

5. Build and run the simulation:
   ```bash
   make
   ```

## What to expect

The terminal will print the value of `pc` on every cycle, as the processor
advances instruction by instruction:
```
pc = 0x00000000
pc = 0x00000004
...
pc = 0x00000024
```

Upon reaching the `ebreak` instruction, the processor asserts the `trapped`
signal and the simulation halts automatically:
```
Simulated 12 cycles
- testbench.sv:82: Verilog $finish
```

A **GTKWave** window will also open, showing waveforms for all internal
signals (`clock`, `reset`, `alu_op`, `pc`, `return_reg`, etc.), where the
full execution of the program can be visually verified.

**Expected result:** at the end of the simulation, `return_reg` should hold
the value `0xE1EC3608` — the result of the test program after all 10
instructions have executed.

## Project structure

```
.
├── constants.svh      # Opcode, funct3/funct7, and ALU function code definitions
├── rv3608a.sv         # The processor (top-level module)
├── testbench.sv       # Testbench: instruction memory + processor instantiation
├── testbench.py       # Python testbench (pyverilator) that drives the simulation
├── firmware.s         # RISC-V assembly test program
├── firmware.hex       # Compiled program (generated from firmware.s)
└── Makefile           # Automates building with Verilator and running the testbench
```

## Design decisions

- **`illegalinsn` as a centralized signal**: any unrecognized combination of
  opcode/funct3/funct7 (including SYSTEM instructions like `ebreak`) asserts
  `illegalinsn`, which in turn triggers `trapped` on the next clock edge.
  This avoids duplicating the "halt execution" logic in multiple places.
- **Default value for `alu_op` before the `case`**: to avoid accidentally
  inferring latches in the decoder's combinational logic, `alu_op` is given
  a default value (`ALU_ADD`) before entering the `case`, so that no
  execution path leaves it unassigned.
- **`x0` protection**: the destination register is explicitly checked to
  make sure it isn't `x0` before writing to the register file, respecting
  the RISC-V convention that `x0` is a read-only constant.
