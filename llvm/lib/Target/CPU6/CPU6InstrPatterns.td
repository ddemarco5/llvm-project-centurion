//===-- CPU6InstrPatterns.td - SelectionDAG patterns for CPU6 -*- tablegen -*-=//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// Instruction selection reads this file. CPU6DAGToDAGISel::Select calls
// SelectCode, which TableGen generates from the patterns below. A node with
// no pattern dies in llc as "Cannot select:".
//
// The assembler defs in CPU6InstrInfo.td are the instructions selection
// matches, once every register the instruction defines is in (outs) and
// every register it reads is in (ins). isCodeGenOnly is only for a second
// form the assembler must not parse.
//
// Patterns are grouped by the DAG node they match: target nodes, then the
// predicates those patterns share, then control, branches, constants,
// extensions, word arithmetic, byte arithmetic, addresses, and calls.
//
//===----------------------------------------------------------------------===//

//===----------------------------------------------------------------------===//
// Target nodes
//===----------------------------------------------------------------------===//

// Return. LowerReturn builds this node; the pattern turns it into RSR.
// SDNPVariadic lets the node also list the physical registers that were copied
// into, which is how the register allocator learns they are live-out.
def CPU6retglue : SDNode<"CPU6ISD::RET_GLUE", SDTNone,
                         [SDNPHasChain, SDNPOptInGlue, SDNPVariadic]>;

// CPU6ISD::NOP has a chain and no value, matching NOP (opcode 0x01).
def CPU6noop : SDNode<"CPU6ISD::NOP", SDTNone, [SDNPHasChain]>;

// LowerCall builds CPU6ISD::CALL. The callee is an absolute address (JSR
// direct, 0x79 plus a big-endian word) or a register (JSR (r), 0x7D).
def SDT_CPU6Call : SDTypeProfile<0, -1, [SDTCisVT<0, iPTR>]>;
def SDT_CPU6CallSeqStart : SDCallSeqStart<[SDTCisVT<0, i16>, SDTCisVT<1, i16>]>;
def SDT_CPU6CallSeqEnd : SDCallSeqEnd<[SDTCisVT<0, i16>, SDTCisVT<1, i16>]>;

def CPU6call : SDNode<"CPU6ISD::CALL", SDT_CPU6Call,
                      [SDNPHasChain, SDNPOutGlue, SDNPOptInGlue, SDNPVariadic]>;
// Tail call. No output glue: the jump does not return into this function.
def CPU6tcret : SDNode<"CPU6ISD::TC_RETURN", SDT_CPU6Call,
                       [SDNPHasChain, SDNPOptInGlue, SDNPVariadic]>;
def CPU6callseq_start : SDNode<"ISD::CALLSEQ_START", SDT_CPU6CallSeqStart,
                               [SDNPHasChain, SDNPOutGlue]>;
def CPU6callseq_end : SDNode<"ISD::CALLSEQ_END", SDT_CPU6CallSeqEnd,
                             [SDNPHasChain, SDNPOptInGlue, SDNPOutGlue]>;

// Flags from a compare, glued to the one node that reads them. CMP a,b
// sets them from a - b and also yields that difference; TST sets Minus and
// Value from its operand.
def CPU6cmp : SDNode<"CPU6ISD::CMP",
                     SDTypeProfile<1, 2, [SDTCisInt<0>, SDTCisSameAs<0, 1>,
                                          SDTCisSameAs<0, 2>]>,
                     [SDNPOutGlue]>;
def CPU6tst : SDNode<"CPU6ISD::TST", SDTypeProfile<0, 1, [SDTCisInt<0>]>,
                     [SDNPOutGlue]>;
// The condition operand is the opcode of the branch that tests it.
// CPU6DAGToDAGISel::Select turns BR_CC into that branch.
def CPU6brcc : SDNode<"CPU6ISD::BR_CC",
                      SDTypeProfile<0, 2, [SDTCisVT<0, OtherVT>,
                                           SDTCisVT<1, i16>]>,
                      [SDNPHasChain, SDNPInGlue]>;
def CPU6selectcc : SDNode<"CPU6ISD::SELECT_CC",
                          SDTypeProfile<1, 3, [SDTCisSameAs<0, 1>,
                                               SDTCisSameAs<0, 2>,
                                               SDTCisVT<3, i16>]>,
                          [SDNPInGlue]>;
// x + delta, or x if the branch in $skip is taken. This is what the carry or
// borrow of a wide add or subtract becomes, so the 0 and 1 of a select are
// never made. delta is 1 or -1.
def CPU6stepcc : SDNode<"CPU6ISD::STEP_CC",
                        SDTypeProfile<1, 3, [SDTCisVT<0, i16>,
                                             SDTCisSameAs<0, 1>,
                                             SDTCisVT<2, i16>,
                                             SDTCisVT<3, i16>]>,
                        [SDNPInGlue]>;

// Bignum memops. Ptrs are i16; $len is length-1 (i8 target constant).
def SDT_CPU6Bignum : SDTypeProfile<0, 3,
    [SDTCisVT<0, iPTR>, SDTCisVT<1, iPTR>, SDTCisVT<2, i8>]>;
def CPU6bnmov : SDNode<"CPU6ISD::BN_MOV", SDT_CPU6Bignum,
                       [SDNPHasChain, SDNPMayLoad, SDNPMayStore,
                        SDNPMemOperand]>;
def CPU6bnadd : SDNode<"CPU6ISD::BN_ADD", SDT_CPU6Bignum,
                       [SDNPHasChain, SDNPMayLoad, SDNPMayStore,
                        SDNPMemOperand]>;
def CPU6bnsub : SDNode<"CPU6ISD::BN_SUB", SDT_CPU6Bignum,
                       [SDNPHasChain, SDNPMayLoad, SDNPMayStore,
                        SDNPMemOperand]>;
def CPU6bnneg : SDNode<"CPU6ISD::BN_NEG", SDT_CPU6Bignum,
                       [SDNPHasChain, SDNPMayLoad, SDNPMayStore,
                        SDNPMemOperand]>;
