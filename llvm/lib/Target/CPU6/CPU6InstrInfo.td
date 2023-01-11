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
class SImmAsmOperand<int width, string suffix = "">
    : ImmAsmOperand<"S", width, suffix> {
}

// Define operands that don't derive definitions elsewhere
// unsigned 4 bit immediate
def uimm4 : Operand<i4> {
    let ParserMatchClass = UImmAsmOperand<4>;
    let DecoderMethod = "decodeUImmOperand<4>";
}
// unsigned 16 bit immediate
def uimm16 : Operand<i16> {
    let ParserMatchClass = UImmAsmOperand<16>;
    let DecoderMethod = "decodeUImmOperand<16>";
}
// signed 8 bit immediate
def simm8 : Operand<i8> {
    let ParserMatchClass = SImmAsmOperand<8>;
    let DecoderMethod = "decodeSImmOperand<8>";
}
// signed 16 bit immediate
def simm16 : Operand<i16> {
    let ParserMatchClass = SImmAsmOperand<16>;
    let DecoderMethod = "decodeSImmOperand<16>";
}


// Most basic instructions to implement for now
// load
// store
// add
// and
// nor
// branch on less than
// branch on equal


//-----------  Control  ---------------//
// Instruction: <|opcode|>
// opcode = 8 bits
//------------------------------------//
// This is a subclass of CenturionInst8 meant for control ops with no in or out dags, so we
// provide an empty list to the superclass and just use this to hold an opcode.
// We aren't using a class like SingleArg16 or anything because we're just writing a single opcode
class Control<bits<8> opcode, string opstr>
        : CenturionInst8<(outs), (ins), opstr> {
      //: CenturionInst8<outs, ins, asmstr> {
    let Inst{7-0} = opcode;
}

def HLT : Control<0x00, "HLT">;     // Halt
def NOP : Control<0x01, "NOP">;     // No-op
def SF : Control<0x02, "SF">;       // Set Fault
def RF : Control<0x03, "RF">;       // Reset Fault
def EI : Control<0x04, "EI">;       // Enable Interrupt System
def DI : Control<0x05, "DI">;       // Disable Interrupt System
def SL : Control<0x06, "SL">;       // Set Link
def RL : Control<0x07, "RL">;       // Reset Link
def CL : Control<0x08, "CL">;       // Complement Link
def RSR : Control<0x09, "RSR">;     // Return from Subroutine
def RI : Control<0x0A, "RI">;       // Return from Inturrupt
def RIM : Control<0x0B, "RIM">;     // Return from Inturrupt Modified
def ELO : Control<0x0C, "ELO">;     // Enable link to teletype
def PCX : Control<0x0D, "PCX">;     // Move PC to X
def DLY : Control<0x0E, "DLY">;     // Delay

//-----------  Branch  ---------------//
// The operation code byte defines the condition being tested
// The displacement byte, b, contains an eight-bit signed value which specifies
// a jump location relative to PC
// Instruction: <| one |opcode|+127, -128|>
//               |  op code   | disp (b) |
// opcode = 8 bits (high half ones)
// displacement = 8 bits
//------------------------------------//
class Branch<bits<8> opcode, string opstr>
      : SingleArg16<opcode, (outs), (ins simm8: $argbyte), opstr, "$argbyte"> { }

def BL : Branch<0x10, "BL">;    // Branch if Link Set
def BNL: Branch<0x11, "BNL">;   // Branch if Link Not Set
def BF : Branch<0x12, "BF">;    // Branch if Fault Set
def BNF: Branch<0x13, "BF">;    // Branch if Fault Not Set
def BZ : Branch<0x14, "BZ">;    // Branch if Equal to Zero
def BNZ: Branch<0x15, "BNZ">;   // Branch if Not Equal to Zero
def BM : Branch<0x16, "BM">;    // Branch if Minus Set
def BP : Branch<0x17, "BP">;    // Branch on Puls
def BGZ: Branch<0x18, "BGZ">;   // Branch if Greater than Zero
def BLE: Branch<0x19, "BLE">;   // Branch if Less Than or Equal to Zero
def BS1: Branch<0x1A, "BS1">;   // Branch if Sense Switch 1 Set
def BS2: Branch<0x1B, "BS2">;   // Branch if Sense Switch 2 Set
def BS3: Branch<0x1C, "BS3">;   // Branch if Sense Switch 3 Set
def BS4: Branch<0x1D, "BS4">;   // Branch if Sense Switch 4 Set
def BTM: Branch<0x1E, "BTM">;   // Branch on Teletype MARK
def BEP: Branch<0x1F, "BEP">;   // Branch on Even Parity

