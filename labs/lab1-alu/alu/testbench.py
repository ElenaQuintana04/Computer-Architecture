import pyverilator
from ctypes import c_int32, c_uint32

ALU_ADD = 1
ALU_SUB = 2
ALU_XOR = 9
ALU_OR = 10
ALU_AND = 11
ALU_SLL = 3
ALU_SRL = 4
ALU_SRA = 5
ALU_SLT = 7
ALU_SLTU = 8

ALUSYM = { ALU_ADD: '+', ALU_SUB: '-', ALU_XOR: '^', ALU_OR: '|', ALU_AND: '&', 
          ALU_SLL: '<<', ALU_SRL: '>>', ALU_SRA: '>>>', ALU_SLT: 'SLT', ALU_SLTU: 'SLTU'}

def uint32(v):
    return c_uint32(v).value

# This is the function we are trying to emulate in our system verilog 
def alu(alu_function, a, b):
    if alu_function == ALU_ADD:
        r = a + b
    elif alu_function == ALU_SUB:   
        r = a - b
    elif alu_function == ALU_XOR:
        r = a ^ b
    elif alu_function == ALU_OR:
        r = a | b
    elif alu_function == ALU_AND:
        r = a & b
    elif alu_function == ALU_SLL:
        r = a << (b & 0x1f)
    elif alu_function == ALU_SRL:
        r = uint32(a) >> (b & 0x1f)
    elif alu_function == ALU_SRA:
        r = c_int32(a).value >> (b & 0x1f)  
    elif alu_function == ALU_SLT:
        r = 1 if c_int32(a).value < c_int32(b).value else 0
    elif alu_function == ALU_SLTU:
        r = 1 if uint32(a) < uint32(b) else 0
    else:
        r = 0
    r = uint32(r)
    zero = 1 if (r == 0) else 0
    return (r, zero)

def test_alu(tb, alu_function, a, b):
    tb.io.alu_function = alu_function
    tb.io.op_a = a
    tb.io.op_b = b

    (cresult, ceq) = alu(alu_function, a, b)     # computer result
    vresult = uint32(tb.io.result)                  # verilog result
    veq = uint32(tb.io.result_eq_zero)
    ok = cresult == vresult and ceq == veq
    print("{:08x} {} {:08x}\tresult={:08x},{} (cresult={:08x},{}) {}".\
            format(a, ALUSYM[alu_function], b, vresult, veq, cresult, ceq, ok));
    return ok

tb = pyverilator.PyVerilator.build('alu.sv')
ok = test_alu(tb, ALU_ADD, 1, 2); 
ok = test_alu(tb, ALU_ADD, 0xffffffff, 2); 
ok = test_alu(tb, ALU_ADD, 0x7fffffff, 0xFF); 
ok = test_alu(tb, ALU_SUB, 0xdeadbeef, 0xdeadbeef); 
ok = test_alu(tb, ALU_SUB, 0xdeadbeef, 2); 
ok = test_alu(tb, ALU_SUB, 0xe1e10, 0xdeadbeef);
ok = test_alu(tb, ALU_XOR, 0xAAAAAAAA, 0x55555555)
ok = test_alu(tb, ALU_OR,  0xAAAAAAAA, 0x55555555)
ok = test_alu(tb, ALU_AND, 0xAAAAAAAA, 0x55555555)
print("\n--- ADD Edge Cases ---")

# overflow
ok = test_alu(tb, ALU_ADD, 0xFFFFFFFF, 1)
# underflow
ok = test_alu(tb, ALU_SUB, 0, 1)
# result zero
ok = test_alu(tb, ALU_SUB, 0xAAAAAAAA, 0xAAAAAAAA)
# largest positive signed + 1
ok = test_alu(tb, ALU_ADD, 0x7FFFFFFF, 1)
# minimum signed minus 1
ok = test_alu(tb, ALU_SUB, 0x80000000, 1)
# zero + zero
ok = test_alu(tb, ALU_ADD, 0, 0)
# random
ok = test_alu(tb, ALU_ADD, 0x04332648, 0xACED1357)
# XOR to zero
ok = test_alu(tb, ALU_XOR, 0xAAAAAAAA, 0xAAAAAAAA)
# AND to zero
ok = test_alu(tb, ALU_AND, 0xFFFFFFFF, 0)
# OR all ones
ok = test_alu(tb, ALU_OR, 0xFFFFFFFF, 0)
# XOR all ones
ok = test_alu(tb, ALU_XOR, 0xAAAAAAAA, 0x55555555)
# SLL by 0
ok = test_alu(tb, ALU_SLL, 0x12345678, 0)
# SLL by 31 or more (verify op_b[4:0])
ok = test_alu(tb, ALU_SLL, 1, 31)
ok = test_alu(tb, ALU_SLL, 1, 33)
ok = test_alu(tb, ALU_SLL, 1, 64)
# SRL by 0
ok = test_alu(tb, ALU_SRL, 0x44444444, 0)
# SRL by 31 or more (verify op_b[4:0])
ok = test_alu(tb, ALU_SRL, 0x80000000, 31)
ok = test_alu(tb, ALU_SRL, 0x80000000, 32)
ok = test_alu(tb, ALU_SRL, 0x80000000, 33)
# example from spec
ok = test_alu(tb, ALU_SRA, 0xFFFFFFFF, 2)
# preserve sign
ok = test_alu(tb, ALU_SRA, 0x80000000, 1)
ok = test_alu(tb, ALU_SRA, 0x80000000, 31)
# all ones stay
ok = test_alu(tb, ALU_SRA, 0xFFFFFFFF, 31)
# compare with + value
ok = test_alu(tb, ALU_SRA, 0x7FFFFFFF, 4)

