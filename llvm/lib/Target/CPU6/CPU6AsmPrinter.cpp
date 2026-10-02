//===-- CPU6AsmPrinter.cpp - CPU6 assembly writer ----------------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// AsmPrinter walks the MachineFunction after register allocation and prologue
// insertion. Labels, directives, and debug info are handled by the base class.
// emitInstruction is the per-opcode hook, and it forwards to CPU6MCInstLower.

#include "CPU6AsmPrinter.h"
#include "CPU6MCInstLower.h"
#include "MCTargetDesc/CPU6MCTargetDesc.h"
#include "TargetInfo/CPU6TargetInfo.h"
#include "llvm/CodeGen/AsmPrinter.h"
#include "llvm/CodeGen/AsmPrinterAnalysis.h"
#include "llvm/CodeGen/MachineFunctionAnalysisManager.h"
#include "llvm/MC/MCInst.h"
#include "llvm/MC/MCStreamer.h"
#include "llvm/MC/TargetRegistry.h"

using namespace llvm;

namespace {

class CPU6AsmPrinter : public AsmPrinter {
public:
  CPU6AsmPrinter(TargetMachine &TM, std::unique_ptr<MCStreamer> Streamer)
      : AsmPrinter(TM, std::move(Streamer)) {}

  StringRef getPassName() const override { return "CPU6 Assembly Printer"; }

  void emitInstruction(const MachineInstr *MI) override;
};

} // namespace

#define GEN_COMPRESS_INSTR
#include "CPU6GenCompressInstEmitter.inc"

void CPU6AsmPrinter::emitInstruction(const MachineInstr *MI) {
  CPU6MCInstLower Lower(OutContext, *this);
  MCInst TmpInst;
  Lower.lowerInstruction(MI, TmpInst);
  MCInst CInst;
  if (compressInst(CInst, TmpInst, getSubtargetInfo()))
    TmpInst = CInst;
  OutStreamer->emitInstruction(TmpInst, getSubtargetInfo());
}

extern "C" LLVM_EXTERNAL_VISIBILITY void LLVMInitializeCPU6AsmPrinter() {
  RegisterAsmPrinter<CPU6AsmPrinter> X(getTheCPU6Target());
}

PreservedAnalyses CPU6AsmPrinterBeginPass::run(Module &M,
                                               ModuleAnalysisManager &MAM) {
  CPU6AsmPrinter &Printer = static_cast<CPU6AsmPrinter &>(
      MAM.getResult<AsmPrinterAnalysis>(M).getPrinter());
  setupModuleAsmPrinter(M, MAM, Printer);
  Printer.doInitialization(M);
  return PreservedAnalyses::all();
}

PreservedAnalyses
CPU6AsmPrinterPass::run(MachineFunction &MF,
                        MachineFunctionAnalysisManager &MFAM) {
  CPU6AsmPrinter &Printer = static_cast<CPU6AsmPrinter &>(
      MFAM.getResult<ModuleAnalysisManagerMachineFunctionProxy>(MF)
          .getCachedResult<AsmPrinterAnalysis>(*MF.getFunction().getParent())
          ->getPrinter());
  setupMachineFunctionAsmPrinter(MFAM, MF, Printer);
  Printer.runOnMachineFunction(MF);
  return PreservedAnalyses::all();
}

PreservedAnalyses CPU6AsmPrinterEndPass::run(Module &M,
                                             ModuleAnalysisManager &MAM) {
  CPU6AsmPrinter &Printer = static_cast<CPU6AsmPrinter &>(
      MAM.getResult<AsmPrinterAnalysis>(M).getPrinter());
  setupModuleAsmPrinter(M, MAM, Printer);
  Printer.doFinalization(M);
  return PreservedAnalyses::all();
}