//-----------  SingleReg  --------------//
// There are two types of single-register operations, explicit and implicit.
// Explicit register instructions are two-byte instructions with the source
// register address contained in the second byte.
// Instruction: <| 3(2) |      | sr | #  |>
//               |   opcode    |
// The low-order bits of the second byte are used only for the Increment Register
// and Decrement Register instrucitons and are otherwise ignored
// opcode = 8 bits
// sr = 4 bits 
// # = 4 bits, this is usually the number of times you want to perform an op, CPU6 differs from EE200 here
//------------------------------------//
// Word operation flavor of opcode
class SingleReg16<bits<8> opcode, string opstr>
      : SingleArg16HL<opcode, (outs), (ins GPR: $arghnibble, uimm4: $arglnibble),
                     opstr, "$arghnibble,$arglnibble"> { }

// Byte operation flavor
class SingleReg16_B<bits<8> opcode, string opstr>
      : SingleArg16HL<opcode, (outs), (ins GPRB: $arghnibble, uimm4: $arglnibble),
                     opstr, "$arghnibble,$arglnibble"> { }

class SingleReg16H<bits<8> opcode, string opstr>
      : SingleArg16H<opcode, (outs), (ins GPR: $arghnibble),
                     opstr, "$arghnibble"> { }

class SingleReg16H_B<bits<8> opcode, string opstr>
      : SingleArg16H<opcode, (outs), (ins GPRB: $arghnibble),
                     opstr, "$arghnibble"> { }

def INR : SingleReg16<0x30, "INR">;      // Increment Register
def INRB: SingleReg16_B<0x20, "INRB">;   // Increment Register (Byte mode)
def DCR : SingleReg16<0x31, "DCR">;      // Decrement Register
def DCRB: SingleReg16_B<0x21, "DCRB">;   // Decrement Register (Byte mode)
def CLR : SingleReg16H<0x32, "CLR">;     // Clear Register
def CLRB: SingleReg16H_B<0x22, "CLRB">;  // Clear Register (Byte mode)
def IVR : SingleReg16H<0x33, "IVR">;     // Invert Register
def IVRB: SingleReg16H_B<0x23, "IVRB">;  // Invert Register (Byte mode)
def SRR : SingleReg16<0x34, "SRR">;      // Shift Register Right
def SRRB: SingleReg16_B<0x24, "SRRB">;   // Shift Register Right (Byte mode)
def SLR : SingleReg16<0x35, "SLR">;      // Shift Register Left
def SLRB: SingleReg16_B<0x25, "SLRB">;   // Shift Register Left (Byte mode)
def RRR : SingleReg16<0x36, "RRR">;      // Rotate Register Right
def RRRB: SingleReg16_B<0x26, "RRRB">;   // Rotate Register Right (Byte mode)
def RLR : SingleReg16<0x37, "RLR">;      // Rotate Register Left
def RLRB: SingleReg16_B<0x27, "RLRB">;   // Rotate Register Left (Byte mode)

//-----------  Implicit instructions  ---------------//
// Instruction: <|opcode|>
// opcode = 8 bits
//---------------------------------------------------//
// This is the same as Control near the top of the file, but I want a new name for it to be pretty
class Implicit<bits<8> opcode, string opstr>
        : CenturionInst8<(outs), (ins), opstr> {
    let Inst{7-0} = opcode;
}

def INA : Implicit<0x38, "INA">;        // Increment Accumulator by 1
def INAB: Implicit<0x28, "INAB">;       // Increment Accumulator by 1 (Byte mode)
def DCA : Implicit<0x39, "DCA">;        // Decrement Accumulator by 1
def DCAB: Implicit<0x29, "DCAB">;       // Decrement Accumulator by 1 (Byte mode)
def CLA : Implicit<0x3A, "CLA">;        // Clear Accumulator
def CLAB: Implicit<0x2A, "CLAB">;       // Clear Accumulator (Byte mode)
def IVA : Implicit<0x3B, "IVA">;        // Invert Accumulator
def IVAB: Implicit<0x2B, "IVAB">;       // Invert Accumulator (Byte mode)
def SRA : Implicit<0x3C, "SRA">;        // Shift Accumulator Right
def SRAB: Implicit<0x2C, "SRAB">;       // Shift Accumulator Right (Byte mode)
def SLA : Implicit<0x3D, "SLA">;        // Shift Accumulator Left
def SLAB: Implicit<0x2D, "SLAB">;       // Shift Accumulator Left (Byte mode)
def INX : Implicit<0x3E, "INX">;        // Inrement X Register
def DNX : Implicit<0x3F, "DNX">;        // Decrement X Register


