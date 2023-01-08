//===-- CPU6AsmBackend.cpp - CPU6 Assembler Backend ---------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "CPU6AsmBackend.h"
#include "llvm/MC/MCAsmBackend.h"
#include "llvm/MC/MCAssembler.h"
#include "llvm/MC/MCDirectives.h"
#include "llvm/MC/MCELFObjectWriter.h"
#include "llvm/MC/MCExpr.h"
#include "llvm/MC/MCFixupKindInfo.h"
#include "llvm/MC/MCObjectWriter.h"
#include "llvm/MC/MCSymbol.h"
#include "llvm/Support/ErrorHandling.h"
#include "llvm/Support/raw_ostream.h"

using namespace llvm;

void CPU6AsmBackend::applyFixup(const MCAssembler &Asm, const MCFixup &Fixup,
                    const MCValue &Target, MutableArrayRef<char> Data,
                    uint64_t Value, bool IsResolved,
                    const MCSubtargetInfo *STI) const {
    return;
}
unsigned CPU6AsmBackend::getNumFixupKinds() const { return 1; }
bool CPU6AsmBackend::mayNeedRelaxation(const MCInst &Inst, const MCSubtargetInfo &STI) const { return false; }
void CPU6AsmBackend::relaxInstruction(MCInst &Inst,const MCSubtargetInfo &STI) const {
    report_fatal_error("CPU6AsmBackend::relaxInstruction() unimplemented");
}
bool CPU6AsmBackend::writeNopData(raw_ostream &OS, uint64_t Count, const MCSubtargetInfo *STI) const {
    //TODO: Figure out how we want to write our noop data here
    return true;
}
std::unique_ptr<MCObjectTargetWriter>
CPU6AsmBackend::createObjectTargetWriter() const {
    return createCPU6ELFObjectWriter(OSABI, Is64Bit);
}

MCAsmBackend *llvm::createCPU6AsmBackend(const Target &T,
                                        const MCSubtargetInfo &STI,
                                        const MCRegisterInfo &MRI,
                                        const MCTargetOptions &Options) {
    const Triple &TT = STI.getTargetTriple();
    uint8_t OSABI = MCELFObjectTargetWriter::getOSABI(TT.getOS());
    return new CPU6AsmBackend(OSABI, TT.isArch64Bit());
}

