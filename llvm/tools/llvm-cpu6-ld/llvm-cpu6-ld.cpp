//===-- llvm-cpu6-ld.cpp - CPU6 static linker -----------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// Links relocatable CPU6 ELF objects into one flat image at a chosen base
// address. R_CPU6_16 is a big-endian absolute address (S + A). R_CPU6_8_PCREL
// is a signed displacement from the instruction after the field,
// S + A - (P + 1). The ELF file itself is little-endian.

#include "llvm/ADT/STLExtras.h"
#include "llvm/ADT/StringMap.h"
#include "llvm/BinaryFormat/ELF.h"
#include "llvm/Object/ELF.h"
#include "llvm/Support/CommandLine.h"
#include "llvm/Support/Error.h"
#include "llvm/Support/FileSystem.h"
#include "llvm/Support/Format.h"
#include "llvm/Support/InitLLVM.h"
#include "llvm/Support/MathExtras.h"
#include "llvm/Support/MemoryBuffer.h"
#include "llvm/Support/WithColor.h"
#include "llvm/Support/raw_ostream.h"
#include <cinttypes>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <limits>
#include <optional>

using namespace llvm;
using namespace llvm::object;
using namespace llvm::ELF;

static cl::opt<std::string>
    OutputFilename("o", cl::desc("Write the linked image to <file>"),
                   cl::value_desc("file"), cl::Required);

static cl::opt<std::string>
    BaseAddress("base", cl::desc("Address of the first byte of the image"),
                cl::value_desc("address"), cl::Required);

static cl::opt<std::string>
    EntrySymbol("e", cl::desc("Print the address of <symbol>"),
                cl::value_desc("symbol"));

static cl::list<std::string> InputFilenames(cl::Positional,
                                            cl::desc("<object files>"),
                                            cl::OneOrMore);

[[noreturn]] static void fail(const Twine &Msg) {
  WithColor::error(errs(), "llvm-cpu6-ld") << Msg << "\n";
  std::exit(1);
}

template <class T> static T must(Expected<T> V, const Twine &What) {
  if (!V)
    fail(What + ": " + toString(V.takeError()));
  return std::move(*V);
}

namespace {

struct Section {
  unsigned Input = 0;
  unsigned Index = 0;
  unsigned Group = 0;
  uint64_t Align = 1;
  uint64_t Size = 0;
  uint64_t Addr = 0;
  uint64_t Off = 0;
  std::string Name;
  bool NoBits = false;
  std::vector<uint8_t> Bytes;
};

struct ResolvedSym {
  std::string Name;
  bool External = false;
  std::optional<uint64_t> Addr;
};

struct GlobalDef {
  uint64_t Addr = 0;
  unsigned Binding = 0;
  std::string File;
};

struct Input {
  std::string Name;
  std::unique_ptr<MemoryBuffer> Buf;
  std::optional<ELFFile<ELF32LE>> Elf;
  unsigned NumSections = 0;
  bool HasSymTab = false;
  unsigned SymTabIndex = 0;
  std::vector<ResolvedSym> Syms;
};

} // namespace

static unsigned sectionGroup(uint32_t Type, uint64_t Flags) {
  // NOBITS is last so .bss follows initialized data. Executable bytes come
  // first, then read-only, then writable.
  if (Type == SHT_NOBITS)
    return 3;
  if (Flags & SHF_EXECINSTR)
    return 0;
  if (Flags & SHF_WRITE)
    return 2;
  return 1;
}

static void checkIdent(const Input &In) {
  StringRef Buf = In.Buf->getBuffer();
  if (Buf.size() < EI_NIDENT ||
      memcmp(Buf.data(), ElfMagic, strlen(ElfMagic)) != 0)
    fail(In.Name + ": not an ELF object");
  if (static_cast<unsigned char>(Buf[EI_CLASS]) != ELFCLASS32 ||
      static_cast<unsigned char>(Buf[EI_DATA]) != ELFDATA2LSB)
    fail(In.Name + ": not a 32-bit little-endian object");
}

static void checkHeader(const Input &In) {
  const auto &Hdr = In.Elf->getHeader();
  if (Hdr.e_type != ET_REL)
    fail(In.Name + ": not a relocatable object");
  if (Hdr.e_machine != EM_CPU6)
    fail(In.Name + ": not a CPU6 object");
}

