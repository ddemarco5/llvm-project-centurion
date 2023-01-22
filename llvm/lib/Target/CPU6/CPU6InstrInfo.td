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
// unsigned 8 bit immediate
def uimm8 : Operand<i8> {
    let ParserMatchClass = UImmAsmOperand<8>;
    let DecoderMethod = "decodeUImmOperand<8>";
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

// a parse method for (PC)+${arg}
// def PCOffsetOperand : AsmOperandClass {
//     let Name = "PCOffsetOperand";
//     let RenderMethod = "addImmOperands";
//     let PredicateMethod = "isToken"; // IDK about this
//     let ParserMethod = "parsePCOffset";
// }

// def pcoffimm8 : Operand<i8> {
//     let ParserMatchClass = PCOffsetOperand;
// }


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
def RSYS: Control<0x0F, "RSYS">;    // Return from JSYS using stack

//---------- CPU6 2E instructions-----//
// Instruction: <|  opcode   |  sel | M | N |>
//               |  byte 1   |     byte 2   | 
// opcode: 1 byte
// sel: byte 2 high nibble
// M and N: byte 2 low nibble, 2 bits each

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
def BNF: Branch<0x13, "BNF">;    // Branch if Fault Not Set
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
def BIE: Branch<0x1E, "BIE">;   // Branch on interrupts enabled
def BEP: Branch<0x1F, "BEP">;   // Branch on AH at interrupt level 1 bit 0 set (probably)

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


//------------------------------------//
// Memory reference instructions in CPU6 are a bit strange. They range from
// 3 instruction lengths. 8, 16, and 24 bits. They are separated in the EE200
// book as 4 bit opcodes and an M code. The M code will dictate the 
// possible length of instructions (there can be multiple), as well as
// how to interpret the operands. The M codes are as follows:
//  ----------   M -------------
// 0 - Literal "op"; Operand is an immediate and is 16 bits
// 1 - Direct "(op)"; Operand is a 16 bit address pointer, and as such is 16 bits
// 2 - Indirect "((op))"; Operand is a 16 bit address pointer that will be dereferenced.
//               Meaning the address we're pointing to will be followed once more
//               and data will be read from there. It's also 16 bits in length
// 3 - Relative "(PC)+b"; Operand is an 8 bit address that is treated as a displacement to
//               be applied to the program counter
// 4 - Relative Indirect; "((PC)+b)"; Same as above, but the data at address+displacement 
//                        will be treated as a pointer which will be accessed.
// 5 - Indexed Addressing; This is how all register addressing and modes
//                         of doing so are defined. The layout looks like this.
// | opcode  |   5    |   r   |    M'   |   displacement   |
// |    upper byte    |    middle byte  |    lower byte    |
// 
//         ----------   M' -------------
//         r is the register operand and M' is as follows:
//         0 "(r)" - Use register directly as address
//         1 "(r)" - Use register as address and increment after use
//         2 "(r-dec)" - Decrement register and use as address
//         3 - Unused
//         4 "((r))" - Use regiser as indirect address
//         5 "((r)), inc" - Use register as indirect address and increment after use
//         6 "((r-dec))" - Decrement register and use as indirect address
//         7 - Not used
//		--- 16 bit instructions above, 24 bit below
//         8 "(r+disp)" - Add displacement byte to register and use as direct address
//         9 "(r+disp), inc" - Add displacement byte and use as direct address, then increment register
//         A "(r-dec+disp)" - Decrement register, add displacement byte, and use as direct address
//         B - Not used
//         C "(r+disp)" - Add displacement to register, and use as direct address
//         D "((r+disp)), inc" - Add displacement to register, and use as indirect address, the increment register after
//         E "((r-dec+disp))" - Decrement register, add displacement byte, and use as indirect address
//         F - Not used
//     !!IMPORTANT!! - Inc/decrementing will be by 1 or 2, depending on if instruction
//                     is used in byte or word mode
// 
// 8 - Register addressing; Operation layout is as follows
// | opcode | 8-F  |        The low order nibble is used as follows:
// |     byte      |            8 - A Register
//                              9 - B Register
//                              A - X Register
//                              B - Y Register
//                              C - Z Register
//                              D - S Register
//                              E - C Register
//                              F - P Register
//  
//------------------------------------//
// Byte flavor of opcode
class MemRef8<bits<4> opcode, bits<4> M, string opstr>
      : Memory8<opcode, M, (outs), (ins), opstr> { }
// Word flavor of opcode
// Passing in an DAGOperand will let us specify the dag arg type nicely in the opcode definition line
class MemRef16<bits<4> opcode, bits<4> M, DAGOperand optype, string opstr, string argstr="$arg">
      : Memory16<opcode, M, (outs), (ins optype: $arg), opstr, argstr> { }
// For our strange instructions
class MemRef16Strange<bits<5> opcode, bits<3> M, DAGOperand optype, string opstr, string argstr="$arg">
      : Memory16Strange<opcode, M, (outs), (ins optype: $arg), opstr, argstr> { }
// Two byte m prime flavor of opcode, only optype we'll need here is GPR or GPRB
class MemRef16Index<bits<4> opcode, bits<4> m_prime, DAGOperand optype, string opstr, string argstr="$arg">
      : Memory16Index<opcode, m_prime, (outs), (ins optype: $arg), opstr, argstr> { }
class MemRef16IndexStrange<bits<5> opcode, bits<4> m_prime, DAGOperand optype, string opstr, string argstr="$arg">
      : Memory16IndexStrange<opcode, m_prime, (outs), (ins optype: $arg), opstr, argstr> { }
// Three byte flavor of opcode
class MemRef24<bits<4> opcode, bits<4> M, DAGOperand optype, string opstr, string argstr="$arg">
      : Memory24<opcode, M, (outs), (ins optype: $arg), opstr, argstr> { }
class MemRef24Strange<bits<5> opcode, bits<3> M, DAGOperand optype, string opstr, string argstr="$arg">
      : Memory24Strange<opcode, M, (outs), (ins optype: $arg), opstr, argstr> { }
// Three byte m_rime flavor of opcode, its M is always 5 so we don't bother passing that in
class MemRef24Index<bits<4> opcode, bits<4> m_prime, DAGOperand optype, string opstr, string argstr="$r,$arg">
      : Memory24Index<opcode, m_prime, (outs), (ins optype: $r, i8imm: $arg),
                      opstr, argstr> { }
class MemRef24IndexStrange<bits<5> opcode, bits<4> m_prime, DAGOperand optype, string opstr, string argstr="$r,$arg">
      : Memory24IndexStrange<opcode, m_prime, (outs), (ins optype: $r, i8imm: $arg),
                      opstr, argstr> { }

class Memop<string name, int opcw, int opcb> {
    string Name = name;
    int Opcodew = opcw;
    int Opcodeb = opcb;
}

foreach OP = [
            Memop<"LDA", 0x9, 0x8>,
            Memop<"STA", 0xB, 0xA>,
            Memop<"LDB", 0xD, 0xC>,
            Memop<"STB", 0xF, 0xE>
        ] in {
    def OP.Name#_0 : MemRef24<OP.Opcodew, 0x0, i16imm, OP.Name>;
    def OP.Name#B_0 : MemRef24<OP.Opcodeb, 0x0, i16imm, OP.Name#"B">;
    def OP.Name#_1 : MemRef24<OP.Opcodew, 0x1, i16imm, OP.Name, "(${arg})">;        //(ptr)
    def OP.Name#B_1 : MemRef24<OP.Opcodeb, 0x1, i16imm, OP.Name#"B", "(${arg})">;   //(ptr)
    def OP.Name#_2 : MemRef24<OP.Opcodew, 0x2, i16imm, OP.Name, "((${arg}))">;      //((ptr))
    def OP.Name#B_2 : MemRef24<OP.Opcodeb, 0x2, i16imm, OP.Name#"B", "((${arg}))">; //((ptr))
    def OP.Name#_3 : MemRef16<OP.Opcodew, 0x3, i8imm, OP.Name, "(PC)+${arg}">;      //offset
    def OP.Name#B_3 : MemRef16<OP.Opcodeb, 0x3, i8imm, OP.Name#"B", "(PC)+${arg}">; //offset
    def OP.Name#_4 : MemRef16<OP.Opcodew, 0x4, i8imm, OP.Name, "((PC)+${arg})">;    //((offset))
    def OP.Name#B_4 : MemRef16<OP.Opcodeb, 0x4, i8imm, OP.Name#"B", "((PC)+${arg})">; //((offset))
    def OP.Name#_5_0: MemRef16Index<OP.Opcodew, 0x0, GPR, OP.Name, "(${arg})">;     //(r)    
    def OP.Name#B_5_0: MemRef16Index<OP.Opcodeb, 0x0, GPRB, OP.Name#"B", "(${arg})">; //(r)
    def OP.Name#_5_1: MemRef16Index<OP.Opcodew, 0x1, GPR, OP.Name#"_I", "(${arg})">; //I (r)
    def OP.Name#B_5_1: MemRef16Index<OP.Opcodeb, 0x1, GPRB, OP.Name#"B_I", "(${arg})">; //I (r)      
    def OP.Name#_5_2: MemRef16Index<OP.Opcodew, 0x2, GPR, OP.Name#"_D", "(${arg})">;    //D (r)
    def OP.Name#B_5_2: MemRef16Index<OP.Opcodeb, 0x2, GPRB, OP.Name#"B_D", "(${arg})">; //D (r)
    // 3 is not used
    def OP.Name#_5_4: MemRef16Index<OP.Opcodew, 0x4, GPR, OP.Name, "((${arg}))">;       //((r))
    def OP.Name#B_5_4: MemRef16Index<OP.Opcodeb, 0x4, GPRB, OP.Name#"B", "((${arg}))">; //((r))
    def OP.Name#_5_5: MemRef16Index<OP.Opcodew, 0x5, GPR, OP.Name#"_I", "((${arg}))">;  //I ((r))
    def OP.Name#B_5_5: MemRef16Index<OP.Opcodeb, 0x5, GPRB, OP.Name#"B_I", "((${arg}))">;   //I ((r))
    def OP.Name#_5_6: MemRef16Index<OP.Opcodew, 0x6, GPR, OP.Name#"_D", "((${arg}))">;  //D ((r))
    def OP.Name#B_5_6: MemRef16Index<OP.Opcodeb, 0x6, GPRB, OP.Name#"B_D", "((${arg}))">;   //D ((r))
    // 7 is not used
    def OP.Name#_5_8: MemRef24Index<OP.Opcodew, 0x8, GPR, OP.Name, "(${r}),$arg">;      //(r),disp
    def OP.Name#B_5_8: MemRef24Index<OP.Opcodeb, 0x8, GPRB, OP.Name#"B", "(${r}),$arg">;    //(r),disp
    def OP.Name#_5_9: MemRef24Index<OP.Opcodew, 0x9, GPR, OP.Name#"_I", "(${r}),$arg">; //I (r),disp
    def OP.Name#B_5_9: MemRef24Index<OP.Opcodeb, 0x9, GPRB, OP.Name#"B_I", "(${r}),$arg">;  //I (r),disp
    def OP.Name#_5_A: MemRef24Index<OP.Opcodew, 0xA, GPR, OP.Name#"_D", "(${r}),$arg">;  //D (r),disp
    def OP.Name#B_5_A: MemRef24Index<OP.Opcodeb, 0xA, GPRB, OP.Name#"B_D", "(${r}),$arg">;  //D (r),disp
    // B is not used
    def OP.Name#_5_C: MemRef24Index<OP.Opcodew, 0xC, GPR, OP.Name, "(${r}),${arg}">;  //(r),disp
    def OP.Name#B_5_C: MemRef24Index<OP.Opcodeb, 0xC, GPRB, OP.Name#"B", "(${r}),${arg}">;  //(r),disp
    def OP.Name#_5_D: MemRef24Index<OP.Opcodew, 0xD, GPR, OP.Name#"_I", "((${r})),$arg">;   //I ((r)),disp
    def OP.Name#B_5_D: MemRef24Index<OP.Opcodeb, 0xD, GPRB, OP.Name#"B_I", "((${r})),$arg">;   //I ((r)),disp
    def OP.Name#_5_E: MemRef24Index<OP.Opcodew, 0xE, GPR, OP.Name#"_D", "((${r})),$arg">;   //D ((r)),disp
    def OP.Name#B_5_E: MemRef24Index<OP.Opcodeb, 0xE, GPRB, OP.Name#"B_D", "((${r})),$arg">;   //D ((r)),disp
    // F is not used
    // These are the implicits, they have no operands so they literally can't be implemented
    // without virtual instructions
    def OP.Name#_A: MemRef8<OP.Opcodew, 0x8, OP.Name#"_A">;  // A register
    def OP.Name#B_A: MemRef8<OP.Opcodeb, 0x8, OP.Name#"B_A">;  // A register
    def OP.Name#_B: MemRef8<OP.Opcodew, 0x9, OP.Name#"_B">;  // B register
    def OP.Name#B_B: MemRef8<OP.Opcodeb, 0x9, OP.Name#"B_B">;  // B register
    def OP.Name#_X: MemRef8<OP.Opcodew, 0xA, OP.Name#"_X">;  // X register
    def OP.Name#B_X: MemRef8<OP.Opcodeb, 0xA, OP.Name#"B_X">;  // X register
    def OP.Name#_Y: MemRef8<OP.Opcodew, 0xB, OP.Name#"_Y">;  // Y register
    def OP.Name#B_Y: MemRef8<OP.Opcodeb, 0xB, OP.Name#"B_Y">;  // Y register
    def OP.Name#_Z: MemRef8<OP.Opcodew, 0xC, OP.Name#"_Z">;  // Z register
    def OP.Name#B_Z: MemRef8<OP.Opcodeb, 0xC, OP.Name#"B_Z">;  // Z register
    def OP.Name#_S: MemRef8<OP.Opcodew, 0xD, OP.Name#"_S">;  // S register
    def OP.Name#B_S: MemRef8<OP.Opcodeb, 0xD, OP.Name#"B_S">;  // S register
    def OP.Name#_C: MemRef8<OP.Opcodew, 0xE, OP.Name#"_C">;  // C register
    def OP.Name#B_C: MemRef8<OP.Opcodeb, 0xE, OP.Name#"B_C">;  // C register
    def OP.Name#_P: MemRef8<OP.Opcodew, 0xF, OP.Name#"_P">;  // P register
    def OP.Name#B_P: MemRef8<OP.Opcodeb, 0xF, OP.Name#"B_P">;  // P register
}

class Memopstrange<string name, bits<5> opc> {
    string Name = name;
    int Opcode = opc;
}

foreach OP = [
            Memopstrange<"LDX", 0b01100>,
            Memopstrange<"STX", 0b01101>,
            Memopstrange<"JMP", 0b01110>,
            Memopstrange<"JSR", 0b01111>
        ] in {
    // JMP and JSR don't have an M 0 variant
    if !or(!eq(OP.Name, "LDX"), !eq(OP.Name,"STX")) then {
        def OP.Name#_0 : MemRef24Strange<OP.Opcode, 0b000, i16imm, OP.Name>;
    }
    def OP.Name#_1 : MemRef24Strange<OP.Opcode, 0b001, i16imm, OP.Name, "(${arg})">;
    def OP.Name#_2 : MemRef24Strange<OP.Opcode, 0b010, i16imm, OP.Name, "((${arg}))">;
    def OP.Name#_3 : MemRef16Strange<OP.Opcode, 0b011, i8imm, OP.Name, "(PC)+${arg}">;
    def OP.Name#_4 : MemRef16Strange<OP.Opcode, 0b100, i8imm, OP.Name, "((PC)+${arg})">;
    def OP.Name#_5_0: MemRef16IndexStrange<OP.Opcode, 0x0, GPR, OP.Name, "(${arg})">;
    def OP.Name#_5_1: MemRef16IndexStrange<OP.Opcode, 0x1, GPR, OP.Name#"_I", "(${arg})">;
    def OP.Name#_5_2: MemRef16IndexStrange<OP.Opcode, 0x2, GPR, OP.Name#"_D", "(${arg})">;
    // 3 is not used
    def OP.Name#_5_4: MemRef16IndexStrange<OP.Opcode, 0x4, GPR, OP.Name, "((${arg}))">;
    def OP.Name#_5_5: MemRef16IndexStrange<OP.Opcode, 0x5, GPR, OP.Name#"_I", "((${arg}))">;
    def OP.Name#_5_6: MemRef16IndexStrange<OP.Opcode, 0x6, GPR, OP.Name#"_D", "((${arg}))">;
    // 7 is not used
    def OP.Name#_5_8: MemRef24IndexStrange<OP.Opcode, 0x8, GPR, OP.Name, "(${r}),$arg">;
    def OP.Name#_5_9: MemRef24IndexStrange<OP.Opcode, 0x9, GPR, OP.Name#"_I", "(${r}),$arg">;
    def OP.Name#_5_A: MemRef24IndexStrange<OP.Opcode, 0xA, GPR, OP.Name#"_D", "(${r}),$arg">;
    // B is not used
    def OP.Name#_5_C: MemRef24IndexStrange<OP.Opcode, 0xC, GPR, OP.Name, "(${r}),${arg}">;
    def OP.Name#_5_D: MemRef24IndexStrange<OP.Opcode, 0xD, GPR, OP.Name#"_I", "((${r})),$arg">;
    def OP.Name#_5_E: MemRef24IndexStrange<OP.Opcode, 0xE, GPR, OP.Name#"_D", "((${r})),$arg">;
}