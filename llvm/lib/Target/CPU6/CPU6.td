include "llvm/Target/Target.td"

// Register file description
include "CPU6RegisterInfo.td"

// For subtargets
include "CPU6Devices.td"

// Instruction description
include "CPU6InstrInfo.td"
def CPU6InstrInfo : InstrInfo;


// Assembly Printers
def CPU6AsmWriter : AsmWriter {
    string AsmWriterClassName = "InstPrinter";
    bit isMCAsmWriter = 1;
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