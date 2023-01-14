// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This class prints an CPU6 MCInst to a .s file.
//
//===----------------------------------------------------------------------===//

#include "CPU6InstPrinter.h"
#include "llvm/MC/MCAsmInfo.h"
#include "llvm/MC/MCExpr.h"
#include "llvm/MC/MCInst.h"
#include "llvm/MC/MCRegisterInfo.h"
#include "llvm/MC/MCSymbol.h"
#include "llvm/Support/CommandLine.h"
#include "llvm/Support/ErrorHandling.h"
#include "llvm/Support/FormattedStream.h"
using namespace llvm;

#define DEBUG_TYPE "asm-printer"

// Include the auto-generated portion of the assembly writer.
#define PRINT_ALIAS_INSTR
#include "CPU6GenAsmWriter.inc"

void CPU6InstPrinter::printInst(const MCInst *MI, uint64_t Address, StringRef Annot,
                                const MCSubtargetInfo &STI, raw_ostream &O) {
    printInstruction(MI, Address, O);
    printAnnotation(O, Annot);
}

void CPU6InstPrinter::printRegName(raw_ostream &O, unsigned RegNo) const {
    O << getRegisterName(RegNo);
}

void CPU6InstPrinter::printOperand(const MCInst *MI, unsigned OpNo, raw_ostream &O) {

    const MCOperand &MO = MI->getOperand(OpNo);

    if (MO.isReg()) {
        printRegName(O, MO.getReg());
        return;
    }

    if (MO.isImm()) {
        O << MO.getImm();
        return;
    }

    assert(MO.isExpr() && "Unknown operand kind in printOperand");
    MO.getExpr()->print(O, &MAI);
}