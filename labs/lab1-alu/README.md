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
