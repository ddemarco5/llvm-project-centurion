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
  // x + delta, or x if the branch in the last operand is taken; glued to the
  // compare. See combineCarryStep.
  STEP_CC,
  // Bignum mem ops (0x46). Chain in, chain out. Operands are src ptr, dest
  // ptr, and a byte length-1 immediate (3 => i32, 7 => i64). See the Bignum
  // section of CPU6InstrInfo.td and the TODO patterns in
  // CPU6InstrPatterns.td.
  BN_MOV, // ZAD
  BN_ADD, // BNA
  BN_SUB, // BNS
  BN_NEG, // ZSU
  BN_MUL, // M
  BN_DIV, // D, signed
  // DRM: also takes the remainder's address in A, as glue from a CopyToReg.
  BN_DRM,
  BN_CMP, // BNC — sets flags; no store
  // 0x47 block ops. Chain in, chain out. BLK_COPY is src, dst, count-1 (MVF);
  // BLK_FILL is the byte, dst, count-1 (FIL). count-1 is an i8 target
  // constant, so one node moves at most 256 bytes.
  BLK_COPY,
  BLK_FILL,
  // A run-time length. MEMCPY_LOOP and MEMMOVE_LOOP are src, dst, n.
  // MEMSET_LOOP is dst, the byte, n. See EmitMemLoop.
  MEMCPY_LOOP,
  MEMMOVE_LOOP,
  MEMSET_LOOP,
};
} // namespace CPU6ISD

// memcpy, memmove, and memset on the 0x47 and 0x67 block ops. See the Block
// move section of CPU6InstrInfo.td.
class CPU6SelectionDAGInfo : public SelectionDAGTargetInfo {
public:
  const char *getTargetNodeName(unsigned Opcode) const override;

  SDValue EmitTargetCodeForMemcpy(SelectionDAG &DAG, const SDLoc &DL,
                                  SDValue Chain, SDValue Dst, SDValue Src,
                                  SDValue Size, Align DstAlign, Align SrcAlign,
                                  bool IsVolatile, bool AlwaysInline,
                                  MachinePointerInfo DstPtrInfo,
                                  MachinePointerInfo SrcPtrInfo) const override;

  SDValue EmitTargetCodeForMemmove(SelectionDAG &DAG, const SDLoc &DL,
                                   SDValue Chain, SDValue Dst, SDValue Src,
                                   SDValue Size, Align DstAlign,
                                   Align SrcAlign, bool IsVolatile,
                                   MachinePointerInfo DstPtrInfo,
                                   MachinePointerInfo SrcPtrInfo) const override;

  SDValue EmitTargetCodeForMemset(SelectionDAG &DAG, const SDLoc &DL,
                                  SDValue Chain, SDValue Dst, SDValue Val,
                                  SDValue Size, Align Alignment,
                                  bool IsVolatile, bool AlwaysInline,
                                  MachinePointerInfo DstPtrInfo) const override;
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

  // DIV is one instruction, so a constant divisor stays DIVimmLo.
  bool isIntDivCheap(EVT VT, AttributeList) const override {
    return VT == MVT::i16;
  }

  // No floating-point hardware. f32/f64 stay SoftenFloat via libcalls.
  bool useSoftFloat() const override { return true; }

  // "r" picks a GPR. "{A}" and the other names go through the base class.
  std::pair<unsigned, const TargetRegisterClass *>
  getRegForInlineAsmConstraint(const TargetRegisterInfo *TRI,
                               StringRef Constraint, MVT VT) const override;

  SDValue LowerOperation(SDValue Op, SelectionDAG &DAG) const override;

  SDValue PerformDAGCombine(SDNode *N, DAGCombinerInfo &DCI) const override;

  MachineBasicBlock *
  EmitInstrWithCustomInserter(MachineInstr &MI,
                              MachineBasicBlock *BB) const override;

private:
  // Fold store(add/sub(load,load)) and store(load) into 0x46 bignum ops
  // while the value type is still i32/i64.
  SDValue combineBignumStore(StoreSDNode *St, SelectionDAG &DAG) const;
  SDValue combineBignumRem(StoreSDNode *St, SelectionDAG &DAG) const;
  // Fold setcc(load,load) on i32/i64 into BNC plus a flag reader.
  SDValue combineBignumSetCC(SDNode *N, SelectionDAG &DAG) const;
  // add/sub x, (select_cc 1, 0): a carry or borrow added to a word.
  SDValue combineCarryStep(SDNode *N, SelectionDAG &DAG) const;
  // A constant logical right shift is an arithmetic shift plus a mask. A
  // variable shift is left for the one-bit loop in EmitShift.
  SDValue LowerShift(SDValue Op, SelectionDAG &DAG) const;

  // Signed i16 quotient and remainder. DIV is unsigned, so both are
  // magnitudes, one DIV, then the sign is put back.
  SDValue LowerDivRem(SDValue Op, SelectionDAG &DAG) const;

  // Signed widening product. The low half matches the unsigned pair MUL.
  // The high half subtracts the other operand for each negative input.
  SDValue LowerSmulLoHi(SDValue Op, SelectionDAG &DAG) const;

  MachineBasicBlock *EmitSelect(MachineInstr &MI, MachineBasicBlock *BB) const;
  MachineBasicBlock *EmitStepCC(MachineInstr &MI, MachineBasicBlock *BB) const;
  MachineBasicBlock *EmitShift(MachineInstr &MI, MachineBasicBlock *BB) const;
  MachineBasicBlock *EmitMulhu(MachineInstr &MI, MachineBasicBlock *BB) const;
  MachineBasicBlock *EmitMulLow(MachineInstr &MI, MachineBasicBlock *BB) const;
  MachineBasicBlock *EmitDiv(MachineInstr &MI, MachineBasicBlock *BB) const;
  MachineBasicBlock *EmitMulLoHi(MachineInstr &MI,
                                 MachineBasicBlock *BB) const;
  MachineBasicBlock *EmitMemLoop(MachineInstr &MI, MachineBasicBlock *BB) const;

  SDValue LowerCallResult(SDValue Chain, SDValue InGlue, CallingConv::ID CallConv,
                          bool IsVarArg, const SmallVectorImpl<ISD::InputArg> &Ins,
                          const SDLoc &DL, SelectionDAG &DAG,
                          SmallVectorImpl<SDValue> &InVals) const;
};

} // namespace llvm

#endif