//-----------  DoubleReg  --------------//
// There are two types of double-register operations, explicit and implicit.
// Explicit register instructions are two-byte instructions with the source
// register and destination addresses contained in the second byte.
// Instruction: <| 5(4) |opcode| sr | dr |>
// The low-order bits of the second byte are used only for the Increment Register
// and Decrement Register instrucitons and are otherwise ignored
// opcode = 8 bits
// sr = 4 bits
// dr = 4 bits
//------------------------------------//
// Word operation flavor of opcode
class DoubleReg16<bits<8> opcode, string opstr>
      : SingleArg16HL<opcode, (outs GPR: $arglnibble), (ins GPR: $arghnibble),
                     opstr, "$arghnibble,$arglnibble"> { }
// Byte operation flavor
class DoubleReg16_B<bits<8> opcode, string opstr>
      : SingleArg16HL<opcode, (outs GPRB: $arglnibble), (ins GPRB: $arghnibble),
                     opstr, "$arghnibble,$arglnibble"> { }

def ADD : DoubleReg16<0x50, "ADD">;     // Add
def ADDB: DoubleReg16_B<0x40, "ADDB">;  // Add (Byte mode)
def SUB : DoubleReg16<0x51, "SUB">;     // Subtract
def SUBB: DoubleReg16_B<0x41, "SUBB">;  // Subtract (Byte mode)
def AND : DoubleReg16<0x52, "AND">;     // AND
def ANDB: DoubleReg16_B<0x42, "ANDB">;  // AND (Byte mode)
def ORI : DoubleReg16<0x53, "ORI">;     // OR Inlusive
def ORIB: DoubleReg16_B<0x43, "ORIB">;  // OR Inclusive (Byte mode)
def ORE : DoubleReg16<0x54, "ORE">;     // OR Exclusive
def OREB: DoubleReg16_B<0x44, "OREB">;  // OR Exclusive (Byte mode)
def XFR : DoubleReg16<0x55, "XFR">;     // Transfer
def XFRB: DoubleReg16_B<0x45, "XFRB">;  // Transfer (Byte mode)

//-----------  Implicit Register Rnstructions  ---------------//
// Instruction: <|opcode|>
// opcode = 8 bits
//------------------------------------------------------------//
// This is the same as Control near the top of the file, but I want a new name for it to be pretty
class ImplicitReg<bits<8> opcode, string opstr>
        : CenturionInst8<(outs), (ins), opstr> {
    let Inst{7-0} = opcode;
}

def AAB : ImplicitReg<0x58, "AAB">;     // Add A Register and B Register
def AABB: ImplicitReg<0x48, "AABB">;    // Add A Register and B Register (Byte mode)
def SAB : ImplicitReg<0x59, "SAB">;     // Subtract A Register and B Register
def SABB: ImplicitReg<0x49, "SABB">;    // Subtract A Register and B Register (Byte mode)
def NAB : ImplicitReg<0x5A, "NAB">;     // AND A Register and B Register
def NABB: ImplicitReg<0x4A, "NABB">;    // AND A Register and B Register (Byte mode)
def XAX : ImplicitReg<0x5B, "XAX">;     // Transfer A Register to X Register
def XAXB: ImplicitReg<0x4B, "XAXB">;    // Transfer A Register to X Register (Byte mode)
def XAY : ImplicitReg<0x5C, "XAY">;     // Transfer A Register to Y Register
def XAYB: ImplicitReg<0x4C, "XAYB">;    // Transfer A Register to Y Register (Byte mode)
def XAB : ImplicitReg<0x5D, "XAB">;     // Transfer A Register to B Register
def XABB: ImplicitReg<0x4D, "XABB">;    // Transfer A Register to B Register (Byte mode)
def XAZ : ImplicitReg<0x5E, "XAZ">;     // Transfer A Register to Z Register
def XAZB: ImplicitReg<0x4E, "XAZB">;    // Transfer A Register to Z Register (Byte mode)
def XAS : ImplicitReg<0x5F, "XAS">;     // Transfer A Register to S Register
def XASB: ImplicitReg<0x4F, "XASB">;    // Transfer A Register to S Register (Byte mode)


// TODO: Finish up our Loads and Memory maniuplation instructions

// Testing our weird 3 byte instruction
def LDA : Memory24<0x9, 0x0,     // Load opcode with the 0 M flag means load 16 bit immediate
           //(outs), (ins uimm16 : $argword),
           (outs), (ins uimm16 : $argword),
           "LDA", "$argword">;