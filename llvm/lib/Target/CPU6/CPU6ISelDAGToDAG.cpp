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
#include "llvm/IR/InlineAsm.h"
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

  bool SelectInlineAsmMemoryOperand(const SDValue &Op,
                                    InlineAsm::ConstraintCode ConstraintID,
                                    std::vector<SDValue> &OutOps) override;

  void splitBaseOffset(SDValue N, SDValue &Base, SDValue &Disp, unsigned Bits);
  bool SelectAddr(SDValue N, SDValue &Base, SDValue &Disp);
  bool SelectBignumAddr(SDValue N, SDValue &Base, SDValue &Disp);
  bool SelectBignumAbs(SDValue N, SDValue &Addr);
  bool SelectBlkAbs(SDValue N, SDValue &Addr);
  bool SelectBlkIdx(SDValue N, SDValue &Base, SDValue &Disp);
  bool SelectBlkFrame(SDValue N, SDValue &Base, SDValue &Disp);
  bool SelectFrameAddr(SDValue N, SDValue &Base, SDValue &Disp);
  bool SelectAbsAddr(SDValue N, SDValue &Addr);
  bool selectIndexedMem(SDNode *Node);
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
  case CPU6ISD::WSHIFT: {
    // One result per word, low first, then the count and the direction.
    // WSHIFT2, WSHIFT4, and WSHIFT8 are the same loop; only the operand
    // count differs.
    unsigned N = Node->getNumValues();
    unsigned Opc = N == 8 ? CPU6::WSHIFT8 : N == 4 ? CPU6::WSHIFT4 : CPU6::WSHIFT2;
    SmallVector<SDValue, 8> Ops;
    for (unsigned I = 0, E = Node->getNumOperands(); I != E; ++I)
      Ops.push_back(Node->getOperand(I));
    SmallVector<EVT, 4> VTs(N, MVT::i16);
    CurDAG->SelectNodeTo(Node, Opc, CurDAG->getVTList(VTs), Ops);
    return;
  }
  case ISD::LOAD:
  case ISD::STORE:
    if (selectIndexedMem(Node))
      return;
    break;
  }
  SelectCode(Node);
}

// POST_INC / PRE_DEC became a load or store whose offset is the access size.
// The data register is chosen after register allocation; the pseudo only
// names it. An indexed node that is not one of those strides is a bug in the
// address hook, and SelectCode then reports it.
bool CPU6DAGToDAGISel::selectIndexedMem(SDNode *Node) {
  const LSBaseSDNode *Mem = dyn_cast<LSBaseSDNode>(Node);
  if (!Mem || !Mem->isIndexed())
    return false;
  ISD::MemIndexedMode AM = Mem->getAddressingMode();
  if (AM != ISD::POST_INC && AM != ISD::PRE_DEC)
    return false;

  const auto *Off = dyn_cast<ConstantSDNode>(Mem->getOffset());
  if (!Off)
    return false;
  const int64_t Step = Off->getSExtValue();
  const bool Pre = AM == ISD::PRE_DEC;
  const EVT VT = Mem->getMemoryVT();

  unsigned Opc = 0;
  if (auto *LD = dyn_cast<LoadSDNode>(Node)) {
    if (LD->getExtensionType() != ISD::NON_EXTLOAD)
      return false;
    if (VT == MVT::i16 && Step == (Pre ? -2 : 2))
      Opc = Pre ? CPU6::LDW_PRE : CPU6::LDW_POST;
    else if (VT == MVT::i8 && Step == (Pre ? -1 : 1))
      Opc = Pre ? CPU6::LDB_PRE : CPU6::LDB_POST;
    else
      return false;
    SDNode *Res = CurDAG->getMachineNode(Opc, SDLoc(LD), LD->getValueType(0),
                                         MVT::i16, MVT::Other, LD->getBasePtr(),
                                         LD->getChain());
    MachineMemOperand *MMO = LD->getMemOperand();
    CurDAG->setNodeMemRefs(cast<MachineSDNode>(Res), {MMO});
    Res->setNodeId(-1);
    ReplaceUses(LD, Res);
    CurDAG->RemoveDeadNode(LD);
    return true;
  }

  auto *ST = cast<StoreSDNode>(Node);
  if (ST->isTruncatingStore())
    return false;
  if (VT == MVT::i16 && Step == (Pre ? -2 : 2))
    Opc = Pre ? CPU6::STW_PRE : CPU6::STW_POST;
  else if (VT == MVT::i8 && Step == (Pre ? -1 : 1))
    Opc = Pre ? CPU6::STB_PRE : CPU6::STB_POST;
  else
    return false;
  SDNode *Res = CurDAG->getMachineNode(Opc, SDLoc(ST), MVT::i16, MVT::Other,
                                       ST->getBasePtr(), ST->getValue(),
                                       ST->getChain());
  MachineMemOperand *MMO = ST->getMemOperand();
  CurDAG->setNodeMemRefs(cast<MachineSDNode>(Res), {MMO});
  Res->setNodeId(-1);
  ReplaceUses(ST, Res);
  CurDAG->RemoveDeadNode(ST);
  return true;
}

