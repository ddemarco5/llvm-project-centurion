include "llvm/Target/Target.td"

// Register file description
include "CPU6RegisterInfo.td"

// Which registers carry arguments and results. Filled in as codegen starts.
include "CPU6CallingConv.td"

// For subtargets
include "CPU6Devices.td"

// Instruction description
include "CPU6InstrInfo.td"

// Patterns that map SelectionDAG nodes onto the instructions above.
include "CPU6InstrPatterns.td"
def CPU6InstrInfo : InstrInfo;


// Assembly Printers
def CPU6AsmWriter : AsmWriter {
    string AsmWriterClassName = "InstPrinter";
    bit isMCAsmWriter = 1;
    // The compress emitter (CompressPat) requires it.
    bit PassSubtarget = 1;
}

// Assembly Parsers
def CPU6AsmParser : AsmParser {
  let ShouldEmitMatchRegisterName = 1;
  let ShouldEmitMatchRegisterAltName = 1;
}


// Target Declaration
def CPU6 : Target {
  let InstructionSet = CPU6InstrInfo;
  let AssemblyWriters = [CPU6AsmWriter];
  let AssemblyParsers = [CPU6AsmParser];
}

// LLVM 23 requires every target to remap standard pseudos that use
// PointerLikeRegClass onto a concrete register class. CPU6 pointers are
// 16-bit GPRs. These are not new CPU6 instructions.
defm : RemapAllTargetPseudoPointerOperands<GPR>;