def CPU6bnmul : SDNode<"CPU6ISD::BN_MUL", SDT_CPU6Bignum,
                       [SDNPHasChain, SDNPMayLoad, SDNPMayStore,
                        SDNPMemOperand]>;
def CPU6bndiv : SDNode<"CPU6ISD::BN_DIV", SDT_CPU6Bignum,
                       [SDNPHasChain, SDNPMayLoad, SDNPMayStore,
                        SDNPMemOperand]>;
// Divide with remainder. The remainder's address is in A, copied there by the
// node that creates this one, and arrives as glue.
def CPU6bndrm : SDNode<"CPU6ISD::BN_DRM", SDT_CPU6Bignum,
                       [SDNPHasChain, SDNPInGlue, SDNPMayLoad, SDNPMayStore,
                        SDNPMemOperand]>;
// Compare: chain and glue out. BNC only reads memory.
def CPU6bncmp : SDNode<"CPU6ISD::BN_CMP",
                       SDTypeProfile<0, 3, [SDTCisVT<0, iPTR>,
                                            SDTCisVT<1, iPTR>,
                                            SDTCisVT<2, i8>]>,
                       [SDNPHasChain, SDNPOutGlue, SDNPMayLoad,
                        SDNPMemOperand]>;

// Block copy and fill (0x47). CPU6SelectionDAGInfo builds these for a
// constant-size memcpy, memmove, or memset. $cnt is the byte count minus one.
def CPU6blkcopy : SDNode<"CPU6ISD::BLK_COPY",
                         SDTypeProfile<0, 3, [SDTCisVT<0, iPTR>,
                                              SDTCisVT<1, iPTR>,
                                              SDTCisVT<2, i8>]>,
                         [SDNPHasChain, SDNPMayLoad, SDNPMayStore]>;
def CPU6blkfill : SDNode<"CPU6ISD::BLK_FILL",
                         SDTypeProfile<0, 3, [SDTCisVT<0, i8>,
                                              SDTCisVT<1, iPTR>,
                                              SDTCisVT<2, i8>]>,
                         [SDNPHasChain, SDNPMayStore]>;
// A copy or fill of a run-time length: the operands are src, dst, and the
// byte count (memcpy), or dst, the byte, and the count (memset).
def CPU6memcpyloop : SDNode<"CPU6ISD::MEMCPY_LOOP",
                            SDTypeProfile<0, 3, [SDTCisVT<0, iPTR>,
                                                 SDTCisVT<1, iPTR>,
                                                 SDTCisVT<2, i16>]>,
                            [SDNPHasChain, SDNPMayLoad, SDNPMayStore]>;
def CPU6memmoveloop : SDNode<"CPU6ISD::MEMMOVE_LOOP",
                             SDTypeProfile<0, 3, [SDTCisVT<0, iPTR>,
                                                  SDTCisVT<1, iPTR>,
                                                  SDTCisVT<2, i16>]>,
                             [SDNPHasChain, SDNPMayLoad, SDNPMayStore]>;
def CPU6memsetloop : SDNode<"CPU6ISD::MEMSET_LOOP",
                            SDTypeProfile<0, 3, [SDTCisVT<0, iPTR>,
                                                 SDTCisVT<1, i8>,
                                                 SDTCisVT<2, i16>]>,
                            [SDNPHasChain, SDNPMayLoad, SDNPMayStore]>;

//===----------------------------------------------------------------------===//
// Predicates and transforms
//===----------------------------------------------------------------------===//

def imm16_0to15 : ImmLeaf<i16, [{ return Imm >= 0 && Imm <= 15; }]>;
def shamt16_1to15 : ImmLeaf<i16, [{ return Imm >= 1 && Imm <= 15; }]>;

// The register/count family is two bytes. The count nibble n means n + 1
// for INR, DCR, SLR, SRR and their byte twins, and n itself for CLR and CLRB.
def count_minus1 : SDNodeXForm<imm, [{
  return CurDAG->getTargetConstant(N->getSExtValue() - 1, SDLoc(N), MVT::i8);
}]>;
def neg_count_minus1 : SDNodeXForm<imm, [{
  return CurDAG->getTargetConstant(-N->getSExtValue() - 1, SDLoc(N), MVT::i8);
}]>;
def count_as_i8 : SDNodeXForm<imm, [{
  return CurDAG->getTargetConstant(N->getSExtValue(), SDLoc(N), MVT::i8);
}]>;

// SRR sign-fills. These are the bits that are still real data afterwards.
def srl_mask16 : SDNodeXForm<imm, [{
  return CurDAG->getTargetConstant((1u << (16 - N->getZExtValue())) - 1,
                                   SDLoc(N), MVT::i16);
}]>;
def srl_mask8 : SDNodeXForm<imm, [{
  return CurDAG->getTargetConstant((1u << (8 - N->getZExtValue())) - 1,
                                   SDLoc(N), MVT::i16);
}]>;

// An i8 literal as the i16 operand of a word instruction. Only the low byte
// of the result is used. getTargetConstant takes a uint64_t and builds an
// unsigned APInt of that width. getSExtValue() of 0x80..0xFF is negative,
// and that value does not fit in 16 unsigned bits, so the constructor
// asserts. Zero-extending keeps the i8 bit pattern.
def imm8_as_16 : SDNodeXForm<imm, [{
  return CurDAG->getTargetConstant(N->getZExtValue(), SDLoc(N), MVT::i16);
}]>;

// A byte in the low half of an otherwise undefined word. REG_SEQUENCE, not
// INSERT_SUBREG into IMPLICIT_DEF: at -O0 nothing marks that IMPLICIT_DEF
// undef, so the word looks live above the insert and pins A while AL is
// still needed for the byte. REG_SEQUENCE writes sub_lo as a fresh def.
defvar ByteInWord = (REG_SEQUENCE GPR, GPRB:$src, sub_lo,
                                  (i8 (IMPLICIT_DEF)), sub_hi);

