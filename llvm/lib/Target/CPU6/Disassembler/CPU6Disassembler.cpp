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
    regtable[0] = CPU6::A;
    regtable[2] = CPU6::B;
    regtable[4] = CPU6::X;
    regtable[6] = CPU6::Y;
    regtable[8] = CPU6::Z;
    regtable[10] = CPU6::S;
    regtable[12] = CPU6::C;
    regtable[14] = CPU6::P;
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
    regtable[0] = CPU6::AU;
    regtable[2] = CPU6::BU;
    regtable[4] = CPU6::XU;
    regtable[6] = CPU6::YU;
    regtable[8] = CPU6::ZU;
    regtable[10] = CPU6::SU;
    regtable[12] = CPU6::CU;
    regtable[14] = CPU6::PU;
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
    regtable[1] = CPU6::AL;
    regtable[3] = CPU6::BL;
    regtable[5] = CPU6::XL;
    regtable[7] = CPU6::YL;
    regtable[9] = CPU6::ZL;
    regtable[11] = CPU6::SL;
    regtable[13] = CPU6::CL;
    regtable[15] = CPU6::PL;
    LLVM_DEBUG(dbgs() << "DecodeGPRlo " << RegNo << "\n");
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

/*
template <unsigned N>
static DecodeStatus decodeSImmOperand(MCInst &Inst, uint64_t Imm,
                                      int64_t Address,
                                      const MCDisassembler *Decoder) {
    assert(isUInt<N>(Imm) && "Invalid immediate");
    addImplySP(Inst, Address, Decoder);
    // Sign-extend the number in the bottom N bits of Imm
    Inst.addOperand(MCOperand::createImm(SignExtend64<N>(Imm)));
    return MCDisassembler::Success;
}

// TODO: this might not be useful to the CPU6 ISA... should investigate
template <unsigned N>
static DecodeStatus decodeSImmOperandAndLsl1(MCInst &Inst, uint64_t Imm,
                                             int64_t Address,
                                             const MCDisassembler *Decoder) {
    assert(isUInt<N>(Imm) && "Invalid immediate");
    // Sign-extend the number in the bottom N bits of Imm after accounting for
    // the fact that the N bit immediate is stored in N-1 bits (the LSB is
    // always zero)
    Inst.addOperand(MCOperand::createImm(SignExtend64<N>(Imm << 1)));
    return MCDisassembler::Success;
}
*/

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