static std::vector<Section> collectSections(ArrayRef<Input> Files) {
  std::vector<Section> Out;
  for (unsigned FI = 0; FI < Files.size(); ++FI) {
    const Input &In = Files[FI];
    auto Sections = must(In.Elf->sections(), In.Name);
    for (unsigned SI = 0; SI < Sections.size(); ++SI) {
      const auto &S = Sections[SI];
      if (S.sh_type == SHT_REL || S.sh_type == SHT_CREL)
        fail(In.Name + ": SHT_REL relocations are not supported");
      if (S.sh_type == SHT_GROUP || (S.sh_flags & SHF_GROUP))
        fail(In.Name + ": section groups are not supported");
      if (S.sh_flags & SHF_TLS)
        fail(In.Name + ": thread-local storage is not supported");
      if (!(S.sh_flags & SHF_ALLOC))
        continue;
      StringRef Name = must(In.Elf->getSectionName(S), In.Name);
      if (Name == ".eh_frame" || Name.starts_with(".eh_frame."))
        continue;
      if (S.sh_size > 0x10000)
        fail(In.Name + ": section " + Name +
             " is larger than the address space");

      Section Sec;
      Sec.Input = FI;
      Sec.Index = SI;
      Sec.Group = sectionGroup(S.sh_type, S.sh_flags);
      Sec.Align = S.sh_addralign ? S.sh_addralign : 1;
      Sec.Size = S.sh_size;
      Sec.Name = Name.str();
      Sec.NoBits = S.sh_type == SHT_NOBITS;
      if (!Sec.NoBits) {
        ArrayRef<uint8_t> Bytes =
            must(In.Elf->getSectionContents(S), In.Name + ": " + Name);
        if (Bytes.size() != S.sh_size)
          fail(In.Name + ": section " + Name + " has a truncated body");
        Sec.Bytes.assign(Bytes.begin(), Bytes.end());
      }
      Out.push_back(std::move(Sec));
    }
  }
  return Out;
}

// Returns the address one past the image. Byte 0 of the image is Base, so a
// section whose address is aligned above Base leaves zero padding in front.
static uint64_t assignAddresses(uint64_t Base, MutableArrayRef<Section> Sections) {
  uint64_t Cursor = Base;
  for (Section &S : Sections) {
    Cursor = alignTo(Cursor, S.Align);
    S.Addr = Cursor;
    S.Off = Cursor - Base;
    if (S.Size > std::numeric_limits<uint64_t>::max() - Cursor)
      fail("section layout overflow");
    Cursor += S.Size;
  }
  if (Base > 0xFFFF || Cursor > 0x10000)
    fail("load address range does not fit in 16 bits");
  return Cursor;
}

static void defineGlobal(StringMap<GlobalDef> &Globals, const Input &In,
                         const ResolvedSym &Sym, unsigned Binding) {
  if (Sym.Name.empty())
    fail(In.Name + ": global symbol with no name");
  GlobalDef Def;
  Def.Addr = *Sym.Addr;
  Def.Binding = Binding;
  Def.File = In.Name;
  auto It = Globals.find(Sym.Name);
  if (It == Globals.end()) {
    Globals.insert(std::make_pair(Sym.Name, std::move(Def)));
    return;
  }
  GlobalDef &Existing = It->getValue();
  // A strong definition overrides a weak one. Two strong definitions, or a
  // second strong after a strong, cannot both occupy the image.
  if (Existing.Binding != STB_WEAK && Binding != STB_WEAK)
    fail(In.Name + ": duplicate symbol: " + Sym.Name +
         " (already defined in " + Existing.File + ")");
  if (Existing.Binding == STB_WEAK && Binding != STB_WEAK)
    Existing = std::move(Def);
}