def imm8_1to16 : ImmLeaf<i8, [{ return Imm >= 1 && Imm <= 16; }]>;
def imm8_m16tom1 : ImmLeaf<i8, [{ return Imm >= -16 && Imm <= -1; }]>;
def imm8_0to15 : ImmLeaf<i8, [{ return Imm >= 0 && Imm <= 15; }]>;
// i8 shift amounts are i16, the pointer width. 8 and up are poison.
def shamt8_1to7 : ImmLeaf<i16, [{ return Imm >= 1 && Imm <= 7; }]>;

// Byte ALU with a literal: run the word op on the containing register and
// keep the low byte. The carry out of bit 7 lands in the upper half, which
// nothing reads.
class ByteImmPat<SDNode op, Instruction inst>
    : Pat<(op GPRB:$src, (i8 imm:$imm)),
          (EXTRACT_SUBREG (inst ByteInWord, (imm8_as_16 imm:$imm)), sub_lo)>;

//===----------------------------------------------------------------------===//
// Control
//===----------------------------------------------------------------------===//

def : Pat<(CPU6noop), (NOP)>;

// Select the return node LowerReturn builds. RSR is marked isReturn,
// isTerminator, and isBarrier in CPU6InstrInfo.td.
def : Pat<(CPU6retglue), (RSR)>;

// STK and POP are not selected here. A Pat matches one DAG node, and nothing
// in the DAG means "save whichever of X, Y, Z this function clobbers."
// That set is CSR in CPU6CallingConv.td. The prologue inserter asks
// CPU6FrameLowering::spillCalleeSavedRegisters, which emits one STK per
// contiguous stretch of X, Y, Z and a matching POP in front of RSR. Same
// split as MSP430 PUSH/POP.

//===----------------------------------------------------------------------===//
// Branches and compares
//===----------------------------------------------------------------------===//

// Every CPU6 move, load, store, and spill writes Minus and Value, so nothing
// may come between a compare and the branch that reads it. These compares
// are terminators: copies, spills, and PHI moves all go in front of the first
// terminator. They are the assembler's SUB, SUBB, SUB literal, and XFR r,r.
// CPU6InstrInfo::analyzeBranch leaves them in place when it rewrites the
// branches after them.
class Test16<bits<8> op, RegisterClass RC, string opstr>
    : CenturionInst16<(outs), (ins RC:$r), opstr, "$r,$r"> {
  bits<4> r;
  let Inst{15-8} = op;
  let Inst{7-4} = r;
  let Inst{3-0} = r;
}
let isCodeGenOnly = 1, isTerminator = 1, isCompare = 1 in {
let Defs = [rF, rL, rM, rV] in {
def CMP : DoubleReg16RMW<0x51, "SUB">;
def CMPB : DoubleReg16_BRMW<0x41, "SUBB">;
}
def CMPimm : DoubleRegImm32<0x51, "SUB">;
let hasSideEffects = 0, mayLoad = 0, mayStore = 0, Defs = [rM, rV] in {
def TST : Test16<0x55, GPR, "XFR">;
def TSTB : Test16<0x45, GPRB, "XFRB">;
}
}

// SUB src,dst sets the flags of src - dst. The literal form is imm - src.
def : Pat<(CPU6cmp GPR:$a, GPR:$b), (CMP GPR:$a, GPR:$b)>;
def : Pat<(CPU6cmp (i16 imm:$c), GPR:$x), (CMPimm GPR:$x, imm:$c)>;
def : Pat<(CPU6cmp GPRB:$a, GPRB:$b), (CMPB GPRB:$a, GPRB:$b)>;
def : Pat<(CPU6tst GPR:$r), (TST GPR:$r)>;
def : Pat<(CPU6tst GPRB:$r), (TSTB GPRB:$r)>;

def : Pat<(br bb:$dst), (JMP_3 bb:$dst)>;
def : Pat<(brind GPR:$r), (JMP_5_0 GPR:$r)>;

// A select becomes a branch around nothing and a PHI
// (CPU6TargetLowering::EmitInstrWithCustomInserter). $cc is the branch
// opcode, taken to keep $t.
let usesCustomInserter = 1, isPseudo = 1, isCodeGenOnly = 1,
    hasSideEffects = 0, Uses = [rF, rL, rM, rV] in {
def SELECT : CenturionInst<(outs GPR:$dst), (ins GPR:$t, GPR:$f, i16imm:$cc),
                           "#SELECT", "$dst,$t,$f,$cc">;
def SELECTB : CenturionInst<(outs GPRB:$dst),
                            (ins GPRB:$t, GPRB:$f, i16imm:$cc),
                            "#SELECTB", "$dst,$t,$f,$cc">;
}
def : Pat<(CPU6selectcc GPR:$t, GPR:$f, timm:$cc),
          (SELECT GPR:$t, GPR:$f, timm:$cc)>;
def : Pat<(CPU6selectcc GPRB:$t, GPRB:$f, timm:$cc),
          (SELECTB GPRB:$t, GPRB:$f, timm:$cc)>;

// A step is a branch around an ADDimm
// (CPU6TargetLowering::EmitInstrWithCustomInserter). $skip is the branch
// opcode, taken to leave $x as it is.
let usesCustomInserter = 1, isPseudo = 1, isCodeGenOnly = 1,
    hasSideEffects = 0, Uses = [rF, rL, rM, rV] in
def STEPCC : CenturionInst<(outs GPR:$dst),
                           (ins GPR:$x, i16imm:$delta, i16imm:$skip),
                           "#STEPCC", "$dst,$x,$delta,$skip">;
def : Pat<(CPU6stepcc GPR:$x, timm:$delta, timm:$skip),
          (STEPCC GPR:$x, timm:$delta, timm:$skip)>;

//===----------------------------------------------------------------------===//
// Constants
//===----------------------------------------------------------------------===//

// An i16 constant selects the same XFRimm the assembler parses.
def : Pat<(i16 imm:$imm), (XFRimm imm:$imm)>;

// CLR r,n writes n (0-15) in two bytes. It beats the four-byte XFR.
let AddedComplexity = 1 in
def : Pat<(i16 imm16_0to15:$n), (CLR (count_as_i8 $n))>;

