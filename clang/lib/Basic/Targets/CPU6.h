//===--- CPU6.h - Declare CPU6 target feature support -----------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file declares CPU6 TargetInfo objects.
//
//===----------------------------------------------------------------------===//

#ifndef LLVM_CLANG_LIB_BASIC_TARGETS_CPU6_H
#define LLVM_CLANG_LIB_BASIC_TARGETS_CPU6_H

#include "clang/Basic/TargetInfo.h"
#include "clang/Basic/TargetOptions.h"
#include "llvm/Support/Compiler.h"
#include "llvm/TargetParser/Triple.h"

namespace clang {
namespace targets {

// Centurion CPU6. Pointers and int are 16 bits. Memory is byte-addressable
// with no hardware alignment requirement, so every ABI alignment is one byte.
// That has to match Triple::computeDataLayout and the CPU6 backend: a wider
// alignment makes every local int realign the stack.
class LLVM_LIBRARY_VISIBILITY CPU6TargetInfo : public TargetInfo {
public:
  CPU6TargetInfo(const llvm::Triple &Triple, const TargetOptions &)
      : TargetInfo(Triple) {
    TLSSupported = false;
    VLASupported = false;
    HasUnalignedAccess = true;
    // No atomic instructions; keep Clang from promoting atomics to
    // lock-free builtins the backend cannot lower.
    MaxAtomicPromoteWidth = MaxAtomicInlineWidth = 0;
    PointerWidth = 16;
    PointerAlign = 8;
    ShortWidth = 16;
    ShortAlign = 8;
    IntWidth = 16;
    IntAlign = 8;
    LongWidth = 32;
    LongAlign = 8;
    LongLongWidth = 64;
    LongLongAlign = 8;
    // __int128 is eight words. Alignment stays one byte, like every other
    // integer; the Clang default is 16 bytes and would realign the stack.
    Int128Align = 8;
    SuitableAlign = 8;
    DefaultAlignForAttributeAligned = 8;
    HalfWidth = 16;
    HalfAlign = 8;
    // Float types exist for the language, but there is no FPU. The backend
    // softens them to integer libcalls (useSoftFloat).
    FloatWidth = 32;
    FloatAlign = 8;
    DoubleWidth = 64;
    DoubleAlign = 8;
    LongDoubleWidth = 64;
    LongDoubleAlign = 8;
    SizeType = UnsignedInt;
    PtrDiffType = SignedInt;
    IntPtrType = SignedInt;
    Int16Type = SignedInt;
    WCharType = SignedInt;
    WIntType = SignedInt;
    Char32Type = UnsignedLong;
    SigAtomicType = SignedChar;
    resetDataLayout();
  }

  void getTargetDefines(const LangOptions &Opts,
                        MacroBuilder &Builder) const override;

  llvm::SmallVector<Builtin::InfosShard> getTargetBuiltins() const override {
    return {};
  }

  bool allowsLargerPreferedTypeAlignment() const override { return false; }

  bool hasInt128Type() const override { return true; }

  bool hasFeature(StringRef Feature) const override {
    return Feature == "cpu6";
  }

  // The only processor in CPU6Devices.td. An empty -mcpu is that default.
  // The driver maps "cpu6" to the "CPU6" name the backend looks up.
  bool isValidCPUName(StringRef Name) const override {
    return Name.empty() || Name.equals_insensitive("cpu6");
  }

  void fillValidCPUList(SmallVectorImpl<StringRef> &Values) const override {
    Values.push_back("CPU6");
  }

  bool setCPU(StringRef Name) override { return isValidCPUName(Name); }

  ArrayRef<const char *> getGCCRegNames() const override;

  ArrayRef<TargetInfo::GCCRegAlias> getGCCRegAliases() const override {
    return {};
  }

  // r, m, i, n, g, and X are accepted by TargetInfo. A register is named
  // directly ({A}, {AL}). No CPU6-specific letter.
  bool validateAsmConstraint(const char *&,
                             TargetInfo::ConstraintInfo &) const override {
    return false;
  }

  std::string_view getClobbers() const override { return ""; }

  BuiltinVaListKind getBuiltinVaListKind() const override {
    return TargetInfo::VoidPtrBuiltinVaList;
  }
};

} // namespace targets
} // namespace clang
#endif // LLVM_CLANG_LIB_BASIC_TARGETS_CPU6_H
