## Testing my ALU implementation

### How to run

From inside the Docker container (or with pyverilator installed locally):

\`\`\`bash
cd alu/
make
\`\`\`

This compiles `alu.sv` with Verilator and runs `testbench.py`, which checks
`result` and `result_eq_zero` against a Python reference model for every
`alu_function`.

### What's covered

- **Lab Question 1** (result_eq_zero): verified across ADD/SUB/XOR/AND cases
  where the result is exactly zero, plus non-zero cases.
- **Lab Question 2** (ADD, SUB, XOR, OR, AND): basic cases plus overflow/
  underflow edge cases (e.g. 0x7FFFFFFF + 1, 0x80000000 - 1).
- **Lab Question 3** (SLL, SRL, SRA, SLT, SLTU):
  - Shift amount masking: verified `op_b[4:0]` is used correctly by testing
    shift amounts of 31, 32, 33, 64, and 0xFFFFFFFF (all should behave as
    shift-by-(b & 0x1f)).
  - SRA vs SRL sign-preservation: tested with negative numbers
    (0xFFFFFFFF, 0x80000000, 0xAAAAAAAA) to confirm SRA fills with the sign
    bit while SRL fills with zero.
  - SLT vs SLTU: tested signed/unsigned boundary cases (0xFFFFFFFF vs 1,
    0x7FFFFFFF vs 0x80000000) to confirm signed and unsigned comparisons
    diverge correctly.

### Result

All N test cases pass. [pega aquí el output final de `make`, o cuenta
cuántos `True`/`False` salieron]