// There is no byte literal form outside AL and BL, so a byte constant is the
// low half of a word XFR. CLRB r,n writes 0-15 and beats that.
def : Pat<(i8 imm:$imm),
          (EXTRACT_SUBREG (XFRimm (imm8_as_16 imm:$imm)), sub_lo)>;
let AddedComplexity = 1 in
def : Pat<(i8 imm8_0to15:$n), (CLRB imm:$n)>;

//===----------------------------------------------------------------------===//
// Extensions and subregisters
//===----------------------------------------------------------------------===//

def : Pat<(i16 (anyext GPRB:$src)), ByteInWord>;
def : Pat<(i8 (trunc GPR:$src)), (EXTRACT_SUBREG GPR:$src, sub_lo)>;

// No instruction extends a byte. zext clears the upper half with AND.
// sext rebuilds bit 7 across the word: ((x & 0xff) ^ 0x80) - 0x80.
def : Pat<(i16 (zext GPRB:$src)), (ANDimm ByteInWord, 255)>;
def : Pat<(sext_inreg GPR:$src, i8),
          (ADDimm (OREimm (ANDimm GPR:$src, 255), 128), -128)>;
def : Pat<(i16 (sext GPRB:$src)),
          (ADDimm (OREimm (ANDimm ByteInWord, 255), 128), -128)>;

//===----------------------------------------------------------------------===//
// Word arithmetic
//===----------------------------------------------------------------------===//

// Register/register word ALU is two-address: `ADD B,X` reads and writes X.
// The first operand is the source nibble, the second the destination's
// incoming value. SUB is dst = src - dst, so a - b keeps b in the
// destination.
def : Pat<(add GPR:$a, GPR:$b), (ADD GPR:$a, GPR:$b)>;
def : Pat<(and GPR:$a, GPR:$b), (AND GPR:$a, GPR:$b)>;
def : Pat<(or GPR:$a, GPR:$b), (ORI GPR:$a, GPR:$b)>;
def : Pat<(xor GPR:$a, GPR:$b), (ORE GPR:$a, GPR:$b)>;
def : Pat<(sub GPR:$a, GPR:$b), (SUB GPR:$a, GPR:$b)>;
// The i16 product is the low half of the 32-bit unsigned MUL. EmitMulLow
// copies one operand into B and uses MULB, so the written register is the
// low half. B is fixed rather than allocated from MulLo: B and Y are the
// only such destinations, and they are where a wider argument arrives.
let usesCustomInserter = 1, isPseudo = 1, isCodeGenOnly = 1,
    hasSideEffects = 0, Defs = [rF, rL, rM, rV] in
def MULrr : CenturionInst<(outs GPR:$dst), (ins GPR:$a, GPR:$b),
                          "#MUL", "$dst,$a,$b">;
def : Pat<(mul GPR:$a, GPR:$b), (MULrr GPR:$a, GPR:$b)>;
// The i16 quotient is the low half of the 32-bit DIV, and the remainder is
// the high half. EmitDiv copies the dividend into B and uses DIVB, so the
// written register is the quotient. A pair destination would leave the
// remainder in the named register.
let usesCustomInserter = 1, isPseudo = 1, isCodeGenOnly = 1,
    hasSideEffects = 0, Defs = [rF, rL, rM, rV] in
def DIVrr : CenturionInst<(outs GPR:$dst), (ins GPR:$a, GPR:$b),
                          "#DIV", "$dst,$a,$b">;
def : Pat<(udiv GPR:$a, GPR:$b), (DIVrr GPR:$a, GPR:$b)>;
// umul_lohi is the node the type legalizer emits when it splits a multiply
// wider than i16. An i32 mul becomes one i16 umul_lohi of the low halves
// plus i16 muls for the cross terms. An i64 mul splits into i32 muls, and
// each of those splits again into the same node. EmitMulLoHi copies one
// operand into A and uses MULAB, which writes the high half back to A and
// the low half to B.
let usesCustomInserter = 1, isPseudo = 1, isCodeGenOnly = 1,
    hasSideEffects = 0, Defs = [rF, rL, rM, rV] in
def MULlohi : CenturionInst<(outs GPR:$lo, GPR:$hi), (ins GPR:$a, GPR:$b),
                            "#MULLOHI", "$lo,$hi,$a,$b"> {
  let Pattern = [(set GPR:$lo, GPR:$hi, (umullohi GPR:$a, GPR:$b))];
}
// Bits [15:8] of an unsigned 8x8 product. EmitMulhu zero-extends both bytes
// and shifts the word MUL. An i16 mulhu would be bits [31:16] of a 32-bit
// product, and those are zero for a pair of zero-extended bytes.
let usesCustomInserter = 1, isPseudo = 1, isCodeGenOnly = 1,
    hasSideEffects = 0 in
def MULHUb : CenturionInst<(outs GPRB:$dst), (ins GPRB:$a, GPRB:$b),
                           "#MULHUb", "$dst,$a,$b">;
def : Pat<(mulhu GPRB:$a, GPRB:$b), (MULHUb GPRB:$a, GPRB:$b)>;

// Word ALU with a literal. Mode 2 writes dst = src op imm, except SUB, which
// is dst = imm - src. A register minus a constant is an add of the negated
// constant; the AsmPrinter emits INR/DCR when that add is in place and the
// magnitude is at most 16. Selection keeps ADDimm so the allocator may give
// the result its own register.
def : Pat<(add GPR:$src, (i16 imm:$imm)), (ADDimm GPR:$src, imm:$imm)>;
def : Pat<(sub (i16 imm:$imm), GPR:$src), (SUBimm GPR:$src, imm:$imm)>;
def : Pat<(and GPR:$src, (i16 imm:$imm)), (ANDimm GPR:$src, imm:$imm)>;
def : Pat<(or GPR:$src, (i16 imm:$imm)), (ORIimm GPR:$src, imm:$imm)>;
def : Pat<(xor GPR:$src, (i16 imm:$imm)), (OREimm GPR:$src, imm:$imm)>;
def : Pat<(mul GPR:$src, (i16 imm:$imm)), (MULimmLo GPR:$src, imm:$imm)>;
def : Pat<(udiv GPR:$src, (i16 imm:$imm)), (DIVimmLo GPR:$src, imm:$imm)>;

