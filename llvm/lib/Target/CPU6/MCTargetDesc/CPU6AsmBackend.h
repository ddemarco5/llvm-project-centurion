// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef LLVM_LIB_TARGET_CPU6_MCTARGETDESC_CPU6ASMBACKEND_H
#define LLVM_LIB_TARGET_CPU6_MCTARGETDESC_CPU6ASMBACKEND_H

#include "MCTargetDesc/CPU6MCTargetDesc.h"
#include "llvm/MC/MCAsmBackend.h"
#include "llvm/MC/MCFixupKindInfo.h"
#include "llvm/MC/MCSubtargetInfo.h"

namespace llvm {

class CPU6AsmBackend : public MCAsmBackend {
    uint8_t OSABI;
    bool Is64Bit;

public:
    CPU6AsmBackend(uint8_t OSABI, bool Is64Bit)
            : MCAsmBackend(support::little), OSABI(OSABI), Is64Bit(Is64Bit) {}
    ~CPU6AsmBackend() override = default;

    void applyFixup(const MCAssembler &Asm, const MCFixup &Fixup,
                    const MCValue &Target, MutableArrayRef<char> Data,
                    uint64_t Value, bool IsResolved,
                    const MCSubtargetInfo *STI) const override;

    std::unique_ptr<MCObjectTargetWriter> createObjectTargetWriter() const override;

    bool fixupNeedsRelaxation(const MCFixup &Fixup, uint64_t Value,
                            const MCRelaxableFragment *DF,
                            const MCAsmLayout &Layout) const override {
        llvm_unreachable("Handled by fixupNeedsRelaxationAdvanced");
    }

    unsigned getNumFixupKinds() const override;

    bool mayNeedRelaxation(const MCInst &Inst, const MCSubtargetInfo &STI) const override;

    void relaxInstruction(MCInst &Inst, const MCSubtargetInfo &STI) const override;

    bool writeNopData(raw_ostream &OS, uint64_t Count, const MCSubtargetInfo *STI) const override;

};

}

#endif