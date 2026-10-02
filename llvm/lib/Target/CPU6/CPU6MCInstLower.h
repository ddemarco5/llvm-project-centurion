//===-- CPU6MCInstLower.h - Lower MachineInstr to MCInst --------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// MachineInstr is what instruction selection and register allocation produce.
// MCInst is what CPU6InstPrinter and CPU6MCCodeEmitter already consume. This
// is the seam between them.

#ifndef LLVM_LIB_TARGET_CPU6_CPU6MCINSTLOWER_H
#define LLVM_LIB_TARGET_CPU6_CPU6MCINSTLOWER_H

namespace llvm {

class AsmPrinter;
class MCContext;
class MCInst;
class MachineInstr;

class CPU6MCInstLower {
  MCContext &Ctx;
  AsmPrinter &Printer;

public:
  CPU6MCInstLower(MCContext &Ctx, AsmPrinter &Printer)
      : Ctx(Ctx), Printer(Printer) {}

  // Copies the opcode and the encoded operands into OutMI. A symbol, global,
  // or block address becomes an MCExpr through Ctx and Printer.
  void lowerInstruction(const MachineInstr *MI, MCInst &OutMI) const;
};

} // namespace llvm

#endif
