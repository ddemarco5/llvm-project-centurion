//===-- CPU6MCInstLower.cpp - Lower MachineInstr to MCInst -------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "CPU6MCInstLower.h"
#include "MCTargetDesc/CPU6MCTargetDesc.h"
#include "llvm/CodeGen/AsmPrinter.h"
#include "llvm/CodeGen/MachineBasicBlock.h"
#include "llvm/CodeGen/MachineInstr.h"
#include "llvm/CodeGen/MachineOperand.h"
#include "llvm/MC/MCContext.h"
#include "llvm/MC/MCExpr.h"
#include "llvm/MC/MCInst.h"

using namespace llvm;

void CPU6MCInstLower::lowerInstruction(const MachineInstr *MI,
                                       MCInst &OutMI) const {
  // TAILJMP is JMP (addr). The pseudo exists so the jump is a return during
  // prologue insertion and not a block branch during relaxation.
  unsigned Opc = MI->getOpcode();
  if (Opc == CPU6::TAILJMP)
    Opc = CPU6::JMP_1;
  OutMI.setOpcode(Opc);
  for (const MachineOperand &MO : MI->operands()) {
    if (MO.isReg()) {
      // Implicit operands (argument registers, the call's regmask uses)
      // are not encoded. The regmask itself is not a register.
      if (MO.isImplicit())
        continue;
      OutMI.addOperand(MCOperand::createReg(MO.getReg()));
    } else if (MO.isImm()) {
      OutMI.addOperand(MCOperand::createImm(MO.getImm()));
    } else if (MO.isGlobal()) {
      // JSR (foo). The address word is fixup_cpu6_abs_16. The text
      // printer emits the symbol either way.
      const MCExpr *Expr =
          MCSymbolRefExpr::create(Printer.getSymbol(MO.getGlobal()), Ctx);
      if (MO.getOffset())
        Expr = MCBinaryExpr::createAdd(
            Expr, MCConstantExpr::create(MO.getOffset(), Ctx), Ctx);
      OutMI.addOperand(MCOperand::createExpr(Expr));
    } else if (MO.isSymbol()) {
      OutMI.addOperand(MCOperand::createExpr(
          MCSymbolRefExpr::create(Ctx.getOrCreateSymbol(MO.getSymbolName()),
                                  Ctx)));
    } else if (MO.isMBB()) {
      OutMI.addOperand(MCOperand::createExpr(
          MCSymbolRefExpr::create(MO.getMBB()->getSymbol(), Ctx)));
    } else if (MO.isBlockAddress()) {
      const MCExpr *Expr = MCSymbolRefExpr::create(
          Printer.GetBlockAddressSymbol(MO.getBlockAddress()), Ctx);
      if (MO.getOffset())
        Expr = MCBinaryExpr::createAdd(
            Expr, MCConstantExpr::create(MO.getOffset(), Ctx), Ctx);
      OutMI.addOperand(MCOperand::createExpr(Expr));
    } else if (MO.isRegMask()) {
      continue;
    } else {
      llvm_unreachable("unhandled MachineOperand");
    }
  }

  // Operand order has to match the instruction's (outs, ins) list. That is
  // the same order getBinaryCodeForInstr reads. RSR has no operands, so the
  // loop adds nothing and the existing one-byte encoder emits 0x09.
}
