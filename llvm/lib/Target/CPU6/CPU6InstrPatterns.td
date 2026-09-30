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
// The assembler defs in CPU6InstrInfo.td describe the text the parser sees.
// Selection needs a different view of the same encoding: every register the
// instruction defines belongs in (outs), every register it reads belongs in
// (ins). isCodeGenOnly keeps that view out of the assembler and disassembler,
// so the MC tests stay pointed at XFRimm / ADD / ADDimm.

// Return. LowerReturn builds this node; the pattern turns it into RSR.
// SDNPVariadic lets the node also list the physical registers that were copied
// into, which is how the register allocator learns they are live-out.
def CPU6retglue : SDNode<"CPU6ISD::RET_GLUE", SDTNone,
                         [SDNPHasChain, SDNPOptInGlue, SDNPVariadic]>;

// MSVC rejects the generated matcher when it has no patterns (a zero-length
// array). Nothing in the DAG produces CPU6ISD::NOP, so this does not select
// any real instruction. Delete it once a real pattern, such as the RSR
// pattern below, is added.
def SDT_CPU6Nop : SDTypeProfile<1, 1, [SDTCisSameAs<0, 1>, SDTCisVT<0, i16>]>;
def CPU6noop : SDNode<"CPU6ISD::NOP", SDT_CPU6Nop, []>;
def : Pat<(CPU6noop GPR:$src), (XFR GPR:$src)>;

// TODO(cpu6): mark RSR as a return, then match the node.
//
// In CPU6InstrInfo.td the RSR line wants to be wrapped as:
//
//   let isReturn = 1, isTerminator = 1, isBarrier = 1 in
//   def RSR : Control<0x09, "RSR">;
//
// isTerminator + isBarrier tell the machine verifier that control does not
// fall out of the block. isReturn tells the prologue/epilogue pass that this
// is the function's exit.
//
// Then select it:
//
//   def : Pat<(CPU6retglue), (RSR)>;

// TODO(cpu6): load a 16-bit immediate. Copy the XFRimm encoding, but put $dst
// in (outs) so the instruction defines a register. Same bit layout as
// XFRImm32 in CPU6InstrInfo.td (opcode 0x55, low bit of the source nibble
// forced to 1, destination in both nibbles, big-endian imm16).
//
//   let isCodeGenOnly = 1, hasSideEffects = 0, mayLoad = 0, mayStore = 0,
//       isMoveImm = 1, isAsCheapAsAMove = 1 in
//   def LI16 : CenturionInst32<(outs GPR:$dst), (ins i16imm:$imm),
//                              "XFR", "$dst,$imm"> {
//     bits<4> dst;
//     bits<16> imm;
//     let Inst{31-24} = 0x55;
//     let Inst{23} = dst{3};
//     let Inst{22} = dst{2};
//     let Inst{21} = dst{1};
//     let Inst{20} = 1;
//     let Inst{19} = dst{3};
//     let Inst{18} = dst{2};
//     let Inst{17} = dst{1};
//     let Inst{16} = dst{0};
//     let Inst{15-0} = imm;
//   }
//
//   def : Pat<(i16 imm:$imm), (LI16 imm:$imm)>;
//
// `ret i16 42` then becomes LI16 into the return register, plus RSR.

// TODO(cpu6): add a register and an immediate.
// Phire prints `ADD X, X, 0xffec` for `50 54 ff ec`: destination and source
// are independent registers, and the immediate is the other addend. That is
// "dst = src + imm", which matches SelectionDAG's (add src, imm) without a
// tied operand. Confirm that against the EE200 description before relying on
// it. ADDimm in CPU6InstrInfo.td has the encoding (opcode 0x50, low bit of
// the source nibble set, destination in the low nibble, big-endian imm16)
// but both registers are inputs, so it cannot be a pattern result.
//
//   let isCodeGenOnly = 1, hasSideEffects = 0, mayLoad = 0, mayStore = 0 in
//   def ADDri : CenturionInst32<(outs GPR:$dst), (ins GPR:$src, i16imm:$imm),
//                               "ADD", "$src,$dst,$imm"> {
//     bits<4> src;
//     bits<4> dst;
//     bits<16> imm;
//     let Inst{31-24} = 0x50;
//     let Inst{23} = src{3};
//     let Inst{22} = src{2};
//     let Inst{21} = src{1};
//     let Inst{20} = 1;
//     let Inst{19-16} = dst;
//     let Inst{15-0} = imm;
//   }
//
//   def : Pat<(add GPR:$src, (i16 imm:$imm)), (ADDri GPR:$src, imm:$imm)>;
//
// Register/register ADD is two-address on this CPU: the destination is also
// a source (`ADD B, X` updates X). The assembler def does not list that use.
// When you get there, a codegen def needs the tie:
//
//   let Constraints = "$dst = $base", isCodeGenOnly = 1 in
//   def ADDrr : ... (outs GPR:$dst), (ins GPR:$src, GPR:$base) ...
//   def : Pat<(add GPR:$base, GPR:$src), (ADDrr GPR:$src, GPR:$base)>;
