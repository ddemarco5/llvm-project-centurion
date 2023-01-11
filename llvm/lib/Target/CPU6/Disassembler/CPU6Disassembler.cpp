// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file implements the CPU6Disassembler class.
//
//===----------------------------------------------------------------------===//

#include "MCTargetDesc/CPU6MCTargetDesc.h"
#include "TargetInfo/CPU6TargetInfo.h"
#include "llvm/MC/MCContext.h"
#include "llvm/MC/MCDecoderOps.h"
#include "llvm/MC/MCDisassembler/MCDisassembler.h"
#include "llvm/MC/MCInst.h"
#include "llvm/MC/MCRegisterInfo.h"
#include "llvm/MC/MCSubtargetInfo.h"
#include "llvm/MC/TargetRegistry.h"
#include "llvm/Support/Endian.h"

using namespace llvm;

#define DEBUG_TYPE "cpu6-disassembler"

typedef MCDisassembler::DecodeStatus DecodeStatus;

namespace {
class CPU6Disassembler : public MCDisassembler {

public:
    CPU6Disassembler(const MCSubtargetInfo &STI, MCContext &Ctx)
        : MCDisassembler(STI, Ctx) {}

    DecodeStatus getInstruction(MCInst &Instr, uint64_t &Size,
                                ArrayRef<uint8_t> Bytes, uint64_t Address,
                                raw_ostream &CStream) const override;
};
} // end anonymous namespace

static MCDisassembler *createCPU6Disassembler(const Target &T,
                                              const MCSubtargetInfo &STI,
                                              MCContext &Ctx) {
    return new CPU6Disassembler(STI, Ctx);
}

extern "C" LLVM_EXTERNAL_VISIBILITY void LLVMInitializeCPU6Disassembler() {
  // Register the disassembler for each target.
  TargetRegistry::RegisterMCDisassembler(getTheCPU6Target(),
                                         createCPU6Disassembler);
}

static DecodeStatus DecodeGPRRegisterClass(MCInst &Inst, uint64_t RegNo,
                                           uint64_t Address,
                                           const MCDisassembler *Decoder) {

    // our main registers only go up to index 14
    if (RegNo > 14) { return MCDisassembler::Fail; }

    // Our main register index should NEVER be an odd number
    if (RegNo % 2) { return MCDisassembler::Fail; }

    // TODO: THIS IS BAD! Shouldn't redefine. But the tablegen is in flux rn
    // because I haven't touched codegen, so we just define register tables here for now
    std::map<uint64_t, uint16_t> regtable;
    regtable[0] = CPU6::rA;
    regtable[2] = CPU6::rB;
    regtable[4] = CPU6::rX;
    regtable[6] = CPU6::rY;
    regtable[8] = CPU6::rZ;
    regtable[10] = CPU6::rS;
    regtable[12] = CPU6::rC;
    regtable[14] = CPU6::rP;
    LLVM_DEBUG(dbgs() << "DecodeGPR " << RegNo << "\n");
    //MCRegister Reg = CPU6::A + RegNo;
    Inst.addOperand(MCOperand::createReg(regtable[RegNo]));
    return MCDisassembler::Success;
}

static DecodeStatus DecodeGPRhiRegisterClass(MCInst &Inst, uint64_t RegNo,
                                             uint64_t Address,
                                             const MCDisassembler *Decoder) {

    // our high registers only go up to index 14
    if (RegNo > 14) { return MCDisassembler::Fail; }

    // Our high register index should NEVER be an odd number
    if (RegNo % 2) { return MCDisassembler::Fail; }

    // TODO: THIS IS BAD! Shouldn't redefine. But the tablegen is in flux rn
    // because I haven't touched codegen, so we just define register tables here for now
    std::map<uint64_t, uint16_t> regtable;
    regtable[0] = CPU6::rAU;
    regtable[2] = CPU6::rBU;
    regtable[4] = CPU6::rXU;
    regtable[6] = CPU6::rYU;
    regtable[8] = CPU6::rZU;
    regtable[10] = CPU6::rSU;
    regtable[12] = CPU6::rCU;
    regtable[14] = CPU6::rPU;
    LLVM_DEBUG(dbgs() << "DecodeGPRhi " << RegNo << "\n");
    //MCRegister Reg = CPU6::AU + RegNo;
    Inst.addOperand(MCOperand::createReg(regtable[RegNo]));
    return MCDisassembler::Success;
}

static DecodeStatus DecodeGPRloRegisterClass(MCInst &Inst, uint64_t RegNo,
                                             uint64_t Address,
                                             const MCDisassembler *Decoder) {

    // our high registers only go up to index 15
    if (RegNo > 15) { return MCDisassembler::Fail; }

    // Our high register index should NEVER be an even number
    if (!(RegNo % 2)) { return MCDisassembler::Fail; }

    // TODO: THIS IS BAD! Shouldn't redefine. But the tablegen is in flux rn
    // because I haven't touched codegen, so we just define register tables here for now
    std::map<uint64_t, uint16_t> regtable;
    regtable[1] = CPU6::rAL;
    regtable[3] = CPU6::rBL;
    regtable[5] = CPU6::rXL;
    regtable[7] = CPU6::rYL;
    regtable[9] = CPU6::rZL;
    regtable[11] = CPU6::rSL;
    regtable[13] = CPU6::rCL;
    regtable[15] = CPU6::rPL;
    LLVM_DEBUG(dbgs() << "DecodeGPRlo " << RegNo << "\n");
    //MCRegister Reg = CPU6::AU + RegNo;
    Inst.addOperand(MCOperand::createReg(regtable[RegNo]));
    return MCDisassembler::Success;
}