// IVR ignores its count nibble. SLR r,n shifts left by n + 1, and SRR r,n
// shifts right arithmetically by n + 1. There is no logical right shift.
// A constant one is SRR plus a mask (LowerShift): one arithmetic shift of the
// whole distance, then the sign bits it filled are cleared. A variable one
// cannot use a longer RRR, because that rotates the shifted-out bits back
// through Link; the loop clears Link and rotates by one. RLR is the matching
// left rotate.
let AddedComplexity = 1 in {
def : Pat<(not GPR:$r), (IVR GPR:$r, 0)>;
def : Pat<(shl GPR:$r, shamt16_1to15:$n), (SLR GPR:$r, (count_minus1 $n))>;
def : Pat<(sra GPR:$r, shamt16_1to15:$n), (SRR GPR:$r, (count_minus1 $n))>;
// Built here rather than by rewriting the node to an arithmetic shift and an
// AND. That rewrite is turned back into a logical shift by the combiner, and
// legalization never finishes. A longer RRR is not this either: it rotates
// the shifted-out bits back through Link.
def : Pat<(srl GPR:$r, shamt16_1to15:$n),
          (ANDimm (SRR GPR:$r, (count_minus1 $n)), (srl_mask16 $n))>;
}

//===----------------------------------------------------------------------===//
// Byte arithmetic
//===----------------------------------------------------------------------===//

// Byte register/register ALU. The first operand is the source nibble, the
// second is the destination nibble's incoming value.
def : Pat<(add GPRB:$a, GPRB:$b), (ADDB GPRB:$a, GPRB:$b)>;
def : Pat<(and GPRB:$a, GPRB:$b), (ANDB GPRB:$a, GPRB:$b)>;
def : Pat<(or GPRB:$a, GPRB:$b), (ORIB GPRB:$a, GPRB:$b)>;
def : Pat<(xor GPRB:$a, GPRB:$b), (OREB GPRB:$a, GPRB:$b)>;
// SUBB is dst = src - dst, so a - b keeps b in the destination.
def : Pat<(sub GPRB:$a, GPRB:$b), (SUBB GPRB:$a, GPRB:$b)>;

// Past the count nibble, the word literal form runs on the containing
// register. SUB's literal form is dst = imm - src, which is a constant
// minus a byte.
def : ByteImmPat<add, ADDimm>;
def : ByteImmPat<and, ANDimm>;
def : ByteImmPat<or, ORIimm>;
def : ByteImmPat<xor, OREimm>;
def : Pat<(sub (i8 imm:$imm), GPRB:$src),
          (EXTRACT_SUBREG (SUBimm ByteInWord, (imm8_as_16 imm:$imm)), sub_lo)>;

// INRB/DCRB/IVRB/SLRB/SRRB are two bytes and beat the four-byte word literal
// forms. INRB and DCRB add or subtract n + 1. IVRB has no count. SLRB r,n
// shifts left by n + 1, and SRRB r,n shifts right arithmetically by n + 1.
// Amounts of 8 and up are poison for i8.
let AddedComplexity = 1 in {
def : Pat<(add GPRB:$r, imm8_1to16:$n), (INRB GPRB:$r, (count_minus1 $n))>;
def : Pat<(add GPRB:$r, imm8_m16tom1:$n),
          (DCRB GPRB:$r, (neg_count_minus1 $n))>;
def : Pat<(not GPRB:$r), (IVRB GPRB:$r)>;
def : Pat<(shl GPRB:$r, shamt8_1to7:$n), (SLRB GPRB:$r, (count_minus1 $n))>;
def : Pat<(sra GPRB:$r, shamt8_1to7:$n), (SRRB GPRB:$r, (count_minus1 $n))>;
// The mask is applied to the word that holds the byte. The high half is
// undefined and the extract keeps only the shifted byte.
def : Pat<(srl GPRB:$r, shamt8_1to7:$n),
          (EXTRACT_SUBREG
              (ANDimm (REG_SEQUENCE GPR,
                                    (SRRB GPRB:$r, (count_minus1 $n)), sub_lo,
                                    (i8 (IMPLICIT_DEF)), sub_hi),
                      (srl_mask8 $n)),
              sub_lo)>;
}

// A variable count cannot use the nibble above. EmitShift replaces the pseudo
// with a one-bit loop. The count is i16 for a byte shift as well: that is
// getShiftAmountTy on this target. A constant count is an immediate, so it
// matches SLR/SRR above and not these.
let usesCustomInserter = 1, isPseudo = 1, isCodeGenOnly = 1,
    hasSideEffects = 0 in {
def SHLrr : CenturionInst<(outs GPR:$dst), (ins GPR:$src, GPR:$cnt),
                          "#SHLrr", "$dst,$src,$cnt">;
def SRArr : CenturionInst<(outs GPR:$dst), (ins GPR:$src, GPR:$cnt),
                          "#SRArr", "$dst,$src,$cnt">;
def SRLrr : CenturionInst<(outs GPR:$dst), (ins GPR:$src, GPR:$cnt),
                          "#SRLrr", "$dst,$src,$cnt">;
def SHLbr : CenturionInst<(outs GPRB:$dst), (ins GPRB:$src, GPR:$cnt),
                          "#SHLbr", "$dst,$src,$cnt">;
def SRAbr : CenturionInst<(outs GPRB:$dst), (ins GPRB:$src, GPR:$cnt),
                          "#SRAbr", "$dst,$src,$cnt">;
def SRLbr : CenturionInst<(outs GPRB:$dst), (ins GPRB:$src, GPR:$cnt),
                          "#SRLbr", "$dst,$src,$cnt">;
}
def : Pat<(shl GPR:$src, GPR:$cnt), (SHLrr GPR:$src, GPR:$cnt)>;
def : Pat<(sra GPR:$src, GPR:$cnt), (SRArr GPR:$src, GPR:$cnt)>;
def : Pat<(srl GPR:$src, GPR:$cnt), (SRLrr GPR:$src, GPR:$cnt)>;
def : Pat<(shl GPRB:$src, GPR:$cnt), (SHLbr GPRB:$src, GPR:$cnt)>;
def : Pat<(sra GPRB:$src, GPR:$cnt), (SRAbr GPRB:$src, GPR:$cnt)>;
def : Pat<(srl GPRB:$src, GPR:$cnt), (SRLbr GPRB:$src, GPR:$cnt)>;

