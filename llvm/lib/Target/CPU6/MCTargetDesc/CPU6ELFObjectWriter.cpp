// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "MCTargetDesc/CPU6MCTargetDesc.h"
#include "CPU6FixupKinds.h"
#include "llvm/BinaryFormat/ELF.h"
#include "llvm/MC/MCELFObjectWriter.h"
#include "llvm/MC/MCFixup.h"
#include "llvm/MC/MCObjectWriter.h"
#include "llvm/Support/ErrorHandling.h"

using namespace llvm;

namespace {

class CPU6ELFObjectWriter : public MCELFObjectTargetWriter {
public:
  CPU6ELFObjectWriter(uint8_t OSABI, bool Is64Bit);

  ~CPU6ELFObjectWriter() override;

protected:
  unsigned getRelocType(const MCFixup &Fixup, const MCValue &Target,
                        bool IsPCRel) const override;
};

} // namespace

CPU6ELFObjectWriter::CPU6ELFObjectWriter(uint8_t OSABI, bool Is64Bit)
    : MCELFObjectTargetWriter(Is64Bit, OSABI, ELF::EM_CPU6,
                              /*HasRelocationAddend*/ true) {}

CPU6ELFObjectWriter::~CPU6ELFObjectWriter() = default;

unsigned CPU6ELFObjectWriter::getRelocType(const MCFixup &Fixup, const MCValue &,
                                           bool) const {
  // R_CPU6_8_PCREL is S + A - (P + 1): P is the displacement byte, and the
  // hardware's PC is the following instruction. R_CPU6_16 is S + A, stored
  // big-endian.
  switch (Fixup.getKind()) {
  case CPU6::fixup_cpu6_pcrel_8:
    return ELF::R_CPU6_8_PCREL;
  case CPU6::fixup_cpu6_abs_16:
    return ELF::R_CPU6_16;
  case FK_Data_4:
    return ELF::R_CPU6_32;
  default:
    report_fatal_error("invalid fixup kind! (CPU6)");
  }
}

std::unique_ptr<MCObjectTargetWriter>
llvm::createCPU6ELFObjectWriter(uint8_t OSABI, bool Is64Bit) {
  return std::make_unique<CPU6ELFObjectWriter>(OSABI, Is64Bit);
}
