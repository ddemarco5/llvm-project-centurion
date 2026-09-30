//===-- CPU6.h - Top-level interface for CPU6 codegen -----------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef LLVM_LIB_TARGET_CPU6_CPU6_H
#define LLVM_LIB_TARGET_CPU6_CPU6_H

#include "llvm/CodeGen/MachineFunctionAnalysisManager.h"
#include "llvm/CodeGen/SelectionDAGISel.h"
#include "llvm/IR/PassManager.h"
#include "llvm/Pass.h"

namespace llvm {

class CPU6TargetMachine;
class FunctionPass;
class PassRegistry;

class CPU6ISelDAGToDAGPass : public SelectionDAGISelPass {
public:
  CPU6ISelDAGToDAGPass(CPU6TargetMachine &TM, CodeGenOptLevel OptLevel);
};

FunctionPass *createCPU6ISelDag(CPU6TargetMachine &TM, CodeGenOptLevel OptLevel);

void initializeCPU6DAGToDAGISelLegacyPass(PassRegistry &);

} // namespace llvm

#endif