// Variable shift of a value wider than a word. Words are low to high.
// $k is 0 for left, 1 for logical right, 2 for arithmetic right.
// EmitWideShift walks the defs, so every width shares one loop.
let usesCustomInserter = 1, isPseudo = 1, isCodeGenOnly = 1,
    hasSideEffects = 0 in {
def WSHIFT2 : CenturionInst<(outs GPR:$d0, GPR:$d1),
                            (ins GPR:$s0, GPR:$s1, GPR:$c, i16imm:$k),
                            "#WSHIFT2", "">;
def WSHIFT4 : CenturionInst<(outs GPR:$d0, GPR:$d1, GPR:$d2, GPR:$d3),
                            (ins GPR:$s0, GPR:$s1, GPR:$s2, GPR:$s3, GPR:$c,
                                 i16imm:$k),
                            "#WSHIFT4", "">;
def WSHIFT8 : CenturionInst<(outs GPR:$d0, GPR:$d1, GPR:$d2, GPR:$d3,
                                  GPR:$d4, GPR:$d5, GPR:$d6, GPR:$d7),
                            (ins GPR:$s0, GPR:$s1, GPR:$s2, GPR:$s3,
                                 GPR:$s4, GPR:$s5, GPR:$s6, GPR:$s7,
                                 GPR:$c, i16imm:$k),
                            "#WSHIFT8", "">;
}

//===----------------------------------------------------------------------===//
// Addresses
//===----------------------------------------------------------------------===//

// A load or store address is one of two modes (CPU6ISelDAGToDAG.cpp):
//   addr     `(r),disp`. A register or a frame index plus a displacement.
//            A word uses XFR/STR, which name the data register and take a
//            word displacement. A byte uses LDBYTE, expanded to LDAB or LDBB,
//            whose displacement is a signed byte. orderFrameObjects places
//            those byte objects nearest the final S. eliminateFrameIndex
//            replaces a frame index with S and adds the slot's distance
//            from S.
//   absaddr  `(addr)`, M = 1. A global, an external symbol, a block
//            address, or a number. A word is XFRabs/STRmem, any register.
//            A byte is LDBYTEabs, expanded to LDAB or LDBB.
// absaddr is tried first. Otherwise addr would take a global as its base and
// load through a register holding the global's address.
def addr : ComplexPattern<i16, 2, "SelectAddr">;
def absaddr : ComplexPattern<i16, 1, "SelectAbsAddr",
                             [globaladdr, externalsym, blockaddress], [], 10>;
// Indexed bignum operand. A frame index, or a register plus a nonzero simm8,
// and only when this instruction is the address's only user. SelectBignumAddr
// rejects a bare register and an address word; those stay RR or AA.
def bnaddr : ComplexPattern<i16, 2, "SelectBignumAddr",
                            [frameindex, add, or], [], 10>;
// Absolute bignum operand with the same single-user rule. AA keeps absaddr.
def bnabs : ComplexPattern<i16, 1, "SelectBignumAbs",
                           [globaladdr, externalsym, blockaddress], [], 10>;
// The address itself, S plus a word. Also tried before the add patterns, so
// a slot plus a constant is one ADD.
def frameaddr : ComplexPattern<i16, 2, "SelectFrameAddr", [frameindex, add, or],
                               [], 10>;

// The accumulator loads and stores: LDA/STA move A, LDAB/STAB move AL. The
// assembler records (LDA_5_8, LDA_1, ...) have no result operand, because
// the mnemonic already means A. These are the same encodings with the
// register named, so selection can use them. isCodeGenOnly: the assembler
// keeps parsing `LDA (X),21`.
multiclass AccMemory<bits<4> ldOpc, bits<4> stOpc, RegisterClass RC> {
  let isCodeGenOnly = 1, hasSideEffects = 0, Defs = [rM, rV] in {
    let mayLoad = 1, mayStore = 0 in {
      def "LD"#NAME#"fi" : Memory24Index<ldOpc, 0x8, (outs RC:$dst),
                               (ins GPR:$r, i16imm:$arg), "LD"#NAME, "(${r}),$arg">;
      def "LD"#NAME#"abs" : Memory24<ldOpc, 0x1, (outs RC:$dst), (ins abs16:$arg),
                                     "LD"#NAME, "(${arg})">;
    }
    let mayLoad = 0, mayStore = 1 in {
      def "ST"#NAME#"fi" : Memory24Index<stOpc, 0x8, (outs),
                               (ins RC:$src, GPR:$r, i16imm:$arg), "ST"#NAME, "(${r}),$arg">;
      def "ST"#NAME#"abs" : Memory24<stOpc, 0x1, (outs), (ins RC:$src, abs16:$arg),
                                     "ST"#NAME, "(${arg})">;
    }
  }
}
// LDAfi, STAfi, LDAabs, STAabs: opcode rows 0x9 and 0xB. The absolute word
// patterns are not these. LDA writes only A, so two absolute loads cannot
// both be live. XFRabs is rrfetchw mode 1 and writes any word register.
// STRmem is the matching store.
defm A : AccMemory<0x9, 0xB, Acc>;
// LDABfi, STABfi, LDABabs, STABabs: opcode rows 0x8 and 0xA. LDBBfi and
// LDBBabs are rows 0xC and 0xE. webCenREE's rrfetchb has no memory mode, so
// a byte load cannot name an arbitrary register the way XFR does. These are
// what expandPostRAPseudo emits for LDBYTEfi and LDBYTEabs.
defm AB : AccMemory<0x8, 0xA, AccB>;
defm BB : AccMemory<0xC, 0xE, AccBL>;
// A selected byte load. The destination is any byte register, so two loads
// can be live at a CMPB. expandPostRAPseudo turns it into LDAB or LDBB.
// Operands match LDABfi, so eliminateFrameIndex treats a frame index alike.
// Five bytes covers LDAB plus an XFRB when the destination is neither
// accumulator. The expanded load sets Minus and Value, so the pseudo does too.
let isPseudo = 1, isCodeGenOnly = 1, hasSideEffects = 0, Defs = [rM, rV],
    Size = 5 in {
let mayLoad = 1, mayStore = 0 in {
def LDBYTEfi : CenturionInst<(outs GPRB:$dst), (ins GPR:$base, i16imm:$disp),
                             "#LDBYTE", "(${base}),$dst,$disp">;
def LDBYTEabs : CenturionInst<(outs GPRB:$dst), (ins abs16:$addr),
                              "#LDBYTE", "(${addr}),$dst">;
}
}
def : Pat<(i16 (load (absaddr abs16:$a))), (XFRabs abs16:$a)>;
def : Pat<(store GPR:$src, (absaddr abs16:$a)),
          (STRmem GPR:$src, abs16:$a)>;
