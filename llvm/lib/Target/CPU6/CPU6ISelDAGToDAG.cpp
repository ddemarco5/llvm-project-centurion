//===-- CPU6ISelDAGToDAG.cpp - CPU6 instruction selector ---------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// Select() is the instruction selector. Nodes that are already machine opcodes
// are left alone. Everything else goes to SelectCode, which TableGen builds
// from CPU6InstrPatterns.td. A miss prints "Cannot select:" and the DAG node.

#include "CPU6.h"
#include "CPU6TargetMachine.h"
#include "MCTargetDesc/CPU6MCTargetDesc.h"
#include "llvm/CodeGen/SelectionDAGISel.h"

using namespace llvm;

#define DEBUG_TYPE "cpu6-isel"
#define PASS_NAME "CPU6 DAG->DAG Pattern Instruction Selection"

namespace {

class CPU6DAGToDAGISel : public SelectionDAGISel {
public:
  CPU6DAGToDAGISel(CPU6TargetMachine &TM, CodeGenOptLevel OptLevel)
      : SelectionDAGISel(TM, OptLevel) {}

private:
#include "CPU6GenDAGISel.inc"

  void Select(SDNode *Node) override;
};

class CPU6DAGToDAGISelLegacy : public SelectionDAGISelLegacy {
public:
  static char ID;
  CPU6DAGToDAGISelLegacy(CPU6TargetMachine &TM, CodeGenOptLevel OptLevel)
      : SelectionDAGISelLegacy(ID,
                               std::make_unique<CPU6DAGToDAGISel>(TM, OptLevel)) {}
};

} // namespace

char CPU6DAGToDAGISelLegacy::ID = 0;

INITIALIZE_PASS(CPU6DAGToDAGISelLegacy, DEBUG_TYPE, PASS_NAME, false, false)

FunctionPass *llvm::createCPU6ISelDag(CPU6TargetMachine &TM,
                                      CodeGenOptLevel OptLevel) {
  return new CPU6DAGToDAGISelLegacy(TM, OptLevel);
}

CPU6ISelDAGToDAGPass::CPU6ISelDAGToDAGPass(CPU6TargetMachine &TM,
                                           CodeGenOptLevel OptLevel)
    : SelectionDAGISelPass(std::make_unique<CPU6DAGToDAGISel>(TM, OptLevel)) {}

void CPU6DAGToDAGISel::Select(SDNode *Node) {
  // Already a machine instruction (for example a node emitted by custom
  // lowering). Nothing to match.
  if (Node->isMachineOpcode()) {
    Node->setNodeId(-1);
    return;
  }

  // TODO(cpu6): nodes that TableGen patterns cannot express go in a switch
  // on Node->getOpcode() before this call. Frame indexes are the usual first
  // one, and the first tests do not have any.
  SelectCode(Node);
}
