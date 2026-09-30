//===-- CPU6ISelLowering.h - CPU6 DAG Lowering Interface --------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// TargetLowering sits between LLVM IR and instruction selection. It decides
// which operations are legal on the CPU and rewrites calls, arguments, and
// returns into CPU6ISD nodes that the patterns in CPU6InstrPatterns.td match.

#ifndef LLVM_LIB_TARGET_CPU6_CPU6ISELLOWERING_H
#define LLVM_LIB_TARGET_CPU6_CPU6ISELLOWERING_H

#include "llvm/CodeGen/SelectionDAG.h"
#include "llvm/CodeGen/SelectionDAGTargetInfo.h"
#include "llvm/CodeGen/TargetLowering.h"

namespace llvm {

class CPU6Subtarget;

namespace CPU6ISD {
enum NodeType : unsigned {
  FIRST_NUMBER = ISD::BUILTIN_OP_END,
  // Chain-carrying return. Optional glue keeps the copies into the return
  // register attached to the RSR. See CPU6retglue in CPU6InstrPatterns.td.
  RET_GLUE,
  // Selects the NOP instruction. See CPU6noop in CPU6InstrPatterns.td.
  NOP,
};
} // namespace CPU6ISD

class CPU6SelectionDAGInfo : public SelectionDAGTargetInfo {
public:
  const char *getTargetNodeName(unsigned Opcode) const override;
};

class CPU6TargetLowering : public TargetLowering {
public:
  explicit CPU6TargetLowering(const TargetMachine &TM,
                              const CPU6Subtarget &STI);

  SDValue LowerFormalArguments(SDValue Chain, CallingConv::ID CallConv,
                               bool IsVarArg,
                               const SmallVectorImpl<ISD::InputArg> &Ins,
                               const SDLoc &DL, SelectionDAG &DAG,
                               SmallVectorImpl<SDValue> &InVals) const override;

  SDValue LowerReturn(SDValue Chain, CallingConv::ID CallConv, bool IsVarArg,
                      const SmallVectorImpl<ISD::OutputArg> &Outs,
                      const SmallVectorImpl<SDValue> &OutVals, const SDLoc &DL,
                      SelectionDAG &DAG) const override;

  SDValue LowerCall(CallLoweringInfo &CLI,
                    SmallVectorImpl<SDValue> &InVals) const override;
};

} // namespace llvm

#endif