def : Pat<(i8 (load (absaddr abs16:$a))), (LDBYTEabs abs16:$a)>;
def : Pat<(store AccB:$src, (absaddr abs16:$a)),
          (STABabs AccB:$src, abs16:$a)>;

// Word indexed load/store. XFR and STR name the data register, so two loaded
// values can be live together. A byte load's result is any byte register for
// the same reason: CMPB needs both operands at once, and a result pinned to
// AL makes the second one impossible. The expanded form is LDAB or LDBB, and
// an XFRB when the register is neither accumulator.
def : Pat<(i16 (load (addr GPR:$r, i16imm:$d))),
          (XFRidx GPR:$r, i16imm:$d)>;
def : Pat<(store GPR:$src, (addr GPR:$r, i16imm:$d)),
          (STRidx GPR:$src, GPR:$r, i16imm:$d)>;
def : Pat<(i8 (load (addr GPR:$r, i16imm:$d))),
          (LDBYTEfi GPR:$r, i16imm:$d)>;
def : Pat<(store AccB:$src, (addr GPR:$r, i16imm:$d)),
          (STABfi AccB:$src, GPR:$r, i16imm:$d)>;

def : Pat<(frameaddr GPR:$r, i16imm:$d), (ADDimm GPR:$r, i16imm:$d)>;
// XFRimm's immediate is abs16, so a symbol is fixup_cpu6_abs_16.
def : Pat<(absaddr abs16:$a), (XFRimm abs16:$a)>;

// Byte spill and reload. The register allocator can spill any byte register.
// expandPostRAPseudo turns these into LDAB/STAB, moving the byte through AL
// and keeping AL intact if it is live. Operands match LDABfi/STABfi, so
// eliminateFrameIndex treats them alike. They are not selected;
// storeRegToStackSlot and loadRegFromStackSlot emit them.
// The expanded LDAB/STAB set Minus and Value, so the pseudo does too.
let isPseudo = 1, isCodeGenOnly = 1, hasSideEffects = 0, Defs = [rM, rV] in {
let mayLoad = 0, mayStore = 1 in
def SPILLB : CenturionInst<(outs), (ins GPRB:$src, GPR:$r, i16imm:$arg),
                           "#SPILLB", "$src,(${r}),$arg">;
let mayLoad = 1, mayStore = 0 in
def RELOADB : CenturionInst<(outs GPRB:$dst), (ins GPR:$r, i16imm:$arg),
                            "#RELOADB", "(${r}),$dst,$arg">;
}

//===----------------------------------------------------------------------===//
// Block memory
//===----------------------------------------------------------------------===//

// MVF count,src,dst and FIL count,lit,dst with both addresses in registers.
def : Pat<(CPU6blkcopy GPR:$src, GPR:$dst, (i8 timm:$cnt)),
          (MVF_RR timm:$cnt, GPR:$src, GPR:$dst)>;
def : Pat<(CPU6blkfill (i8 timm:$byte), GPR:$dst, (i8 timm:$cnt)),
          (FIL_R timm:$cnt, timm:$byte, GPR:$dst)>;

// A run-time length (CPU6TargetLowering::EmitMemLoop). A zero count skips
// the copy. Otherwise it is MVFR with count-1 in AL, 256 bytes at a time,
// or under optsize a byte loop through AL with post-incremented pointers.
// MEMMOVELOOP compares the pointers first: a destination above the source
// copies from the top down, a byte at a time with pre-decremented pointers.
// MEMSETLOOP stores the byte at dst and copies forward from dst to dst+1,
// which repeats it. A is the count or the byte in flight.
let usesCustomInserter = 1, isPseudo = 1, isCodeGenOnly = 1,
    hasSideEffects = 0, mayLoad = 1, mayStore = 1,
    Defs = [rA, rF, rL, rM, rV] in {
def MEMCPYLOOP : CenturionInst<(outs), (ins GPR:$src, GPR:$dst, GPR:$n),
                               "#MEMCPYLOOP", "$src,$dst,$n">;
def MEMMOVELOOP : CenturionInst<(outs), (ins GPR:$src, GPR:$dst, GPR:$n),
                                "#MEMMOVELOOP", "$src,$dst,$n">;
def MEMSETLOOP : CenturionInst<(outs), (ins GPR:$dst, GPRB:$byte, GPR:$n),
                               "#MEMSETLOOP", "$dst,$byte,$n">;
}
def : Pat<(CPU6memcpyloop GPR:$src, GPR:$dst, GPR:$n),
          (MEMCPYLOOP GPR:$src, GPR:$dst, GPR:$n)>;
def : Pat<(CPU6memmoveloop GPR:$src, GPR:$dst, GPR:$n),
          (MEMMOVELOOP GPR:$src, GPR:$dst, GPR:$n)>;
def : Pat<(CPU6memsetloop GPR:$dst, GPRB:$byte, GPR:$n),
          (MEMSETLOOP GPR:$dst, GPRB:$byte, GPR:$n)>;

//===----------------------------------------------------------------------===//
// Calls
//===----------------------------------------------------------------------===//

def : Pat<(CPU6callseq_start timm:$amt1, timm:$amt2),
          (ADJCALLSTACKDOWN timm:$amt1, timm:$amt2)>;
