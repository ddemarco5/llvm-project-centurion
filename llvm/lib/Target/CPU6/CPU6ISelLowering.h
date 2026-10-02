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
  // Direct or indirect JSR. Glue keeps the argument copies on the call.
  // See CPU6call in CPU6InstrPatterns.td.
  CALL,
  // Direct JMP in return position. The epilogue restores S and X first, so
  // the callee's RSR returns to this function's caller. See CPU6tcret.
  TC_RETURN,
  // Flag-setting compares and their two readers. See CPU6cmp, CPU6tst,
  // CPU6brcc, and CPU6selectcc in CPU6InstrPatterns.td.
  CMP,
  TST,
  BR_CC,
  SELECT_CC,
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

  // There is no GOT and no position-independent code, so every global is at
  // an absolute address and `g + 4` is one relocation with an addend. The
  // default only folds globals marked dso_local.
  bool isOffsetFoldingLegal(const GlobalAddressSDNode *) const override {
    return true;
  }

  SDValue LowerOperation(SDValue Op, SelectionDAG &DAG) const override;

  MachineBasicBlock *
  EmitInstrWithCustomInserter(MachineInstr &MI,
                              MachineBasicBlock *BB) const override;

private:
  SDValue LowerCallResult(SDValue Chain, SDValue InGlue, CallingConv::ID CallConv,
                          bool IsVarArg, const SmallVectorImpl<ISD::InputArg> &Ins,
                          const SDLoc &DL, SelectionDAG &DAG,
                          SmallVectorImpl<SDValue> &InVals) const;
};

} // namespace llvm

#endif
