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

// Return. LowerReturn builds this node; the pattern turns it into RSR.
// SDNPVariadic lets the node also list the physical registers that were copied
// into, which is how the register allocator learns they are live-out.
def CPU6retglue : SDNode<"CPU6ISD::RET_GLUE", SDTNone,
                         [SDNPHasChain, SDNPOptInGlue, SDNPVariadic]>;

// CPU6ISD::NOP has a chain and no value, matching NOP (opcode 0x01).
def CPU6noop : SDNode<"CPU6ISD::NOP", SDTNone, [SDNPHasChain]>;
def : Pat<(CPU6noop), (NOP)>;

// Select the return node LowerReturn builds. RSR is marked isReturn,
// isTerminator, and isBarrier in CPU6InstrInfo.td.
def : Pat<(CPU6retglue), (RSR)>;

// An i16 constant selects the same XFRimm the assembler parses.
def : Pat<(i16 imm:$imm), (XFRimm imm:$imm)>;

// Mode-2 ADD writes $dst, so the pattern names only the two inputs.
def : Pat<(add GPR:$src, (i16 imm:$imm)), (ADDimm GPR:$src, imm:$imm)>;

// Register/register ADD is two-address: `ADD B, X` reads and writes X.
// ADD already defines $arglnibble. Add the tied use on that same def:
//
//   let Constraints = "$arglnibble = $base" in
//   ... (outs GPR:$arglnibble), (ins GPR:$arghnibble, GPR:$base) ...
//   def : Pat<(add GPR:$base, GPR:$arghnibble),
//             (ADD GPR:$arghnibble, GPR:$base)>;

// STK and POP are not selected here. A Pat matches one DAG node, and nothing
// in the DAG means "save whichever of X, Y, Z this function clobbers."
// That set is CSR in CPU6CallingConv.td. The prologue inserter asks
// CPU6FrameLowering::spillCalleeSavedRegisters, which emits one STK per
// contiguous stretch of X, Y, Z and a matching POP in front of RSR. Same
// split as MSP430 PUSH/POP.

// Frame index -> target frame index, so a displacement operand can hold the
// slot until eliminateFrameIndex writes the offset from S.
def to_tframeindex : SDNodeXForm<frameindex, [{
  return CurDAG->getTargetFrameIndex(N->getIndex(), N->getValueType(0));
}]>;

// `LDA (S),disp` / `STA (S),disp`. M = 5, M' = 8: base plus a displacement
// byte, direct. The assembler records (LDA_5_8, STA_5_8) have no result
// operand, because the mnemonic already means A. These are that encoding
// with A named, so a load or store of a frame slot can select them.
// isCodeGenOnly: the assembler keeps parsing `LDA (X),21`.
let isCodeGenOnly = 1, hasSideEffects = 0, mayLoad = 1, mayStore = 0 in
def LDAfi : Memory24Index<0x9, 0x8, (outs Acc:$dst), (ins GPR:$r, i16imm:$arg),
                          "LDA", "(${r}),$arg">;
let isCodeGenOnly = 1, hasSideEffects = 0, mayLoad = 0, mayStore = 1 in
def STAfi : Memory24Index<0xB, 0x8, (outs), (ins Acc:$src, GPR:$r, i16imm:$arg),
                          "STA", "(${r}),$arg">;

// The address of an alloca is a FrameIndex. S is the base; the displacement
// is filled in after the frame layout is known.
def : Pat<(i16 (load (frameindex:$fi))),
          (LDAfi (i16 rS), (to_tframeindex $fi))>;
def : Pat<(store Acc:$src, (frameindex:$fi)),
          (STAfi Acc:$src, (i16 rS), (to_tframeindex $fi))>;

