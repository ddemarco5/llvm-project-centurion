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
// predicates those patterns share, then control, constants, extensions,
// word arithmetic, byte arithmetic, addresses, and calls.
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
def CPU6callseq_start : SDNode<"ISD::CALLSEQ_START", SDT_CPU6CallSeqStart,
                               [SDNPHasChain, SDNPOutGlue]>;
def CPU6callseq_end : SDNode<"ISD::CALLSEQ_END", SDT_CPU6CallSeqEnd,
                             [SDNPHasChain, SDNPOptInGlue, SDNPOutGlue]>;

//===----------------------------------------------------------------------===//
// Predicates and transforms
//===----------------------------------------------------------------------===//

def imm16_0to15 : ImmLeaf<i16, [{ return Imm >= 0 && Imm <= 15; }]>;
def shamt16_1to15 : ImmLeaf<i16, [{ return Imm >= 1 && Imm <= 15; }]>;

// The register/count family is two bytes. The count nibble n means n + 1
// for INR, DCR, SLR and their byte twins, and n itself for CLR and CLRB.
def count_minus1 : SDNodeXForm<imm, [{
  return CurDAG->getTargetConstant(N->getSExtValue() - 1, SDLoc(N), MVT::i8);
}]>;
def neg_count_minus1 : SDNodeXForm<imm, [{
  return CurDAG->getTargetConstant(-N->getSExtValue() - 1, SDLoc(N), MVT::i8);
}]>;
def count_as_i8 : SDNodeXForm<imm, [{
  return CurDAG->getTargetConstant(N->getSExtValue(), SDLoc(N), MVT::i8);
}]>;

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

// IVR ignores its count nibble. SLR r,n shifts left by n + 1.
// The rotates, MUL, and DIV have no patterns. RRR, RLR, RRRB, and RLRB have
// no working handler in webCenREE, and MUL and DIV are decoded as OPM.RRX,
// which throws before any result is computed.
let AddedComplexity = 1 in {
def : Pat<(not GPR:$r), (IVR GPR:$r, 0)>;
def : Pat<(shl GPR:$r, shamt16_1to15:$n), (SLR GPR:$r, (count_minus1 $n))>;
// TODO: confirm whether SRR shifting left is an emulator bug or a microcode
// bug. webCenREE's opf returns src << count, the same direction as SLR, while
// SRA (the one-byte form) is an arithmetic shift right by 1. Same count bias
// as SLR: the nibble n means a shift of n + 1.
//def : Pat<(sra GPR:$r, shamt16_1to15:$n), (SRR GPR:$r, (count_minus1 $n))>;
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

// INRB/DCRB/IVRB/SLRB are two bytes and beat the four-byte word literal
// forms. INRB and DCRB add or subtract n + 1. IVRB has no count. SLRB r,n
// shifts left by n + 1.
let AddedComplexity = 1 in {
def : Pat<(add GPRB:$r, imm8_1to16:$n), (INRB GPRB:$r, (count_minus1 $n))>;
def : Pat<(add GPRB:$r, imm8_m16tom1:$n),
          (DCRB GPRB:$r, (neg_count_minus1 $n))>;
def : Pat<(not GPRB:$r), (IVRB GPRB:$r)>;
def : Pat<(shl GPRB:$r, shamt8_1to7:$n), (SLRB GPRB:$r, (count_minus1 $n))>;
// TODO: confirm whether SRRB shifting left is an emulator bug or a microcode
// bug. webCenREE's opf returns src << count, the same direction as SLRB,
// while SRAB (the one-byte form) is an arithmetic shift right by 1. The
// nibble n means a shift of n + 1. Amounts of 8 and up are poison for i8.
//def : Pat<(sra GPRB:$r, shamt8_1to7:$n), (SRRB GPRB:$r, (count_minus1 $n))>;
}

//===----------------------------------------------------------------------===//
// Addresses
//===----------------------------------------------------------------------===//

// A load or store address is one of two modes (CPU6ISelDAGToDAG.cpp):
//   addr     `(r),disp`, M = 5, M' = 8. A register or a frame index plus a
//            signed byte. eliminateFrameIndex replaces a frame index with S
//            and adds the slot's distance from S to the byte.
//   absaddr  `(addr)`, M = 1. A global, an external symbol, or a number.
// absaddr is tried first. Otherwise addr would take a global as its base and
// load through a register holding the global's address.
def addr : ComplexPattern<i16, 2, "SelectAddr">;
def absaddr : ComplexPattern<i16, 1, "SelectAbsAddr", [globaladdr, externalsym],
                             [], 10>;
// The address itself, S plus a word. Also tried before the add patterns, so
// a slot plus a constant is one ADD.
def frameaddr : ComplexPattern<i16, 2, "SelectFrameAddr", [frameindex, add, or],
                               [], 10>;

// The accumulator loads and stores: LDA/STA move A, LDAB/STAB move AL. The
// assembler records (LDA_5_8, LDA_1, ...) have no result operand, because
// the mnemonic already means A. These are the same encodings with the
// register named, so selection can use them. isCodeGenOnly: the assembler
// keeps parsing `LDA (X),21`.
multiclass AccMemory<bits<4> ldOpc, bits<4> stOpc, RegisterClass RC,
                     ValueType VT> {
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
  // Naming both results of addr fills both operands. `addr:$a` would be one.
  def : Pat<(VT (load (addr GPR:$r, i16imm:$d))),
            (!cast<Instruction>("LD"#NAME#"fi") GPR:$r, i16imm:$d)>;
  def : Pat<(store RC:$src, (addr GPR:$r, i16imm:$d)),
            (!cast<Instruction>("ST"#NAME#"fi") RC:$src, GPR:$r, i16imm:$d)>;
  def : Pat<(VT (load (absaddr abs16:$a))),
            (!cast<Instruction>("LD"#NAME#"abs") abs16:$a)>;
  def : Pat<(store RC:$src, (absaddr abs16:$a)),
            (!cast<Instruction>("ST"#NAME#"abs") RC:$src, abs16:$a)>;
}
// LDAfi, STAfi, LDAabs, STAabs: opcode rows 0x9 and 0xB.
defm A : AccMemory<0x9, 0xB, Acc, i16>;
// LDABfi, STABfi, LDABabs, STABabs: opcode rows 0x8 and 0xA.
defm AB : AccMemory<0x8, 0xA, AccB, i8>;

def : Pat<(frameaddr GPR:$r, i16imm:$d), (ADDimm GPR:$r, i16imm:$d)>;
// XFRimm's immediate is abs16, so a symbol is fixup_cpu6_abs_16.
def : Pat<(absaddr abs16:$a), (XFRimm abs16:$a)>;

// Byte spill and reload. The register allocator can spill any byte register,
// but only AL and BL have byte load/store forms. expandPostRAPseudo turns
// these into LDAB/STAB, moving the byte through AL and keeping AL intact if
// it is live. Operands match LDABfi/STABfi, so eliminateFrameIndex treats
// them alike. They are not selected; storeRegToStackSlot and
// loadRegFromStackSlot emit them.
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
// Indirect. webCenREE's indexed form with M' = 0 reads the word register
// and does not modify it. `JSR (X)` encodes as 7D 40.
def : Pat<(CPU6call GPR:$dst), (JSR_5_0 GPR:$dst)>;
