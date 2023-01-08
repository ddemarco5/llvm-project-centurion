// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "MCTargetDesc/CPU6MCTargetDesc.h"
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
    unsigned getRelocType(MCContext &Ctx, const MCValue &Target,
                          const MCFixup &Fixup, bool IsPCRel) const override;
};
}

CPU6ELFObjectWriter::CPU6ELFObjectWriter(uint8_t OSABI, bool Is64Bit)
    : MCELFObjectTargetWriter(Is64Bit, OSABI, ELF::EM_RISCV,
                              /*HasRelocationAddend*/ true) {}

CPU6ELFObjectWriter::~CPU6ELFObjectWriter() = default;

unsigned CPU6ELFObjectWriter::getRelocType(MCContext &Ctx,
                                           const MCValue &Target,
                                           const MCFixup &Fixup,
                                           bool IsPCRel) const {
    report_fatal_error("invalid fixup kind! (CPU6)");
}

std::unique_ptr<MCObjectTargetWriter>
llvm::createCPU6ELFObjectWriter(uint8_t OSABI, bool Is64Bit) {
  return std::make_unique<CPU6ELFObjectWriter>(OSABI, Is64Bit);
}