// Word ALU with a literal. Mode 2 writes dst = src op imm, except SUB, which
// is dst = imm - src.
def : Pat<(sub (i16 imm:$imm), GPR:$src), (SUBimm GPR:$src, imm:$imm)>;
def : Pat<(and GPR:$src, (i16 imm:$imm)), (ANDimm GPR:$src, imm:$imm)>;
def : Pat<(or GPR:$src, (i16 imm:$imm)), (ORIimm GPR:$src, imm:$imm)>;
def : Pat<(xor GPR:$src, (i16 imm:$imm)), (OREimm GPR:$src, imm:$imm)>;

//===----------------------------------------------------------------------===//
// Bytes
//===----------------------------------------------------------------------===//

// `LDAB (S),disp` / `STAB (S),disp`: the byte twins of LDAfi/STAfi, opcode
// rows 0x8 and 0xA with the same M = 5, M' = 8 index byte. The base is still
// a word register; only the data is a byte, and it is always AL.
let isCodeGenOnly = 1, hasSideEffects = 0, mayLoad = 1, mayStore = 0 in
def LDABfi : Memory24Index<0x8, 0x8, (outs AccB:$dst), (ins GPR:$r, i16imm:$arg),
                           "LDAB", "(${r}),$arg">;
let isCodeGenOnly = 1, hasSideEffects = 0, mayLoad = 0, mayStore = 1 in
def STABfi : Memory24Index<0xA, 0x8, (outs), (ins AccB:$src, GPR:$r, i16imm:$arg),
                           "STAB", "(${r}),$arg">;

def : Pat<(i8 (load (frameindex:$fi))),
          (LDABfi (i16 rS), (to_tframeindex $fi))>;
def : Pat<(store AccB:$src, (frameindex:$fi)),
          (STABfi AccB:$src, (i16 rS), (to_tframeindex $fi))>;

// Byte spill and reload. The register allocator can spill any byte register,
// but only AL and BL have byte load/store forms. expandPostRAPseudo turns
// these into LDAB/STAB, moving the byte through AL and keeping AL intact if
// it is live. Operands match LDABfi/STABfi so eliminateFrameIndex treats them
// alike.
let isPseudo = 1, isCodeGenOnly = 1, hasSideEffects = 0 in {
let mayLoad = 0, mayStore = 1 in
def SPILLB : CenturionInst<(outs), (ins GPRB:$src, GPR:$r, i16imm:$arg),
                           "#SPILLB", "$src,(${r}),$arg">;
let mayLoad = 1, mayStore = 0 in
def RELOADB : CenturionInst<(outs GPRB:$dst), (ins GPR:$r, i16imm:$arg),
                            "#RELOADB", "(${r}),$dst,$arg">;
}

// An i8 literal as the i16 operand of a word instruction. Only the low byte
// of the result is used, so sign- or zero-extending makes no difference.
def imm8_as_16 : SDNodeXForm<imm, [{
  return CurDAG->getTargetConstant(N->getSExtValue(), SDLoc(N), MVT::i16);
}]>;

// A byte in the low half of an otherwise undefined word. REG_SEQUENCE, not
// INSERT_SUBREG into IMPLICIT_DEF: at -O0 nothing marks that IMPLICIT_DEF
// undef, so the word looks live above the insert and pins A while AL is
// still needed for the byte. REG_SEQUENCE writes sub_lo as a fresh def.
defvar ByteInWord = (REG_SEQUENCE GPR, GPRB:$src, sub_lo,
                                  (i8 (IMPLICIT_DEF)), sub_hi);
def : Pat<(i16 (anyext GPRB:$src)), ByteInWord>;
def : Pat<(i8 (trunc GPR:$src)), (EXTRACT_SUBREG GPR:$src, sub_lo)>;

// There is no byte literal form outside AL and BL, so a byte constant is the
// low half of a word XFR.
def : Pat<(i8 imm:$imm),
          (EXTRACT_SUBREG (XFRimm (imm8_as_16 imm:$imm)), sub_lo)>;