// All 8 bit register flavors
static DecodeStatus DecodeGPRBRegisterClass(MCInst &Inst, uint64_t RegNo,
                                             uint64_t Address,
                                             const MCDisassembler *Decoder) {

    // our registers only go up to index 15
    if (RegNo > 15) { return MCDisassembler::Fail; }

    // TODO: THIS IS BAD! Shouldn't redefine. But the tablegen is in flux rn
    // because I haven't touched codegen, so we just define register tables here for now
    std::map<uint64_t, uint16_t> regtable;
    regtable[1] = CPU6::rAL;
    regtable[3] = CPU6::rBL;
    regtable[5] = CPU6::rXL;
    regtable[7] = CPU6::rYL;
    regtable[9] = CPU6::rZL;
    regtable[11] = CPU6::rSL;
    regtable[13] = CPU6::rCL;
    regtable[15] = CPU6::rPL;
    regtable[0] = CPU6::rAU;
    regtable[2] = CPU6::rBU;
    regtable[4] = CPU6::rXU;
    regtable[6] = CPU6::rYU;
    regtable[8] = CPU6::rZU;
    regtable[10] = CPU6::rSU;
    regtable[12] = CPU6::rCU;
    regtable[14] = CPU6::rPU;
    LLVM_DEBUG(dbgs() << "DecodeGPRB " << RegNo << "\n");
    //MCRegister Reg = CPU6::AU + RegNo;
    Inst.addOperand(MCOperand::createReg(regtable[RegNo]));
    return MCDisassembler::Success;
}

template <unsigned N>
static DecodeStatus decodeUImmOperand(MCInst &Inst, uint64_t Imm,
                                      int64_t Address,
                                      const MCDisassembler *Decoder) {
    assert(isUInt<N>(Imm) && "Invalid immediate");
    Inst.addOperand(MCOperand::createImm(Imm));
    return MCDisassembler::Success;
}


template <unsigned N> // unsigned N because this is the bit size we're looking for
static DecodeStatus decodeSImmOperand(MCInst &Inst, int64_t Imm,
                                      int64_t Address,
                                      const MCDisassembler *Decoder) {

    // We're asserting against Uint here because it gets parsed as unsigned data and passed to us                                   
    assert(isUInt<N>(Imm) && "Invalid immediate");
    // Turn that unsigned value into a signed one with an llvm math helper function
    Inst.addOperand(MCOperand::createImm(SignExtend64<N>(Imm)));
    return MCDisassembler::Success;
}


#include "CPU6GenDisassemblerTables.inc"

DecodeStatus CPU6Disassembler::getInstruction(MCInst &MI, uint64_t &Size,
                                               ArrayRef<uint8_t> Bytes,
                                               uint64_t Address,
                                               raw_ostream &CS) const {

    // Use a uint32_t because we have instructions up to 24 bits, which has no easy native type
    uint32_t Inst;
    DecodeStatus Result;

    // We never have an instruction less than 1 byte... seems obvious.. idk if we need this check
    if (Bytes.size() < 1) {
        Size = 0;
        return MCDisassembler::Fail;
    }


    // For CPU6 this is going to be not so straightforward. We'll need to read 1 byte at a time,
    // check if it's a valid instruction, and read up to 2 more bytes, checking each time.
    // read our first byte and check if it's a valid instruction
    Inst = support::endian::read32be(Bytes.data());
    // try to decode only the first byte we read
    Result = decodeInstruction(DecoderTable8, MI, (Inst >> 24), Address, this, STI);
    LLVM_DEBUG(dbgs() << "Trying to decode as 1 byte isntruction.\n");
    if (Result != MCDisassembler::Fail) {
        Size = 1;
        return Result;
    }
    // It wasn't, read in our second byte
    Result = decodeInstruction(DecoderTable16, MI, (Inst >> 16), Address, this, STI);
    LLVM_DEBUG(dbgs() << "Trying to decode as 2 byte instruction.\n");
    if (Result != MCDisassembler::Fail) {
        Size = 2;
        return Result;
    }
    // It wasn't, read in our third byte
    Result = decodeInstruction(DecoderTable24, MI, (Inst >> 8), Address, this, STI);
    LLVM_DEBUG(dbgs() << "Trying to decode as 3 byte instruction.\n");
    if (Result != MCDisassembler::Fail) {
        Size = 3;
        return Result;
    }

    // we failed to decode any instruction
    errs() << "We failed to decode any instruction!.\n";
    return MCDisassembler::Fail;

}