//===- CPU6.cpp -----------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "ABIInfoImpl.h"
#include "TargetInfo.h"
#include "llvm/ADT/SmallVector.h"

using namespace clang;
using namespace clang::CodeGen;

// CPU6 has four word argument registers (A, B, Y, Z). A scalar return is
// direct: the backend puts an i16 in A, an i32 in A:B, and an i64 or a
// softened double in A, B, Y, Z. An aggregate is passed and returned as that
// many i16s when the whole value fits in the registers still free. CC_CPU6
// already assigns the argument words. A value that does not fit is one
// pointer to memory the caller owns: ByVal stays off, so the backend does
// not copy it into the outgoing argument area. Aggregates use a budget of
// two return words. A return that does not fit is the usual sret pointer
// and spends A before the user's arguments are counted. Raising that budget
// would start returning three- and four-word structs in Y and Z.
namespace {

class CPU6ABIInfo : public DefaultABIInfo {
  static constexpr unsigned NumArgRegs = 4;
  static constexpr unsigned NumRetRegs = 2;

  // Words CC_CPU6 will use. An i8 promotes to one i16. An i32 is two, an i64
  // is four. Rounding the memory size up matches that split.
  uint64_t wordCount(QualType Ty) const {
    return (getContext().getTypeSize(Ty) + 15) / 16;
  }

  // One register: an integer, so a short object uses the big-endian coerce
  // in CGCall. Several registers: a struct of i16s. getDirect flattens that
  // struct into one IR argument per word.
  ABIArgInfo coerceAggregate(QualType Ty) const {
    uint64_t Bits = getContext().getTypeSize(Ty);
    llvm::LLVMContext &Ctx = getVMContext();
    if (Bits <= 16) {
      unsigned CoerceBits = llvm::alignTo(Bits, 8);
      return ABIArgInfo::getDirect(llvm::IntegerType::get(Ctx, CoerceBits));
    }
    unsigned Words = (Bits + 15) / 16;
    llvm::Type *I16 = llvm::Type::getInt16Ty(Ctx);
    SmallVector<llvm::Type *, 4> Elts(Words, I16);
    return ABIArgInfo::getDirect(llvm::StructType::get(Ctx, Elts));
  }

  // The pointer is an i16. It takes one argument register when one is free,
  // and a single stack slot when none is.
  ABIArgInfo passIndirect(QualType Ty, unsigned &Free) const {
    if (Free)
      --Free;
    return getNaturalAlignIndirect(Ty, getDataLayout().getAllocaAddrSpace(),
                                   /*ByVal=*/false);
  }

  // Greedy, same as CC_CPU6: a scalar that needs more words than remain
  // uses the ones left and spills the rest. Later arguments then see no
  // free registers.
  static void takeRegs(uint64_t Need, unsigned &Free) {
    if (Need >= Free)
      Free = 0;
    else
      Free -= static_cast<unsigned>(Need);
  }

  ABIArgInfo classifyArgumentType(QualType Ty, unsigned &Free) const {
    Ty = useFirstFieldIfTransparentUnion(Ty);

    if (const auto *RT = Ty->getAsCanonical<RecordType>()) {
      const RecordDecl *RD = RT->getDecl()->getDefinitionOrSelf();
      // The flexible array is not part of the type size. Passing the prefix
      // in registers would drop it.
      if (RD->hasFlexibleArrayMember())
        return passIndirect(Ty, Free);
      // Itanium passes a non-trivial record as a pointer to a temporary.
      // DirectInMemory must not gain a backend copy either.
      if (getRecordArgABI(RT, getCXXABI()))
        return passIndirect(Ty, Free);
    }

    if (isAggregateTypeForABI(Ty)) {
      if (isEmptyRecord(getContext(), Ty, true))
        return ABIArgInfo::getIgnore();
      uint64_t Words = wordCount(Ty);
      if (Words == 0)
        return ABIArgInfo::getIgnore();
      // The whole aggregate fits, or none of it uses those registers.
      // Splitting it would spill the tail into the outgoing area.
      if (Words <= Free) {
        Free -= static_cast<unsigned>(Words);
        return coerceAggregate(Ty);
      }
      return passIndirect(Ty, Free);
    }

    ABIArgInfo Info = DefaultABIInfo::classifyArgumentType(Ty);
    if (Info.isIndirect())
      return passIndirect(Ty, Free);
    if (!Info.isIgnore())
      takeRegs(wordCount(Ty), Free);
    return Info;
  }

  ABIArgInfo classifyReturnType(QualType RetTy) const {
    if (RetTy->isVoidType())
      return ABIArgInfo::getIgnore();

    if (isAggregateTypeForABI(RetTy)) {
      if (isEmptyRecord(getContext(), RetTy, true))
        return ABIArgInfo::getIgnore();
      uint64_t Words = wordCount(RetTy);
      if (Words != 0 && Words <= NumRetRegs)
        return coerceAggregate(RetTy);
      return getNaturalAlignIndirect(RetTy,
                                     getDataLayout().getAllocaAddrSpace(),
                                     /*ByVal=*/false);
    }

    return DefaultABIInfo::classifyReturnType(RetTy);
  }

public:
  CPU6ABIInfo(CodeGenTypes &CGT) : DefaultABIInfo(CGT) {}

  void computeInfo(CGFunctionInfo &FI) const override {
    if (!getCXXABI().classifyReturnType(FI))
      FI.getReturnInfo() = classifyReturnType(FI.getReturnType());

    unsigned Free = NumArgRegs;
    // The sret pointer is the first argument and lands in A.
    if (FI.getReturnInfo().isIndirect())
      --Free;

    for (auto &Arg : FI.arguments())
      Arg.info = classifyArgumentType(Arg.type, Free);
  }
};

class CPU6TargetCodeGenInfo : public TargetCodeGenInfo {
public:
  CPU6TargetCodeGenInfo(CodeGenTypes &CGT)
      : TargetCodeGenInfo(std::make_unique<CPU6ABIInfo>(CGT)) {}
};

} // namespace

std::unique_ptr<TargetCodeGenInfo>
CodeGen::createCPU6TargetCodeGenInfo(CodeGenModule &CGM) {
  return std::make_unique<CPU6TargetCodeGenInfo>(CGM.getTypes());
}