// Byte ALU with a literal: run the word op on the containing register and
// keep the low byte. The carry out of bit 7 lands in the upper half, which
// nothing reads.
class ByteImmPat<SDNode op, Instruction inst>
    : Pat<(op GPRB:$src, (i8 imm:$imm)),
          (EXTRACT_SUBREG (inst ByteInWord, (imm8_as_16 imm:$imm)), sub_lo)>;
def : ByteImmPat<add, ADDimm>;
def : ByteImmPat<and, ANDimm>;
def : ByteImmPat<or, ORIimm>;
def : ByteImmPat<xor, OREimm>;

// SUB's literal form is dst = imm - src, which is a constant minus a byte.
def : Pat<(sub (i8 imm:$imm), GPRB:$src),
          (EXTRACT_SUBREG (SUBimm ByteInWord, (imm8_as_16 imm:$imm)), sub_lo)>;

// The register/count family is two bytes and works on any byte register.
// The count nibble n means n + 1 for INRB, DCRB and SLRB, and n itself for
// CLRB. These beat the four-byte word literal forms above.
def imm8_1to16 : ImmLeaf<i8, [{ return Imm >= 1 && Imm <= 16; }]>;
def imm8_m16tom1 : ImmLeaf<i8, [{ return Imm >= -16 && Imm <= -1; }]>;
def imm8_0to15 : ImmLeaf<i8, [{ return Imm >= 0 && Imm <= 15; }]>;
// i8 shift amounts are i16, the pointer width. 8 and up are poison.
def shamt8_1to7 : ImmLeaf<i16, [{ return Imm >= 1 && Imm <= 7; }]>;
def count_minus1 : SDNodeXForm<imm, [{
  return CurDAG->getTargetConstant(N->getSExtValue() - 1, SDLoc(N), MVT::i8);
}]>;
def neg_count_minus1 : SDNodeXForm<imm, [{
  return CurDAG->getTargetConstant(-N->getSExtValue() - 1, SDLoc(N), MVT::i8);
}]>;

let AddedComplexity = 1 in {
def : Pat<(add GPRB:$r, imm8_1to16:$n), (INRB GPRB:$r, (count_minus1 $n))>;
def : Pat<(add GPRB:$r, imm8_m16tom1:$n),
          (DCRB GPRB:$r, (neg_count_minus1 $n))>;
def : Pat<(i8 imm8_0to15:$n), (CLRB imm:$n)>;
def : Pat<(not GPRB:$r), (IVRB GPRB:$r)>;
def : Pat<(shl GPRB:$r, shamt8_1to7:$n), (SLRB GPRB:$r, (count_minus1 $n))>;
}

// Byte register/register ALU. The first operand is the source nibble, the
// second is the destination nibble's incoming value.
def : Pat<(add GPRB:$a, GPRB:$b), (ADDB GPRB:$a, GPRB:$b)>;
def : Pat<(and GPRB:$a, GPRB:$b), (ANDB GPRB:$a, GPRB:$b)>;
def : Pat<(or GPRB:$a, GPRB:$b), (ORIB GPRB:$a, GPRB:$b)>;
def : Pat<(xor GPRB:$a, GPRB:$b), (OREB GPRB:$a, GPRB:$b)>;
// SUBB is dst = src - dst, so a - b keeps b in the destination.
def : Pat<(sub GPRB:$a, GPRB:$b), (SUBB GPRB:$a, GPRB:$b)>;

// Extension. No instruction does it, so zext clears the upper half with AND,
// and sext rebuilds bit 7 across the word: ((x & 0xff) ^ 0x80) - 0x80.
def : Pat<(i16 (zext GPRB:$src)), (ANDimm ByteInWord, 255)>;
def : Pat<(sext_inreg GPR:$src, i8),
          (ADDimm (OREimm (ANDimm GPR:$src, 255), 128), -128)>;
def : Pat<(i16 (sext GPRB:$src)),
          (ADDimm (OREimm (ANDimm ByteInWord, 255), 128), -128)>;
