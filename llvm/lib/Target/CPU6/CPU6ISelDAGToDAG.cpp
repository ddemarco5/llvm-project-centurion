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
//
// The Select*Addr functions below are the ComplexPatterns that file uses for
// addresses, the same split RISC-V makes between SelectAddrRegImm and
// SelectFrameAddrRegImm.

#include "CPU6.h"
#include "CPU6TargetMachine.h"
#include "MCTargetDesc/CPU6MCTargetDesc.h"
#include "llvm/CodeGen/SelectionDAGISel.h"
#include "llvm/Support/MathExtras.h"

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

  void splitBaseOffset(SDValue N, SDValue &Base, SDValue &Disp, unsigned Bits);
  bool SelectAddr(SDValue N, SDValue &Base, SDValue &Disp);
  bool SelectFrameAddr(SDValue N, SDValue &Base, SDValue &Disp);
  bool SelectAbsAddr(SDValue N, SDValue &Addr);
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

  // A node TableGen patterns cannot express goes in a switch on getOpcode()
  // before this call.
  switch (Node->getOpcode()) {
  case CPU6ISD::BR_CC:
    // (chain, block, branch opcode, glue) becomes that branch.
    CurDAG->SelectNodeTo(Node, Node->getConstantOperandVal(2), MVT::Other,
                         {Node->getOperand(1), Node->getOperand(0),
                          Node->getOperand(3)});
    return;
  }
  SelectCode(Node);
}

// Base plus a constant that fits in Bits. A constant that does not fit stays
// in the base, which is then selected as an add. A frame index becomes the
// target node eliminateFrameIndex replaces with S or X.
void CPU6DAGToDAGISel::splitBaseOffset(SDValue N, SDValue &Base,
                                       SDValue &Disp, unsigned Bits) {
  int64_t Off = 0;
  if (CurDAG->isBaseWithConstantOffset(N)) {
    int64_t C = cast<ConstantSDNode>(N.getOperand(1))->getSExtValue();
    if (isIntN(Bits, C)) {
      Off = C;
      N = N.getOperand(0);
    }
  }
  if (auto *FI = dyn_cast<FrameIndexSDNode>(N))
    Base = CurDAG->getTargetFrameIndex(FI->getIndex(), MVT::i16);
  else
    Base = N;
  Disp = CurDAG->getSignedTargetConstant(Off, SDLoc(N), MVT::i16);
}

// `(r),disp`. lea_mod in webCenREE sign-extends the displacement byte.
bool CPU6DAGToDAGISel::SelectAddr(SDValue N, SDValue &Base, SDValue &Disp) {
  splitBaseOffset(N, Base, Disp, 8);
  return true;
}

// The address of a slot: S plus a word. Only a frame index is this; any
// other add is the ordinary add-immediate pattern.
bool CPU6DAGToDAGISel::SelectFrameAddr(SDValue N, SDValue &Base,
                                       SDValue &Disp) {
  splitBaseOffset(N, Base, Disp, 16);
  return Base.getOpcode() == ISD::TargetFrameIndex;
}

// The direct form's address word. A constant added to a global is already
// in the node's offset; getNode folds it.
bool CPU6DAGToDAGISel::SelectAbsAddr(SDValue N, SDValue &Addr) {
  if (auto *G = dyn_cast<GlobalAddressSDNode>(N))
    Addr = CurDAG->getTargetGlobalAddress(G->getGlobal(), SDLoc(N), MVT::i16,
                                          G->getOffset());
  else if (auto *E = dyn_cast<ExternalSymbolSDNode>(N))
    Addr = CurDAG->getTargetExternalSymbol(E->getSymbol(), MVT::i16);
  else if (auto *B = dyn_cast<BlockAddressSDNode>(N))
    Addr = CurDAG->getTargetBlockAddress(B->getBlockAddress(), MVT::i16,
                                         B->getOffset());
  else if (auto *C = dyn_cast<ConstantSDNode>(N))
    Addr = CurDAG->getTargetConstant(C->getZExtValue(), SDLoc(N), MVT::i16);
  else
    return false;
  return true;
}
