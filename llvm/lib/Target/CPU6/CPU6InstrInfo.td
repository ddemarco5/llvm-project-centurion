include "CPU6InstrFormats.td"

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

// LOAD
//def LDA : Memory24<0x9,  // operating in word mode
//            (outs GPR : $dr),
//            (ins i16imm : $src),
//            "LDA $dr, $src">;


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
           (outs), (ins i16imm : $argword),
           "LDA $argword">;