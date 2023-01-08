// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file implements the CPU6MCCodeEmitter class.
//
//===----------------------------------------------------------------------===//

#include "MCTargetDesc/CPU6MCTargetDesc.h"
#include "llvm/ADT/Statistic.h"
#include "llvm/MC/MCAsmInfo.h"
#include "llvm/MC/MCCodeEmitter.h"
#include "llvm/MC/MCContext.h"
#include "llvm/MC/MCExpr.h"
#include "llvm/MC/MCInst.h"
#include "llvm/MC/MCInstrInfo.h"
#include "llvm/MC/MCRegisterInfo.h"
#include "llvm/MC/MCSymbol.h"
#include "llvm/Support/EndianStream.h"
#include "llvm/Support/raw_ostream.h"

using namespace llvm;

#define DEBUG_TYPE "mccodeemitter"

STATISTIC(MCNumEmitted, "Number of MC instructions emitted");

namespace {

class CPU6MCCodeEmitter : public MCCodeEmitter {
    CPU6MCCodeEmitter(const CPU6MCCodeEmitter &) = delete;
    void operator=(const CPU6MCCodeEmitter &) = delete;
    MCContext &Ctx;
    MCInstrInfo const &MCII;

public:
    CPU6MCCodeEmitter(MCContext &ctx, MCInstrInfo const &MCII) : Ctx(ctx), MCII(MCII) {}

    ~CPU6MCCodeEmitter() override {}

    void encodeInstruction(const MCInst &MI, raw_ostream &OS,
                           SmallVectorImpl<MCFixup> &Fixups,
                           const MCSubtargetInfo &STI) const override;

    /// TableGen'erated function for getting the binary encoding for an
    /// instruction.
    uint64_t getBinaryCodeForInstr(const MCInst &MI,
                                   SmallVectorImpl<MCFixup> &Fixups,
                                   const MCSubtargetInfo &STI) const;

    /// Return binary encoding of operand. If the machine operand requires
    /// relocation, record the relocation and return zero.
    unsigned getMachineOpValue(const MCInst &MI, const MCOperand &MO,
                               SmallVectorImpl<MCFixup> &Fixups,
                               const MCSubtargetInfo &STI) const;

};    
} // end anonymous namespace

MCCodeEmitter *llvm::createCPU6MCCodeEmitter(const MCInstrInfo &MCII,
                                             MCContext &Ctx) {

  // I know these args are backwards... it has to be that way, it errors if it isn't
  // and I'm too tired to check why
  return new CPU6MCCodeEmitter(Ctx, MCII);
}

void CPU6MCCodeEmitter::encodeInstruction(const MCInst &MI, raw_ostream &OS,
                                           SmallVectorImpl<MCFixup> &Fixups,
                                           const MCSubtargetInfo &STI) const {
    const MCInstrDesc &Desc = MCII.get(MI.getOpcode());
    // Get byte count of instruction.
    unsigned Size = Desc.getSize();

    // CPU6 instructions are 8, 16, or 24 bits in length
    switch (Size) {
        default:
            llvm_unreachable("Unhandled encodeInstruction length!");
        case 1: {
            uint8_t Bits = getBinaryCodeForInstr(MI, Fixups, STI);
            support::endian::write<uint8_t>(OS, Bits, support::little);
            break;
        }
        case 2: {
            uint16_t Bits = getBinaryCodeForInstr(MI, Fixups, STI);
            support::endian::write<uint16_t>(OS, Bits, support::little);
            break;
        }
        case 3: {

            // we need to write 3 bytes (24 bits) to the output stream, and there's no easy
            // way to do that like the cases above, so we have to convert it to const char*
            // and write those 3 chars dirctly to the ostream
            uint64_t Bits = getBinaryCodeForInstr(MI, Fixups, STI);
            std::string bit_str = std::to_string(Bits);
            OS.write(bit_str.c_str(), 3);
            //support::endian::write<uint24_t>(OS, Bits_resized, support::little);
            break;
        }
    }
    ++MCNumEmitted; // Keep track of the # of mi's emitted.
}

unsigned
CPU6MCCodeEmitter::getMachineOpValue(const MCInst &MI, const MCOperand &MO,
                                      SmallVectorImpl<MCFixup> &Fixups,
                                      const MCSubtargetInfo &STI) const {

  if (MO.isReg())
    return Ctx.getRegisterInfo()->getEncodingValue(MO.getReg());

  if (MO.isImm())
    return static_cast<unsigned>(MO.getImm());

  llvm_unreachable("Unhandled expression!");
  return 0;
}

#include "CPU6GenMCCodeEmitter.inc"