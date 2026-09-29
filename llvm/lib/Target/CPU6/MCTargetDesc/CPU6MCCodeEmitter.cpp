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
#include "llvm/Support/Debug.h"
#include "llvm/Support/raw_ostream.h"
#include "llvm/Support/DataExtractor.h"

#include <bitset>

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

    void encodeInstruction(const MCInst &MI, SmallVectorImpl<char> &CB,
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

    unsigned getImmOpValue(const MCInst &MI, unsigned OpNo,
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

void CPU6MCCodeEmitter::encodeInstruction(const MCInst &MI,
                                           SmallVectorImpl<char> &CB,
                                           SmallVectorImpl<MCFixup> &Fixups,
                                           const MCSubtargetInfo &STI) const {
    const MCInstrDesc &Desc = MCII.get(MI.getOpcode());
    // Get byte count of instruction.
    unsigned Size = Desc.getSize();
    uint64_t Bits = getBinaryCodeForInstr(MI, Fixups, STI);

    // CPU6 instructions are 8, 16, or 24 bits. The LLVM 15 emitter wrote
    // those bytes big-endian; keep that encoding.
    switch (Size) {
        default:
            llvm_unreachable("Unhandled encodeInstruction length!");
        case 1:
            LLVM_DEBUG(dbgs() << "Emitting 1 byte opcode!\n");
            CB.push_back(static_cast<char>(Bits));
            break;
        case 2:
            LLVM_DEBUG(dbgs() << "Emitting 2 byte opcode!\n");
            CB.push_back(static_cast<char>(Bits >> 8));
            CB.push_back(static_cast<char>(Bits));
            break;
        case 3:
            LLVM_DEBUG(dbgs() << "Emitting 3 byte opcode!\n");
            CB.push_back(static_cast<char>(Bits >> 16));
            CB.push_back(static_cast<char>(Bits >> 8));
            CB.push_back(static_cast<char>(Bits));
            break;
        case 4:
            LLVM_DEBUG(dbgs() << "Emitting 4 byte opcode!\n");
            CB.push_back(static_cast<char>(Bits >> 24));
            CB.push_back(static_cast<char>(Bits >> 16));
            CB.push_back(static_cast<char>(Bits >> 8));
            CB.push_back(static_cast<char>(Bits));
            break;
        case 6:
            // 0x47 stub: opcode plus five uninterpreted bytes.
            LLVM_DEBUG(dbgs() << "Emitting 6 byte opcode!\n");
            CB.push_back(static_cast<char>(Bits >> 40));
            CB.push_back(static_cast<char>(Bits >> 32));
            CB.push_back(static_cast<char>(Bits >> 24));
            CB.push_back(static_cast<char>(Bits >> 16));
            CB.push_back(static_cast<char>(Bits >> 8));
            CB.push_back(static_cast<char>(Bits));
            break;
        case 7:
            // BIGNUM: 3-byte prefix plus two 2-byte tails.
            LLVM_DEBUG(dbgs() << "Emitting 7 byte opcode!\n");
            CB.push_back(static_cast<char>(Bits >> 48));
            CB.push_back(static_cast<char>(Bits >> 40));
            CB.push_back(static_cast<char>(Bits >> 32));
            CB.push_back(static_cast<char>(Bits >> 24));
            CB.push_back(static_cast<char>(Bits >> 16));
            CB.push_back(static_cast<char>(Bits >> 8));
            CB.push_back(static_cast<char>(Bits));
            break;
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

  llvm_unreachable("Unhandled expression! (getMachineOpValue)");
  return 0;
}

unsigned
CPU6MCCodeEmitter::getImmOpValue(const MCInst &MI, unsigned OpNo,
                                 SmallVectorImpl<MCFixup> &Fixups,
                                 const MCSubtargetInfo &STI) const {
                                   
    const MCOperand &MO = MI.getOperand(OpNo);

    // If the destination is an immediate, there is nothing to do
    if (MO.isImm()) {
        return MO.getImm();
    }
    llvm_unreachable("Unhandled expression! (getImmOpValue)");
    return 0;
}

#include "CPU6GenMCCodeEmitter.inc"