# examples
ok = test_alu(tb, ALU_SLT, 0xFFFFFFFF, 1)
ok = test_alu(tb, ALU_SLTU, 0xFFFFFFFF, 1)
# most negative number
ok = test_alu(tb, ALU_SLT, 0x80000000, 0)
ok = test_alu(tb, ALU_SLTU, 0x80000000, 0)
# equal numbers
ok = test_alu(tb, ALU_SLT, 5, 5)
ok = test_alu(tb, ALU_SLTU, 5, 5)
# normal less-than
ok = test_alu(tb, ALU_SLT, 1, 2)
ok = test_alu(tb, ALU_SLTU, 1, 2)
# normal greater-than
ok = test_alu(tb, ALU_SLT, 2, 1)
ok = test_alu(tb, ALU_SLTU, 2, 1)
# zero flag
ok = test_alu(tb, ALU_ADD, 0, 0)
ok = test_alu(tb, ALU_SUB, 12345, 12345)
ok = test_alu(tb, ALU_XOR, 0xCAFFE444, 0xCAFFE444)
ok = test_alu(tb, ALU_AND, 0, 0xFFFFFFFF)
# every bit set alternating
ok = test_alu(tb, ALU_SLT, 0xAAAAAAAA, 0x55555555)
ok = test_alu(tb, ALU_SLTU, 0xAAAAAAAA, 0x55555555)
# huge shift amount (checks op_b[4:0])
ok = test_alu(tb, ALU_SLL, 1, 0xFFFFFFFF)
# arithmetic shift of -1 should remain -1 forever
ok = test_alu(tb, ALU_SRA, 0xFFFFFFFF, 17)
# SLT / SLTU boundary cross-checks
# Max positive vs Max negative
ok = test_alu(tb, ALU_SLT, 0x7FFFFFFF, 0x80000000)   # False (signed: + > -)
ok = test_alu(tb, ALU_SLTU, 0x7FFFFFFF, 0x80000000)  # True (unsigned: 0x7FFFFFFF < 0x80000000)

# -1 vs 0
ok = test_alu(tb, ALU_SLT, 0xFFFFFFFF, 0)            # True (signed: -1 < 0)
ok = test_alu(tb, ALU_SLTU, 0xFFFFFFFF, 0)           # False (unsigned: max_uint > 0)

# Negative shift amounts (should be masked by b & 0x1f, effectively shifting by 31)
ok = test_alu(tb, ALU_SLL, 0x00000001, 0xFFFFFFFF)
ok = test_alu(tb, ALU_SRL, 0x80000000, 0xFFFFFFFF)
ok = test_alu(tb, ALU_SRA, 0x80000000, 0xFFFFFFFF)

# Shift by exactly 31
ok = test_alu(tb, ALU_SLL, 0xFFFFFFFF, 31)
ok = test_alu(tb, ALU_SRL, 0xFFFFFFFF, 31)
ok = test_alu(tb, ALU_SRA, 0xFFFFFFFF, 31)

# Logical operations with extreme masks
ok = test_alu(tb, ALU_XOR, 0x00000000, 0xFFFFFFFF)
ok = test_alu(tb, ALU_OR,  0x00000000, 0x00000000)
ok = test_alu(tb, ALU_AND, 0xFFFFFFFF, 0xFFFFFFFF)

# Addition/Subtraction extreme overflows
ok = test_alu(tb, ALU_ADD, 0x7FFFFFFF, 0x7FFFFFFF)   # Max signed + Max signed
ok = test_alu(tb, ALU_SUB, 0x80000000, 0x7FFFFFFF)   # Min signed - Max signed
ok = test_alu(tb, ALU_ADD, 0xFFFFFFFF, 0xFFFFFFFF)   # -1 + -1 (or max unsigned + max unsigned)

# Alternate bits shift propagation
ok = test_alu(tb, ALU_SRA, 0xAAAAAAAA, 4)
ok = test_alu(tb, ALU_SRL, 0x55555555, 4)
