//===-- CPU6MCInstLower.cpp - Lower MachineInstr to MCInst -------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "CPU6MCInstLower.h"
#include "llvm/CodeGen/AsmPrinter.h"
#include "llvm/CodeGen/MachineInstr.h"
#include "llvm/CodeGen/MachineOperand.h"
#include "llvm/MC/MCContext.h"
#include "llvm/MC/MCInst.h"

using namespace llvm;

void CPU6MCInstLower::lowerInstruction(const MachineInstr *MI,
                                       MCInst &OutMI) const {
  // TODO(cpu6): CPU6AsmPrinter::emitInstruction calls this for every real
  // instruction, then hands OutMI to the streamer. The streamer is the MC
  // layer you already have: CPU6InstPrinter writes the text, and
  // CPU6MCCodeEmitter writes the bytes when the output is an object file.
  //
    OutMI.setOpcode(MI->getOpcode());
    for (const MachineOperand &MO : MI->operands()) {
      if (MO.isReg()) {
        // Implicit operands (clobbers, dead defs) are not encoded.
        if (MO.isImplicit())
          continue;
        OutMI.addOperand(MCOperand::createReg(MO.getReg()));
      } else if (MO.isImm()) {
        OutMI.addOperand(MCOperand::createImm(MO.getImm()));
      } else {
        llvm_unreachable("unhandled MachineOperand");
      }
    }

  // Operand order has to match the instruction's (outs, ins) list. That is
  // the same order getBinaryCodeForInstr reads. RSR has no operands, so the
  // loop adds nothing and the existing one-byte encoder emits 0x09.
}