static void resolveSymbols(Input &In, ArrayRef<const Section *> Placed,
                           StringMap<GlobalDef> &Globals) {
  auto Sections = must(In.Elf->sections(), In.Name);
  const typename ELFFile<ELF32LE>::Elf_Shdr *SymTab = nullptr;
  for (unsigned SI = 0; SI < Sections.size(); ++SI) {
    if (Sections[SI].sh_type != SHT_SYMTAB)
      continue;
    if (In.HasSymTab)
      fail(In.Name + ": multiple symbol tables are not supported");
    In.HasSymTab = true;
    In.SymTabIndex = SI;
    SymTab = &Sections[SI];
  }
  if (!SymTab)
    return;

  StringRef StrTab = must(In.Elf->getStringTableForSymtab(*SymTab), In.Name);
  auto Syms = must(In.Elf->symbols(SymTab), In.Name);
  In.Syms.reserve(Syms.size());
  for (const auto &Sym : Syms) {
    ResolvedSym RS;
    RS.Name = std::string(must(Sym.getName(StrTab), In.Name));
    RS.External = Sym.isExternal();
    if (Sym.isCommon())
      fail(In.Name + ": common symbol: " + RS.Name);
    if (Sym.getType() == STT_TLS)
      fail(In.Name + ": thread-local symbol: " + RS.Name);
    if (Sym.isUndefined()) {
      // A reference. The address comes from another object, if any.
    } else if (Sym.isAbsolute()) {
      RS.Addr = Sym.st_value;
    } else if (Sym.st_shndx >= SHN_LORESERVE) {
      fail(In.Name + ": unsupported symbol index for " + RS.Name);
    } else if (Sym.st_shndx < Placed.size() && Placed[Sym.st_shndx]) {
      RS.Addr = Placed[Sym.st_shndx]->Addr + Sym.st_value;
    }
    if (RS.External && RS.Addr)
      defineGlobal(Globals, In, RS, Sym.getBinding());
    In.Syms.push_back(std::move(RS));
  }
}

static uint64_t symbolAddress(const Input &In, uint32_t Index,
                              const StringMap<GlobalDef> &Globals) {
  // Symbol 0 has no name. The value of the relocation is the addend alone.
  if (Index == 0)
    return 0;
  if (Index >= In.Syms.size())
    fail(In.Name + ": relocation refers to a missing symbol");
  const ResolvedSym &Sym = In.Syms[Index];
  if (Sym.External) {
    auto It = Globals.find(Sym.Name);
    if (It == Globals.end())
      fail(In.Name + ": undefined symbol: " + Sym.Name);
    return It->getValue().Addr;
  }
  if (!Sym.Addr)
    fail(In.Name + ": undefined symbol: " + Sym.Name);
  return *Sym.Addr;
}

static void applyRelocations(const Input &In, ArrayRef<const Section *> Placed,
                             const StringMap<GlobalDef> &Globals,
                             MutableArrayRef<uint8_t> Image) {
  auto Sections = must(In.Elf->sections(), In.Name);
  for (const auto &S : Sections) {
    if (S.sh_type != SHT_RELA)
      continue;
    if (!In.HasSymTab || S.sh_link != In.SymTabIndex)
      fail(In.Name + ": relocation refers to an unknown symbol table");
    if (S.sh_info >= Placed.size())
      fail(In.Name + ": relocation refers to a missing section");
    const Section *Target = Placed[S.sh_info];
    // Relocations against a dropped section, such as .eh_frame, are not part
    // of the image.
    if (!Target)
      continue;
    for (const auto &Rel : must(In.Elf->relas(S), In.Name)) {
      uint32_t Type = Rel.getType(/*isMips64EL=*/false);
      if (Type == R_CPU6_NONE)
        continue;
      uint64_t Width = Type == R_CPU6_16 ? 2 : 1;
      if (Type != R_CPU6_16 && Type != R_CPU6_8_PCREL) {
        if (Type == R_CPU6_32)
          fail(In.Name + ": R_CPU6_32 in section " + Target->Name);
        fail(In.Name + ": unrecognized relocation " + Twine(Type) +
             " in section " + Target->Name);
      }
      if (Rel.r_offset > Target->Size || Width > Target->Size - Rel.r_offset)
        fail(In.Name + ": relocation offset is outside " + Target->Name);

      uint64_t SAddr = symbolAddress(
          In, Rel.getSymbol(/*isMips64EL=*/false), Globals);
      int64_t Value = static_cast<int64_t>(SAddr) + Rel.r_addend;
      uint64_t At = Target->Off + Rel.r_offset;
      if (Type == R_CPU6_16) {
        if (Value < 0 || Value > 0xFFFF)
          fail(In.Name + ": R_CPU6_16 value out of range");
        Image[At] = static_cast<uint8_t>(static_cast<uint64_t>(Value) >> 8);
        Image[At + 1] = static_cast<uint8_t>(Value);
        continue;
      }
      int64_t Place = static_cast<int64_t>(Target->Addr + Rel.r_offset);
      int64_t Disp = Value - (Place + 1);
      if (!isInt<8>(Disp))
        fail(In.Name + ": R_CPU6_8_PCREL displacement out of range");
      Image[At] = static_cast<uint8_t>(Disp);
    }
  }
}