// "m" uses the same address match as a load. A symbol is `(addr)`. Anything
// else is SelectAddr's `(r),disp`, and eliminateFrameIndex fills in a slot.
bool CPU6DAGToDAGISel::SelectInlineAsmMemoryOperand(
    const SDValue &Op, InlineAsm::ConstraintCode ConstraintID,
    std::vector<SDValue> &OutOps) {
  if (ConstraintID != InlineAsm::ConstraintCode::m &&
      ConstraintID != InlineAsm::ConstraintCode::o)
    return true;

  SDValue Base, Disp;
  if (SelectAbsAddr(Op, Base)) {
    OutOps.push_back(Base);
    return false;
  }
  SelectAddr(Op, Base, Disp);
  OutOps.push_back(Base);
  OutOps.push_back(Disp);
  return false;
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

// True when every use of this value is the same node. A bignum address used
// by two instructions stays in a register: folding it into each instruction
// repeats the displacement and the add was smaller.
static bool onlyUsedByOneNode(const SDNode *N) {
  const SDNode *User = nullptr;
  for (const SDNode *U : N->users()) {
    if (!User)
      User = U;
    else if (U != User)
      return false;
  }
  return User != nullptr;
}

static bool isAddressWord(SDValue N) {
  switch (N.getOpcode()) {
  case ISD::GlobalAddress:
  case ISD::ExternalSymbol:
  case ISD::BlockAddress:
  case ISD::Constant:
  case ISD::TargetGlobalAddress:
  case ISD::TargetExternalSymbol:
  case ISD::TargetBlockAddress:
  case ISD::TargetConstant:
    return true;
  default:
    return false;
  }
}

// Indexed bignum operand: a frame index, or a register plus a nonzero signed
// byte. The frame offset is filled in by eliminateFrameIndex. A bare register
// stays the register form, which is two bytes shorter than an index of 0.
// The displacement the pattern sees is an i8, matching simm8 on the encoding.
bool CPU6DAGToDAGISel::SelectBignumAddr(SDValue N, SDValue &Base,
                                        SDValue &Disp) {
  if (!onlyUsedByOneNode(N.getNode()))
    return false;

  SDLoc DL(N);
  int64_t Off = 0;
  bool Folded = false;
  if (CurDAG->isBaseWithConstantOffset(N)) {
    int64_t C = cast<ConstantSDNode>(N.getOperand(1))->getSExtValue();
    if (isInt<8>(C)) {
      Off = C;
      N = N.getOperand(0);
      Folded = true;
    }
  }
  if (auto *FI = dyn_cast<FrameIndexSDNode>(N)) {
    Base = CurDAG->getTargetFrameIndex(FI->getIndex(), MVT::i16);
    Disp = CurDAG->getSignedTargetConstant(Off, DL, MVT::i8);
    return true;
  }
  // add %p, 0 is %p. An address word is the absolute form, not an index.
  if (!Folded || Off == 0 || isAddressWord(N))
    return false;
  Base = N;
  Disp = CurDAG->getSignedTargetConstant(Off, DL, MVT::i8);
  return true;
}

// Absolute bignum operand, and only when this instruction is its only user.
// A global used again is loaded once and shared. AA does not use this: two
// address words are still smaller than materializing both.
bool CPU6DAGToDAGISel::SelectBignumAbs(SDValue N, SDValue &Addr) {
  if (!onlyUsedByOneNode(N.getNode()))
    return false;
  return SelectAbsAddr(N, Addr);
}

// Absolute block-move operand. Same single-use rule as a bignum address: a
// global that is loaded again stays in a register and is shared.
bool CPU6DAGToDAGISel::SelectBlkAbs(SDValue N, SDValue &Addr) {
  return SelectBignumAbs(N, Addr);
}

// Register plus a nonzero signed byte. A frame index is SelectBlkFrame, and
// only on forms that can widen to a 16-bit displacement. A bare register and
// an address word stay the register and absolute forms.
bool CPU6DAGToDAGISel::SelectBlkIdx(SDValue N, SDValue &Base, SDValue &Disp) {
  if (!onlyUsedByOneNode(N.getNode()))
    return false;

  SDLoc DL(N);
  int64_t Off = 0;
  bool Folded = false;
  if (CurDAG->isBaseWithConstantOffset(N)) {
    int64_t C = cast<ConstantSDNode>(N.getOperand(1))->getSExtValue();
    if (isInt<8>(C)) {
      Off = C;
      N = N.getOperand(0);
      Folded = true;
    }
  }
  if (isa<FrameIndexSDNode>(N))
    return false;
  if (!Folded || Off == 0 || isAddressWord(N))
    return false;
  Base = N;
  Disp = CurDAG->getSignedTargetConstant(Off, DL, MVT::i8);
  return true;
}

// A frame index, or a frame index plus a signed byte. The slot's real
// distance from S or X is filled in by eliminateFrameIndex, which widens an
// 8-bit form when that distance does not fit.
bool CPU6DAGToDAGISel::SelectBlkFrame(SDValue N, SDValue &Base,
                                      SDValue &Disp) {
  if (!onlyUsedByOneNode(N.getNode()))
    return false;

  SDLoc DL(N);
  int64_t Off = 0;
  if (CurDAG->isBaseWithConstantOffset(N)) {
    int64_t C = cast<ConstantSDNode>(N.getOperand(1))->getSExtValue();
    if (!isInt<8>(C))
      return false;
    Off = C;
    N = N.getOperand(0);
  }
  auto *FI = dyn_cast<FrameIndexSDNode>(N);
  if (!FI)
    return false;
  Base = CurDAG->getTargetFrameIndex(FI->getIndex(), MVT::i16);
  Disp = CurDAG->getSignedTargetConstant(Off, DL, MVT::i8);
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
