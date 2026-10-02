//===-- CPU6AsmBackend.cpp - CPU6 Assembler Backend ---------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "CPU6AsmBackend.h"
#include "CPU6FixupKinds.h"
#include "llvm/MC/MCAsmBackend.h"
#include "llvm/MC/MCAssembler.h"
#include "llvm/MC/MCContext.h"
#include "llvm/MC/MCELFObjectWriter.h"
#include "llvm/MC/MCExpr.h"
#include "llvm/MC/MCObjectWriter.h"
#include "llvm/Support/ErrorHandling.h"
#include "llvm/Support/MathExtras.h"
#include "llvm/Support/raw_ostream.h"

using namespace llvm;

MCFixupKindInfo CPU6AsmBackend::getFixupKindInfo(MCFixupKind Kind) const {
  const static MCFixupKindInfo Infos[CPU6::NumTargetFixupKinds] = {
      // name                    offset bits flags
      {"fixup_cpu6_pcrel_8", 0, 8, 0},
      {"fixup_cpu6_abs_16", 0, 16, 0},
  };
  static_assert(std::size(Infos) == CPU6::NumTargetFixupKinds,
                "Not all CPU6 fixup kinds added to Infos array");

  if (Kind < FirstTargetFixupKind)
    return MCAsmBackend::getFixupKindInfo(Kind);
  assert(unsigned(Kind - FirstTargetFixupKind) < CPU6::NumTargetFixupKinds &&
         "Invalid CPU6 fixup kind");
  return Infos[Kind - FirstTargetFixupKind];
}

void CPU6AsmBackend::applyFixup(const MCFragment &F, const MCFixup &Fixup,
                                const MCValue &Target, uint8_t *Data,
                                uint64_t Value, bool IsResolved) {
  maybeAddReloc(F, Fixup, Target, Value, IsResolved);
  // A relocation that still needs a linker is RELA: the addend is in the
  // relocation, and the instruction bytes stay zero. PC-relative branches
  // to a label in this section are resolved here.
  if (!IsResolved)
    return;

  switch (Fixup.getKind()) {
  case CPU6::fixup_cpu6_pcrel_8: {
    // Value is target - address_of_displacement_byte. The hardware adds the
    // displacement to the PC of the next instruction, one byte later.
    int64_t Disp = static_cast<int64_t>(Value) - 1;
    if (!isInt<8>(Disp)) {
      getContext().reportError(Fixup.getLoc(),
                               "8-bit PC-relative displacement out of range");
      return;
    }
    assert(Fixup.getOffset() + 1 <= F.getSize() && "Invalid fixup offset");
    Data[0] = static_cast<uint8_t>(Disp);
    break;
  }
  case CPU6::fixup_cpu6_abs_16: {
    assert(Fixup.getOffset() + 2 <= F.getSize() && "Invalid fixup offset");
    uint16_t Imm = static_cast<uint16_t>(Value);
    Data[0] = static_cast<uint8_t>(Imm >> 8);
    Data[1] = static_cast<uint8_t>(Imm);
    break;
  }
  default: {
    // FK_Data_* and the other generic kinds. The bytes are little-endian,
    // matching this backend's endianness. CPU6 instruction fixups are the
    // two cases above and are big-endian.
    MCFixupKindInfo Info = getFixupKindInfo(Fixup.getKind());
    if (!Value)
      return;
    Value <<= Info.TargetOffset;
    unsigned NumBytes = alignTo(Info.TargetSize + Info.TargetOffset, 8) / 8;
    assert(Fixup.getOffset() + NumBytes <= F.getSize() &&
           "Invalid fixup offset");
    for (unsigned I = 0; I != NumBytes; ++I)
      Data[I] |= static_cast<uint8_t>((Value >> (I * 8)) & 0xff);
    break;
  }
  }
}

bool CPU6AsmBackend::mayNeedRelaxation(unsigned, ArrayRef<MCOperand>,
                                       const MCSubtargetInfo &) const {
  return false;
}

void CPU6AsmBackend::relaxInstruction(MCInst &,
                                      const MCSubtargetInfo &) const {
  report_fatal_error("CPU6AsmBackend::relaxInstruction() unimplemented");
}

bool CPU6AsmBackend::writeNopData(raw_ostream &OS, uint64_t Count,
                                  const MCSubtargetInfo *) const {
  // NOP is opcode 0x01 and is one byte, so any padding length is a run of
  // them. Count is a number of bytes.
  for (uint64_t I = 0; I != Count; ++I)
    OS << '\x01';
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
