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

// ADD
def ADD : DoubleReg16<0x50,  // word operation selection bit is on
            (outs GPR : $dr),
            (ins GPR : $sr),
            "LDA $sr, $dr">;  // this is a pattern for the SelectionDAG

def ADDB : DoubleReg16<0x40,  // word operation selection bit is off
            (outs GPRlo : $dr),
            (ins GPRlo : $sr),
            "ADDB $sr, $dr">;