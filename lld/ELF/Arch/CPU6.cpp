//===- CPU6.cpp -----------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// CPU6 objects are ELF32 LE (the MCAsmBackend endian). Instruction and data
// fields are big-endian. There is no GOT, PLT, or TLS.
//
//===----------------------------------------------------------------------===//

#include "Symbols.h"
#include "Target.h"
#include "llvm/BinaryFormat/ELF.h"
#include "llvm/Support/Endian.h"

using namespace llvm;
using namespace llvm::object;
using namespace llvm::support::endian;
using namespace llvm::ELF;
using namespace lld;
using namespace lld::elf;

namespace {
class CPU6 final : public TargetInfo {
public:
  CPU6(Ctx &);
  RelExpr getRelExpr(RelType type, const Symbol &s,
                     const uint8_t *loc) const override;
  void relocate(uint8_t *loc, const Relocation &rel,
                uint64_t val) const override;
};
} // namespace

CPU6::CPU6(Ctx &ctx) : TargetInfo(ctx) {
  // Addresses below 0x100 are the register file. The inherited default,
  // 0x10000, is the first address that does not fit in 16 bits.
  defaultImageBase = 0x100;
  // A raw image is copied to 0x100 and executed. Page alignment would insert
  // a gap between the executable and writable segments, so the file would no
  // longer be that image. Alignment gaps stay zero: trapInstr is left unset.
  defaultMaxPageSize = 1;
  defaultCommonPageSize = 1;
}

RelExpr CPU6::getRelExpr(RelType type, const Symbol &s,
                         const uint8_t *loc) const {
  switch (type) {
  case R_CPU6_8_PCREL:
    return R_PC;
  default:
    return R_ABS;
  }
}

void CPU6::relocate(uint8_t *loc, const Relocation &rel, uint64_t val) const {
  switch (rel.type) {
  case R_CPU6_NONE:
    break;
  case R_CPU6_16:
    checkIntUInt(ctx, loc, val, 16, rel);
    write16be(loc, val);
    break;
  case R_CPU6_32:
    checkIntUInt(ctx, loc, val, 32, rel);
    write32be(loc, val);
    break;
  case R_CPU6_8_PCREL: {
    // R_PC is S + A - P. The hardware adds the displacement to the next
    // instruction, one byte after the field.
    int64_t disp = static_cast<int64_t>(val) - 1;
    checkInt(ctx, loc, disp, 8, rel);
    *loc = static_cast<uint8_t>(disp);
    break;
  }
  default:
    Err(ctx) << getErrorLoc(ctx, loc) << "unrecognized relocation " << rel.type;
    break;
  }
}

void elf::setCPU6TargetInfo(Ctx &ctx) { ctx.target.reset(new CPU6(ctx)); }
