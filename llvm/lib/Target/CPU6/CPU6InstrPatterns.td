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

// `ret i16 42` then becomes XFRimm into the return register, plus RSR.

// TODO(cpu6): add a register and an immediate.
// ADDimm (class DoubleRegImm32 in CPU6InstrInfo.td) already encodes this:
// opcode 0x50, source nibble with its low bit set, destination in the low
// nibble, big-endian imm16. Phire prints `ADD X, X, 0xffec` for `50 54 ff ec`,
// which is dst = src + imm, so the DAG node is (add src, imm) with no tied
// operand. $dst is still an input on that class. Move it to (outs), the same
// way XFRimm was fixed, then select the existing instruction:
//
//   def : Pat<(add GPR:$src, (i16 imm:$imm)), (ADDimm GPR:$src, imm:$imm)>;
//
// Register/register ADD is two-address: `ADD B, X` reads and writes X.
// ADD already defines $arglnibble. Add the tied use on that same def:
//
//   let Constraints = "$arglnibble = $base" in
//   ... (outs GPR:$arglnibble), (ins GPR:$arghnibble, GPR:$base) ...
//   def : Pat<(add GPR:$base, GPR:$arghnibble),
//             (ADD GPR:$arghnibble, GPR:$base)>;
