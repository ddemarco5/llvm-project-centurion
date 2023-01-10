include "CPU6InstrFormats.td"

//===----------------------------------------------------------------------===//
// Operand and SDNode transformation definitions.
//===----------------------------------------------------------------------===//

class ImmAsmOperand<string prefix, int width, string suffix> : AsmOperandClass {
    let Name = prefix # "Imm" # width # suffix;
    let RenderMethod = "addImmOperands";
    let DiagnosticType = !strconcat("Invalid", Name);
}

class UImmAsmOperand<int width, string suffix = "">
    : ImmAsmOperand<"U", width, suffix> {
}

// Define operands that don't derive definitions elsewhere
def uimm16 : Operand<i16> {
    let ParserMatchClass = UImmAsmOperand<16>;
    let DecoderMethod = "decodeUImmOperand<16>";
}


// Most basic instructions to implement for now
// load
// store
// add
// and
// nor
// branch on less than
// branch on equal


// The instructions for cpu4 use a B post-fix to indicate they're executing in byte mode
// so for example LDA would be load in word mode, LDAB would be load in byte mode.

// TODO: I can probably move the dag definitions into a class and
// subclass each individual opcode to make the list of instructions nicer

def HLT : Control<0x00, (outs), (ins), "HLT">;

// ADD
def ADD : DoubleReg16<0x50,  // word operation selection bit is on
           (outs GPR : $dr),
           (ins GPR : $sr),
           "ADD $sr, $dr">;  // this is a pattern for the SelectionDAG

def ADDB : DoubleReg16<0x40,  // word operation selection bit is off
            (outs GPRlo : $dr),
            (ins GPRlo : $sr),
            "ADDB $sr, $dr">;


// Testing our weird 3 byte instruction
def LDA : Memory24<0x9, 0x0,     // Load opcode with the 0 M flag means load 16 bit immediate
           (outs), (ins uimm16 : $argword),
           "LDA $argword">;