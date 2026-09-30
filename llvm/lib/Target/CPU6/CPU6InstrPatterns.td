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
