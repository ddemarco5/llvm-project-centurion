// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This class prints a CPU6 MCInst to a .s file.
//
//===----------------------------------------------------------------------===//

#ifndef LLVM_LIB_TARGET_CPU6_MCTARGETDESC_CPU6INSTPRINTER_H
#define LLVM_LIB_TARGET_CPU6_MCTARGETDESC_CPU6INSTPRINTER_H

#include "MCTargetDesc/CPU6MCTargetDesc.h"
#include "llvm/MC/MCInstPrinter.h"

namespace llvm {

class CPU6InstPrinter : public MCInstPrinter {
public:
    CPU6InstPrinter(const MCAsmInfo &MAI, const MCInstrInfo &MII,
                    const MCRegisterInfo &MRI)
        : MCInstPrinter(MAI, MII, MRI) {}

    void printInst(const MCInst *MI, uint64_t Address, StringRef Annot,
                   const MCSubtargetInfo &STI, raw_ostream &O) override;

    void printRegName(raw_ostream &O, unsigned RegNo) const override;

    void printOperand(const MCInst *MI, unsigned OpNo, raw_ostream &O);

    // Autogenerated by tblgen.
    std::pair<const char *, uint64_t> getMnemonic(const MCInst *MI) override;
    void printInstruction(const MCInst *MI, uint64_t Address, raw_ostream &O);
    bool printAliasInstr(const MCInst *MI, uint64_t Address, raw_ostream &O);
    static const char *getRegisterName(unsigned RegNo);
};
} // end llvm namespace
#endif