static void writeImage(ArrayRef<uint8_t> Image) {
  std::error_code EC;
  raw_fd_ostream OS(OutputFilename, EC, sys::fs::OF_None);
  if (EC)
    fail("cannot write " + OutputFilename + ": " + EC.message());
  OS.write(reinterpret_cast<const char *>(Image.data()), Image.size());
}

static void printEntry(const StringMap<GlobalDef> &Globals) {
  std::string Wanted = EntrySymbol;
  bool Explicit = !Wanted.empty();
  if (!Explicit)
    Wanted = "_start";
  auto It = Globals.find(Wanted);
  if (It != Globals.end()) {
    outs() << format("0x%04" PRIx64 "\n", It->getValue().Addr);
    return;
  }
  if (Explicit)
    fail("entry symbol not found: " + Wanted);
}

int main(int argc, char **argv) {
  InitLLVM X(argc, argv);
  cl::ParseCommandLineOptions(argc, argv,
                              "cpu6 static linker\n\n"
                              "  Link relocatable CPU6 objects into a flat image.\n");

  uint64_t Base = 0;
  if (StringRef(BaseAddress).getAsInteger(0, Base))
    fail("invalid base address: " + BaseAddress);
  if (Base < 0x100) {
    WithColor::warning(errs(), "llvm-cpu6-ld")
        << "base " << format("0x%04" PRIx64, Base)
        << " is in the register file (addresses below 0x0100)\n";
  }

  std::vector<Input> Files;
  Files.reserve(InputFilenames.size());
  for (StringRef Name : InputFilenames) {
    Input In;
    In.Name = Name.str();
    ErrorOr<std::unique_ptr<MemoryBuffer>> BufOrErr =
        MemoryBuffer::getFile(Name);
    if (!BufOrErr)
      fail("cannot open " + In.Name + ": " + BufOrErr.getError().message());
    In.Buf = std::move(*BufOrErr);
    checkIdent(In);
    In.Elf = must(ELFFile<ELF32LE>::create(In.Buf->getBuffer()), In.Name);
    checkHeader(In);
    Files.push_back(std::move(In));
  }

  std::vector<Section> Sections = collectSections(Files);
  stable_sort(Sections, [](const Section &A, const Section &B) {
    return A.Group < B.Group;
  });
  uint64_t End = assignAddresses(Base, Sections);
  uint64_t ImageSize = End - Base;

  std::vector<std::vector<const Section *>> Placed(Files.size());
  for (unsigned FI = 0; FI < Files.size(); ++FI) {
    auto FileSections = must(Files[FI].Elf->sections(), Files[FI].Name);
    Files[FI].NumSections = FileSections.size();
    Placed[FI].assign(FileSections.size(), nullptr);
  }
  for (const Section &S : Sections)
    Placed[S.Input][S.Index] = &S;

  StringMap<GlobalDef> Globals;
  for (unsigned FI = 0; FI < Files.size(); ++FI)
    resolveSymbols(Files[FI], Placed[FI], Globals);

  std::vector<uint8_t> Image(ImageSize, 0);
  for (const Section &S : Sections) {
    if (S.NoBits)
      continue;
    std::copy(S.Bytes.begin(), S.Bytes.end(), Image.begin() + S.Off);
  }
  for (unsigned FI = 0; FI < Files.size(); ++FI)
    applyRelocations(Files[FI], Placed[FI], Globals, Image);

  // Entry lookup happens before the file is written, so a missing -e symbol
  // does not leave an image behind.
  std::string Wanted = EntrySymbol;
  if (!Wanted.empty() && Globals.find(Wanted) == Globals.end())
    fail("entry symbol not found: " + Wanted);

  writeImage(Image);
  printEntry(Globals);
  return 0;
}
