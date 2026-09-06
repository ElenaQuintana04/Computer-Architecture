/*
 *  Single cycle RV32 processor supporting R-type, I-type, Load & Store instructions
 *  Parts derived from NERV
 */

`include "constants.svh"

`default_nettype none

module rv3608c (
    input clock,
    input reset,
    output trap,
    output logic [31:0] x10,

    // Instruction Memory Interface
    output  [31:0] imem_addr,
    input   [31:0] imem_data
);
    // Instruction memory mapping
    assign  imem_addr = pc;
    assign  insn = imem_data;

    // Data memory
    logic [31:0] dmem [0:1023];
    logic dmem_wr_enable;
    logic [31:0] dmem_wr_addr;
    logic [31:0] dmem_wr_data;
                          
    logic [31:0] dmem_rd_addr;
    logic [31:0] dmem_rd_data;
    
    assign dmem_rd_addr = alu_result;
    assign dmem_rd_data = dmem[dmem_rd_addr];

    // Debugging signals
    logic   [4:0] d_rd;
    logic   [31:0] d_x0, d_x1, d_x2, d_x3, d_x4;
    logic   [6:0] d_opcode;

    // Trap signal
    logic illegalinsn;
    logic trapped;
    assign trap = trapped;

    // Architectural Registers and PC
    logic   [31:0] regfile [0:`NUMREGS-1];
    logic   [31:0] pc;
    logic   [31:0] insn;

    // Instruction Decomposition
    logic   [6:0] insn_funct7;
    logic   [4:0] insn_rs2;
    logic   [4:0] insn_rs1;
    logic   [2:0] insn_funct3;
    logic   [4:0] insn_rd;
    logic   [6:0] insn_opcode;

    assign {insn_funct7, insn_rs2, insn_rs1, insn_funct3, insn_rd, insn_opcode} = insn;

    // Immediates Decoding
    logic   [11:0] imm_i;
    assign  imm_i = insn[31:20];
    wire    [31:0] imm_i_sext = { {20{imm_i[11]}}, imm_i };
    wire    [31:0] imm_shift = 32'(signed'({1'b0, insn[24:20]}));

    logic   [31:0] imm_val;
    assign imm_val = 
        ({insn_funct7, insn_funct3} == `OPCODE_SLLI ||
         {insn_funct7, insn_funct3} == `OPCODE_SRLI ||
         {insn_funct7, insn_funct3} == `OPCODE_SRAI)
         ? imm_shift : imm_i_sext;

    // B-Type Immediate
    logic   [12:0] imm_b;
    assign {imm_b[12], imm_b[10:5]} = insn_funct7, {imm_b[4:1], imm_b[11]} = insn_rd, imm_b[0] = 1'b0;
  
    // J-Type Immediate
    logic   [20:0] imm_j;
    assign  {imm_j[20], imm_j[10:1], imm_j[11], imm_j[19:12], imm_j[0]} = {insn[31:12], 1'b0};
  
    wire    [31:0] imm_b_sext = 32'(signed'(imm_b));
    wire    [31:0] imm_j_sext = 32'(signed'(imm_j));
    
    // S-Type Immediate
    logic   [11:0] imm_s;
    assign  imm_s = {insn_funct7, insn_rd};
    wire    [31:0] imm_s_sext = 32'(signed'(imm_s));

    // ALU Connections
    logic  alu_eq_zero;
    logic  [31:0] alu_result;
    wire   [31:0] alu_op_a = regfile[insn_rs1];
    wire   [31:0] alu_op_b = (insn_opcode == `OPCODE_OP_IMM || insn_opcode == `OPCODE_LOAD) ? imm_val :
                             (insn_opcode == `OPCODE_STORE)  ? imm_s_sext : 
                             regfile[insn_rs2];
    logic  [4:0] alu_op;

    // ALU Operation Decoder
    always_comb begin
        case (insn_opcode)
            `OPCODE_OP_IMM: begin
                casez ({insn_funct7, insn_funct3})
                    10'b zzzzzzz_000 /* ADDI  */: alu_op = `ALU_ADD;
                    10'b zzzzzzz_010 /* SLTI  */: alu_op = `ALU_SLT;
                    10'b zzzzzzz_011 /* SLTIU */: alu_op = `ALU_SLTU;
                    10'b zzzzzzz_100 /* XORI  */: alu_op = `ALU_XOR;
                    10'b zzzzzzz_110 /* ORI   */: alu_op = `ALU_OR;
                    10'b zzzzzzz_111 /* ANDI  */: alu_op = `ALU_AND;
                    10'b 0000000_001 /* SLLI  */: alu_op = `ALU_SLL;
                    10'b 0000000_101 /* SRLI  */: alu_op = `ALU_SRL;
                    10'b 0100000_101 /* SRAI  */: alu_op = `ALU_SRA;
                    default: ;
                endcase
            end

            `OPCODE_OP: begin
                casez ({insn_funct7, insn_funct3})
                    10'b 0000000_000 /* ADD  */: alu_op = `ALU_ADD;
                    10'b 0100000_000 /* SUB  */: alu_op = `ALU_SUB;
                    10'b 0000000_001 /* SLL  */: alu_op = `ALU_SLL;
                    10'b 0000000_010 /* SLT  */: alu_op = `ALU_SLT;
                    10'b 0000000_011 /* SLTU */: alu_op = `ALU_SLTU;
                    10'b 0000000_100 /* XOR  */: alu_op = `ALU_XOR;
                    10'b 0000000_101 /* SRL  */: alu_op = `ALU_SRL;
                    10'b 0100000_101 /* SRA  */: alu_op = `ALU_SRA;
                    10'b 0000000_110 /* OR   */: alu_op = `ALU_OR;
                    10'b 0000000_111 /* AND  */: alu_op = `ALU_AND;
                    default: ;
                endcase
            end

            `OPCODE_BRANCH: begin
                case (insn_funct3)
                    3'b 000 /* BEQ  */: alu_op = `ALU_SUB;
                    3'b 001 /* BNE  */: alu_op = `ALU_SUB;
                    3'b 100 /* BLT  */: alu_op = `ALU_SLT;
                    3'b 101 /* BGE  */: alu_op = `ALU_SLT;
                    3'b 110 /* BLTU */: alu_op = `ALU_SLTU;
                    3'b 111 /* BGEU */: alu_op = `ALU_SLTU;
                    default: alu_op = `ALU_ADD;
                endcase
            end

            `OPCODE_STORE: alu_op = `ALU_ADD;
            `OPCODE_LOAD:  alu_op = `ALU_ADD;
            `OPCODE_JAL:   alu_op = `ALU_ADD;
            `OPCODE_JALR:  alu_op = `ALU_ADD;

            default: alu_op = `ALU_ADD;
        endcase
    end

    // ALU Module Instantiation
    alu alu_1 (
        .alu_function(alu_op),
        .op_a(alu_op_a),
        .op_b(alu_op_b),
        .result(alu_result),
        .result_eq_zero(alu_eq_zero)
    );

    // Control Unit Logic
    logic        regwrite;
    logic [31:0] npc;
    logic [31:0] rfilewdata;

    always_comb begin
        illegalinsn    = 0;
        regwrite       = 0;
        dmem_wr_enable = 0;
        dmem_wr_addr   = alu_result;
        dmem_wr_data   = regfile[insn_rs2];
        npc            = pc + 4;
        rfilewdata     = alu_result;

        case (insn_opcode)
            0: ; // NOP: mantiene valores por defecto

            `OPCODE_OP_IMM: begin
                regwrite = 1;
            end

            `OPCODE_OP: begin
                regwrite = 1;
            end

            `OPCODE_JAL: begin
                npc        = pc + imm_j_sext;
                rfilewdata = pc + 4;
                regwrite   = 1;
            end

            `OPCODE_JALR: begin
                npc        = (regfile[insn_rs1] + imm_i_sext) & ~32'b1;
                rfilewdata = pc + 4;
                regwrite   = 1;
            end

            `OPCODE_BRANCH: begin
                case (insn_funct3)
                    3'b 000 /* BEQ  */: begin if (alu_eq_zero)  npc = pc + imm_b_sext; end
                    3'b 001 /* BNE  */: begin if (!alu_eq_zero) npc = pc + imm_b_sext; end
                    3'b 100 /* BLT  */: begin if (!alu_eq_zero) npc = pc + imm_b_sext; end
                    3'b 101 /* BGE  */: begin if ( alu_eq_zero) npc = pc + imm_b_sext; end
                    3'b 110 /* BLTU */: begin if (!alu_eq_zero) npc = pc + imm_b_sext; end
                    3'b 111 /* BGEU */: begin if ( alu_eq_zero) npc = pc + imm_b_sext; end
                    default: illegalinsn = 1;
                endcase
            end

            `OPCODE_LOAD: begin
                regwrite   = 1;
                rfilewdata = dmem_rd_data;
                $display("lw from 0x%08x = 0x%08x", dmem_rd_addr, dmem_rd_data);
            end

            `OPCODE_STORE: begin
                dmem_wr_enable = 1;
                $display("sw 0x%08x to = 0x%08x", regfile[insn_rs2], dmem_wr_addr);
            end

            default: illegalinsn = 1;
        endcase

        // Unaligned branch / jump address check
        if ((npc & 32'b11) != 0) begin
            illegalinsn = 1;
            npc = pc & ~32'b11;
        end
    end

    // Sequential Logic Block
    always_ff @(posedge clock) begin
        if (!trapped && !reset) begin
            if (illegalinsn)
                trapped <= 1;

            pc <= npc;

            if (regwrite && insn_rd > 0)
                regfile[insn_rd] <= rfilewdata;

            x10 <= regfile[10];

            if (dmem_wr_enable)
                dmem[dmem_wr_addr] <= dmem_wr_data;
        end

        // Synchronous Reset
        if (reset) begin
            pc      <= 0;
            trapped <= 0;
        end

        // Debug output registers (1-cycle delayed)
        d_x0     <= regfile[0];
        d_x1     <= regfile[1];
        d_x2     <= regfile[2];
        d_x3     <= regfile[3];
        d_x4     <= regfile[4];
        d_rd     <= insn_rd;
        d_opcode <= insn_opcode;
    end

endmodule