def : Pat<(CPU6callseq_end timm:$amt1, timm:$amt2),
          (ADJCALLSTACKUP timm:$amt1, timm:$amt2)>;

// Direct JSR. A named function is a target global or an external symbol.
// A numeric address is the same encoding with an immediate.
def : Pat<(CPU6call (i16 tglobaladdr:$dst)), (JSR_1 tglobaladdr:$dst)>;
def : Pat<(CPU6call (i16 texternalsym:$dst)), (JSR_1 texternalsym:$dst)>;
def : Pat<(CPU6call (i16 imm:$dst)), (JSR_1 imm:$dst)>;
// Direct tail call. Indirect stays a JSR: the address register would be
// the one a callee-saved POP in front of the jump reloads.
def : Pat<(CPU6tcret (i16 tglobaladdr:$dst)), (TAILJMP tglobaladdr:$dst)>;
def : Pat<(CPU6tcret (i16 texternalsym:$dst)), (TAILJMP texternalsym:$dst)>;
def : Pat<(CPU6tcret (i16 imm:$dst)), (TAILJMP imm:$dst)>;
// Indirect. webCenREE's indexed form with M' = 0 reads the word register
// and does not modify it. `JSR (X)` encodes as 7D 40.
def : Pat<(CPU6call GPR:$dst), (JSR_5_0 GPR:$dst)>;

//===----------------------------------------------------------------------===//
// Bignum (0x46)
//===----------------------------------------------------------------------===//
//
// Length-1 in the instruction: i32 → 3, i64 → 7, i128 → 15. Addressing:
// *_AA is two address words and *_RR is two registers. bnaddr / bnabs select
// the indexed and mixed forms when the address is not shared. A shared
// address stays a register so its add is emitted once. The indexed
// displacement is a signed byte; eliminateFrameIndex materializes a slot
// that does not fit.
//
// Implemented (combineBignumStore/SetCC and ReplaceNodeResults emit the
// nodes, selected below):
//   ZAD (MOV), BNA (ADD), BNS (SUB), BNC (CMP), ZSU (NEG), M (MUL),
//   D (SDIV), and DRM (SREM; the quotient goes to a stack temporary
//   unless the dividend is already at the destination).
//
// Lengths in use are 4, 8, and 16 bytes (length-1 of 3, 7, and 15).
// If a selected operation writes the wrong bytes, read the microcode-bug
// note in the Bignum section of CPU6InstrInfo.td before changing the fold.
//
// TODO(cpu6): CTB (TOBIN) — ASCII/base string → bignum. Base = llll+2;
// source width in AL. Libc/runtime territory, not IR math.
//
// TODO(cpu6): CFB (FMBIN) — bignum → formatted base string. Op order
// swapped; AL/BL/A control width, pad, and end pointer. Format language
// (@/#) is not expressible as a normal store.

// One pattern per width (length-1 3 is an i32, 7 an i64, 15 an i128) and
// addressing form. The folded forms are more complex than RR, so a frame
// index or a base+disp is not first selected as its own ADD.
multiclass BNPats<SDPatternOperator op, string inst> {
  foreach len = [3, 7, 15] in {
    def : Pat<(op (absaddr abs16:$src), (absaddr abs16:$dst), (i8 len)),
              (!cast<Instruction>(inst # "_AA") (i8 len), (i8 len),
                                                abs16:$src, abs16:$dst)>;
    let AddedComplexity = 8 in {
      def : Pat<(op (bnaddr GPR:$sb, simm8:$sd),
                     (bnaddr GPR:$db, simm8:$dd), (i8 len)),
                (!cast<Instruction>(inst # "_XX") (i8 len), (i8 len),
                 GPR:$sb, simm8:$sd, GPR:$db, simm8:$dd)>;
      def : Pat<(op (bnabs abs16:$src), (bnaddr GPR:$db, simm8:$dd), (i8 len)),
                (!cast<Instruction>(inst # "_AX") (i8 len), (i8 len),
                 abs16:$src, GPR:$db, simm8:$dd)>;
      def : Pat<(op (bnaddr GPR:$sb, simm8:$sd), (bnabs abs16:$dst), (i8 len)),
                (!cast<Instruction>(inst # "_XA") (i8 len), (i8 len),
                 GPR:$sb, simm8:$sd, abs16:$dst)>;
    }
    let AddedComplexity = 4 in {
      def : Pat<(op (bnaddr GPR:$sb, simm8:$sd), GPR:$dst, (i8 len)),
                (!cast<Instruction>(inst # "_XR") (i8 len), (i8 len),
                 GPR:$sb, simm8:$sd, GPR:$dst)>;
      def : Pat<(op GPR:$src, (bnaddr GPR:$db, simm8:$dd), (i8 len)),
                (!cast<Instruction>(inst # "_RX") (i8 len), (i8 len),
                 GPR:$src, GPR:$db, simm8:$dd)>;
      def : Pat<(op (bnabs abs16:$src), GPR:$dst, (i8 len)),
                (!cast<Instruction>(inst # "_AR") (i8 len), (i8 len),
                 abs16:$src, GPR:$dst)>;
      def : Pat<(op GPR:$src, (bnabs abs16:$dst), (i8 len)),
                (!cast<Instruction>(inst # "_RA") (i8 len), (i8 len),
                 GPR:$src, abs16:$dst)>;
    }
    def : Pat<(op GPR:$src, GPR:$dst, (i8 len)),
              (!cast<Instruction>(inst # "_RR") (i8 len), (i8 len),
                                                GPR:$src, GPR:$dst)>;
  }
}

defm : BNPats<CPU6bnmov, "ZAD">;
defm : BNPats<CPU6bnadd, "BNA">;
defm : BNPats<CPU6bnsub, "BNS">;
defm : BNPats<CPU6bnneg, "ZSU">;
defm : BNPats<CPU6bnmul, "M">;
defm : BNPats<CPU6bndiv, "D">;
defm : BNPats<CPU6bndrm, "DRM">;
defm : BNPats<CPU6bncmp, "BNC">;
