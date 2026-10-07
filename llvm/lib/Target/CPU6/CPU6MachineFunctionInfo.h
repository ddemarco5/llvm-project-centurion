//===-- CPU6MachineFunctionInfo.h - CPU6 machine function info ---*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// Per-function facts the rest of codegen has to remember. Today that is the
// frame index va_start writes into the va_list, and two far spill slots used
// when a bignum indexed operand does not fit in a signed byte.

#ifndef LLVM_LIB_TARGET_CPU6_CPU6MACHINEFUNCTIONINFO_H
#define LLVM_LIB_TARGET_CPU6_CPU6MACHINEFUNCTIONINFO_H

#include "llvm/CodeGen/MachineFunction.h"

namespace llvm {

class CPU6FunctionInfo : public MachineFunctionInfo {
  // Fixed object covering the first variadic word. Fixed objects are
  // negative indices, so -1 is a real slot and cannot mean "unset".
  int VarArgsFrameIndex = 0;
  bool HasVarArgsFrameIndex = false;
  // Ordinary spill objects, ordered with the far frame objects. -1 if this
  // function's indexed bignum slots all fit in a signed byte.
  int BignumScratchSlot[2] = {-1, -1};

public:
  CPU6FunctionInfo(const Function &F, const TargetSubtargetInfo *STI) {}

  MachineFunctionInfo *
  clone(BumpPtrAllocator &Allocator, MachineFunction &DestMF,
        const DenseMap<MachineBasicBlock *, MachineBasicBlock *> &Src2DstMBB)
      const override {
    return DestMF.cloneInfo<CPU6FunctionInfo>(*this);
  }

  void setVarArgsFrameIndex(int FI) {
    VarArgsFrameIndex = FI;
    HasVarArgsFrameIndex = true;
  }
  int getVarArgsFrameIndex() const { return VarArgsFrameIndex; }
  bool hasVarArgsFrameIndex() const { return HasVarArgsFrameIndex; }

  void setBignumScratchSlots(int A, int B) {
    BignumScratchSlot[0] = A;
    BignumScratchSlot[1] = B;
  }
  int getBignumScratchSlot(unsigned I) const { return BignumScratchSlot[I]; }
};

} // namespace llvm

#endif
