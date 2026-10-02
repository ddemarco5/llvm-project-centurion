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
// isReturn marks the function exit. isTerminator and isBarrier tell the
// machine verifier that control does not fall out of the block. The
// CPU6retglue pattern in CPU6InstrPatterns.td selects this opcode.
let isReturn = 1, isTerminator = 1, isBarrier = 1 in
def RSR : Control<0x09, "RSR">;     // Return from Subroutine
def RI : Control<0x0A, "RI">;       // Return from Inturrupt
def RIM : Control<0x0B, "RIM">;     // Return from Inturrupt Modified
def SYN : Control<0x0C, "SYN">;     // Enable link to teletype
def PCX : Control<0x0D, "PCX">;     // Move PC to X
def DLY : Control<0x0E, "DLY">;     // Delay
def RSV: Control<0x0F, "RSV">;    // Return from JSYS using stack

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
def BI: Branch<0x1E, "BI">;   // Branch on interrupts enabled
def BCK: Branch<0x1F, "BCK">;   // Branch on AH at interrupt level 1 bit 0 set (probably)
def SVC: Branch<0x66, "SVC">; // System call

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
// The low nibble is the value, not forced to 0. load7 `32 01` is
// clr A, #1 and `32 02` is clr A, #2. f1 `22 32` is clr BL, #2.
// Phire prints that nibble as the count; the encoded nibble is the value.
def CLR : SingleReg16<0x32, "CLR">;      // Clear Register
def CLRB: SingleReg16_B<0x22, "CLRB">;   // Clear Register (Byte mode)
def IVR : SingleReg16<0x33, "IVR">;      // Invert Register
def IVRB: SingleReg16H_B<0x23, "IVRB">;  // Invert Register (Byte mode)
def SRR : SingleReg16<0x34, "SRR">;      // Shift Register Right
def SRRB: SingleReg16_B<0x24, "SRRB">;   // Shift Register Right (Byte mode)
def SLR : SingleReg16<0x35, "SLR">;      // Shift Register Left
def SLRB: SingleReg16_B<0x25, "SLRB">;   // Shift Register Left (Byte mode)
def RRR : SingleReg16<0x36, "RRR">;      // Rotate Register Right
def RRRB: SingleReg16_B<0x26, "RRRB">;   // Rotate Register Right (Byte mode)
def RLR : SingleReg16<0x37, "RLR">;      // Rotate Register Left
def RLRB: SingleReg16_B<0x27, "RLRB">;   // Rotate Register Left (Byte mode)

// Odd high nibble: the operation is on memory. Wiki OpC_30-3F and load7.
// Nibble 1 is direct and the next word is a big-endian address:
// `30 10 8e cd` inc [0x8ecd], #1; `32 10 90 35` clr [0x9035], #0;
// `33 11 cf 1b` not [0xcf1b], #1.
// Any other odd nibble is indexed from that register, and the next word
// is a big-endian displacement: `31 70 00 35` dec [Y+0x0035], #1;
// `32 90 00 10` clr [Z+0x0010], #0; `34 97 83 00` srl [Z+0x8300], #8.
// The low nibble is the same count field as the register form.
// A 2-byte def only matches an even register, so it does not swallow these.
class CountMem32<bits<8> opcode, string opstr>
      : CenturionInst32<(outs), (ins i16imm:$addr, uimm4:$count),
                        opstr, "(${addr}),$count"> {
  bits<16> addr;
  bits<4> count;
  let Inst{31-24} = opcode;
  let Inst{23-20} = 1;
  let Inst{19-16} = count;
  let Inst{15-0} = addr;
}
class CountIdx32<bits<8> opcode, string opstr>
      : CenturionInst32<(outs), (ins GPR:$base, i16imm:$disp, uimm4:$count),
                        opstr, "(${base}),$disp,$count"> {
  bits<4> base;
  bits<16> disp;
  bits<4> count;
  let Inst{31-24} = opcode;
  let Inst{23} = base{3};
  let Inst{22} = base{2};
  let Inst{21} = base{1};
  let Inst{20} = 1;
  let Inst{19-16} = count;
  let Inst{15-0} = disp;
}
def INRmem : CountMem32<0x30, "INR">;
def INRidx : CountIdx32<0x30, "INR">;
def DCRmem : CountMem32<0x31, "DCR">;
def DCRidx : CountIdx32<0x31, "DCR">;
def CLRmem : CountMem32<0x32, "CLR">;
def CLRidx : CountIdx32<0x32, "CLR">;
def IVRmem : CountMem32<0x33, "IVR">;
def IVRidx : CountIdx32<0x33, "IVR">;
def SRRmem : CountMem32<0x34, "SRR">;
def SRRidx : CountIdx32<0x34, "SRR">;

// 0x2E PageTable stays unimplemented. The wiki form is `2E ssssmmnn`
// and load7 uses both 5-byte and 6-byte tails (`2e 1c 78 80 d3`,
// `2e 30 a1 fc a0 fb`). The mode bits change the tail width.

// ------------------
// Opcode byte is 0x2F. Phire's WIPL encodes these as 2F 00/02/04/06.
// Second byte is | r | s | (register nibble, then selector). The wiki
// form text says `2e rs`. 0x2E stays the PageTable TODO above.
// ------------------
class SingleReg16DMA<bits<8> opcode, bits<4> sel, string opstr>
      : SingleArg16DMA<opcode, sel, (outs), (ins GPR: $argnib), opstr, "$argnib"> { }
// SDV's high nibble is the DMA mode constant. Mode 0 is `2f 04`;
// that constant is not a GPR (register A only happens to encode as 0).
class SingleImm16DMA<bits<8> opcode, bits<4> sel, string opstr>
      : SingleArg16DMA<opcode, sel, (outs), (ins uimm4:$argnib), opstr, "$argnib"> { }

def SAD: SingleReg16DMA<0x2F, 0x0, "SAD">;
def RAD: SingleReg16DMA<0x2F, 0x1, "RAD">;
def SCT: SingleReg16DMA<0x2F, 0x2, "SCT">;
def RCT: SingleReg16DMA<0x2F, 0x3, "RCT">;
def SDV: SingleImm16DMA<0x2F, 0x4, "SDV">;
def RDV: SingleReg16DMA<0x2F, 0x5, "RDV">;
def EAB: SingleReg16DMA<0x2F, 0x6, "EAB">;
def DAB: SingleReg16DMA<0x2F, 0x7, "DAB">;
def SMN: SingleReg16DMA<0x2F, 0x8, "SMN">;
def RMN: SingleReg16DMA<0x2F, 0x9, "RMN">;


//-----------  BIGNUM (0x46)  -----------//
// The wiki prefix is `46 llllkkkk ssssmmnn`. It does not specify the
// bytes that follow. The tail below is a layout defined here.
//
// Byte 0 is 0x46.
// Byte 1 is llllkkkk. l is the 4-bit size of operand 1. k is the 4-bit
// size of operand 2.
// Byte 2 is ssssmmnn. s is the 4-bit selector. mm is operand 1's mode.
// nn is operand 2's mode.
//
// The Instructions page names Literal, Direct, Indirect, Relative,
// Relative Indirect, and Indexed. The BIGNUM paragraph calls out
// literal (literal->literal). mm and nn are two bits, so this layout
// assigns only the three named modes whose widths already exist in
// CPU6InstrFormats.td. Indirect, relative, and relative-indirect are
// not given a value. Value 3 is unused.
//   0 literal: 16-bit big-endian immediate, the LDA M=0 width.
//   1 direct:  16-bit big-endian address, the LDA M=1 width.
//   2 indexed: base register in the high nibble of the next byte, low
//              nibble fixed at 0, then an 8-bit displacement. Those are
//              the LDA (r),disp field widths. LDA's m' nibble is not
//              repeated; the mode already lives in mm or nn.
//
// Each tail is two bytes. Operand 1's tail is bytes 3-4. Operand 2's
// tail is bytes 5-6.
// Selectors 0-8: operand 1 is the source and operand 2 is the destination.
// CFB (selector 9) swaps that pair. Operand 1 is the destination and
// operand 2 is the source. Same opcode, different operand order.
//
// A, S, and C are register asm names, so selectors 0-2 are spelled
// BNA, BNS, and BNC.
//
// CTB: the page does not say how the conversion base is supplied.
// This layout uses the base register of an indexed operand. Operand 1's
// base is that base when operand 1 is indexed; otherwise operand 2's
// base is. A form with no indexed operand does not encode a base.
// DRM: the remainder is written through AW and the link flag is set for
// a zero remainder. AW is not an operand.

class BN_LL<bits<4> sel, string name>
      : CenturionInst56<(outs),
          (ins uimm4:$l, uimm4:$k, i16imm:$op1, i16imm:$op2),
          name, "$l,$k,$op1,$op2"> {
  bits<4> l;
  bits<4> k;
  bits<16> op1;
  bits<16> op2;
  let Inst{55-48} = 0x46;
  let Inst{47-44} = l;
  let Inst{43-40} = k;
  let Inst{39-36} = sel;
  let Inst{35-34} = 0;
  let Inst{33-32} = 0;
  let Inst{31-16} = op1;
  let Inst{15-0} = op2;
}

class BN_LD<bits<4> sel, string name>
      : CenturionInst56<(outs),
          (ins uimm4:$l, uimm4:$k, i16imm:$op1, i16imm:$op2),
          name, "$l,$k,$op1,(${op2})"> {
  bits<4> l;
  bits<4> k;
  bits<16> op1;
  bits<16> op2;
  let Inst{55-48} = 0x46;
  let Inst{47-44} = l;
  let Inst{43-40} = k;
  let Inst{39-36} = sel;
  let Inst{35-34} = 0;
  let Inst{33-32} = 1;
  let Inst{31-16} = op1;
  let Inst{15-0} = op2;
}

class BN_LI<bits<4> sel, string name>
      : CenturionInst56<(outs),
          (ins uimm4:$l, uimm4:$k, i16imm:$op1, GPR:$op2r, i8imm:$op2d),
          name, "$l,$k,$op1,(${op2r}),$op2d"> {
  bits<4> l;
  bits<4> k;
  bits<16> op1;
  bits<4> op2r;
  bits<8> op2d;
  let Inst{55-48} = 0x46;
  let Inst{47-44} = l;
  let Inst{43-40} = k;
  let Inst{39-36} = sel;
  let Inst{35-34} = 0;
  let Inst{33-32} = 2;
  let Inst{31-16} = op1;
  let Inst{15-12} = op2r;
  let Inst{11-8} = 0;
  let Inst{7-0} = op2d;
}

class BN_DL<bits<4> sel, string name>
      : CenturionInst56<(outs),
          (ins uimm4:$l, uimm4:$k, i16imm:$op1, i16imm:$op2),
          name, "$l,$k,(${op1}),$op2"> {
  bits<4> l;
  bits<4> k;
  bits<16> op1;
  bits<16> op2;
  let Inst{55-48} = 0x46;
  let Inst{47-44} = l;
  let Inst{43-40} = k;
  let Inst{39-36} = sel;
  let Inst{35-34} = 1;
  let Inst{33-32} = 0;
  let Inst{31-16} = op1;
  let Inst{15-0} = op2;
}

class BN_DD<bits<4> sel, string name>
      : CenturionInst56<(outs),
          (ins uimm4:$l, uimm4:$k, i16imm:$op1, i16imm:$op2),
          name, "$l,$k,(${op1}),(${op2})"> {
  bits<4> l;
  bits<4> k;
  bits<16> op1;
  bits<16> op2;
  let Inst{55-48} = 0x46;
  let Inst{47-44} = l;
  let Inst{43-40} = k;
  let Inst{39-36} = sel;
  let Inst{35-34} = 1;
  let Inst{33-32} = 1;
  let Inst{31-16} = op1;
  let Inst{15-0} = op2;
}

class BN_DI<bits<4> sel, string name>
      : CenturionInst56<(outs),
          (ins uimm4:$l, uimm4:$k, i16imm:$op1, GPR:$op2r, i8imm:$op2d),
          name, "$l,$k,(${op1}),(${op2r}),$op2d"> {
  bits<4> l;
  bits<4> k;
  bits<16> op1;
  bits<4> op2r;
  bits<8> op2d;
  let Inst{55-48} = 0x46;
  let Inst{47-44} = l;
  let Inst{43-40} = k;
  let Inst{39-36} = sel;
  let Inst{35-34} = 1;
  let Inst{33-32} = 2;
  let Inst{31-16} = op1;
  let Inst{15-12} = op2r;
  let Inst{11-8} = 0;
  let Inst{7-0} = op2d;
}

class BN_IL<bits<4> sel, string name>
      : CenturionInst56<(outs),
          (ins uimm4:$l, uimm4:$k, GPR:$op1r, i8imm:$op1d, i16imm:$op2),
          name, "$l,$k,(${op1r}),$op1d,$op2"> {
  bits<4> l;
  bits<4> k;
  bits<4> op1r;
  bits<8> op1d;
  bits<16> op2;
  let Inst{55-48} = 0x46;
  let Inst{47-44} = l;
  let Inst{43-40} = k;
  let Inst{39-36} = sel;
  let Inst{35-34} = 2;
  let Inst{33-32} = 0;
  let Inst{31-28} = op1r;
  let Inst{27-24} = 0;
  let Inst{23-16} = op1d;
  let Inst{15-0} = op2;
}

class BN_ID<bits<4> sel, string name>
      : CenturionInst56<(outs),
          (ins uimm4:$l, uimm4:$k, GPR:$op1r, i8imm:$op1d, i16imm:$op2),
          name, "$l,$k,(${op1r}),$op1d,(${op2})"> {
  bits<4> l;
  bits<4> k;
  bits<4> op1r;
  bits<8> op1d;
  bits<16> op2;
  let Inst{55-48} = 0x46;
  let Inst{47-44} = l;
  let Inst{43-40} = k;
  let Inst{39-36} = sel;
  let Inst{35-34} = 2;
  let Inst{33-32} = 1;
  let Inst{31-28} = op1r;
  let Inst{27-24} = 0;
  let Inst{23-16} = op1d;
  let Inst{15-0} = op2;
}

class BN_II<bits<4> sel, string name>
      : CenturionInst56<(outs),
          (ins uimm4:$l, uimm4:$k, GPR:$op1r, i8imm:$op1d, GPR:$op2r, i8imm:$op2d),
          name, "$l,$k,(${op1r}),$op1d,(${op2r}),$op2d"> {
  bits<4> l;
  bits<4> k;
  bits<4> op1r;
  bits<8> op1d;
  bits<4> op2r;
  bits<8> op2d;
  let Inst{55-48} = 0x46;
  let Inst{47-44} = l;
  let Inst{43-40} = k;
  let Inst{39-36} = sel;
  let Inst{35-34} = 2;
  let Inst{33-32} = 2;
  let Inst{31-28} = op1r;
  let Inst{27-24} = 0;
  let Inst{23-16} = op1d;
  let Inst{15-12} = op2r;
  let Inst{11-8} = 0;
  let Inst{7-0} = op2d;
}

class BNSel<string name, bits<4> sel> {
  string Name = name;
  bits<4> Sel = sel;
}

foreach OP = [
    BNSel<"BNA", 0>,
    BNSel<"BNS", 1>,
    BNSel<"BNC", 2>,
    BNSel<"ZAD", 3>,
    BNSel<"ZSU", 4>,
    BNSel<"M", 5>,
    BNSel<"D", 6>,
    BNSel<"DRM", 7>,
    BNSel<"CTB", 8>,
    BNSel<"CFB", 9>
] in {
  def OP.Name#_LL : BN_LL<OP.Sel, OP.Name>;
  def OP.Name#_LD : BN_LD<OP.Sel, OP.Name>;
  def OP.Name#_LI : BN_LI<OP.Sel, OP.Name>;
  def OP.Name#_DL : BN_DL<OP.Sel, OP.Name>;
  def OP.Name#_DD : BN_DD<OP.Sel, OP.Name>;
  def OP.Name#_DI : BN_DI<OP.Sel, OP.Name>;
  def OP.Name#_IL : BN_IL<OP.Sel, OP.Name>;
  def OP.Name#_ID : BN_ID<OP.Sel, OP.Name>;
  def OP.Name#_II : BN_II<OP.Sel, OP.Name>;
}


// 0x47 mode 0xC and 0x67 mode 0xA. These are the WIPL sites and the
// load7 lines with the same shape. Other 47/67 lengths stay unimplemented:
// load7 also has 4-, 5-, and 7-byte 0x47 and 4-, 5-, and 6-byte 0x67.
//
// MVF is selector 4, FIL is selector 9. Both use mode nibble 0xC:
// count-1, a literal byte, then a big-endian direct address.
// WIPL `47 4c 00 ff 02 65` is MVF (1)=0xFF, /0x0265.
// WIPL `47 9c 09 a0 03 65` is FIL (10)=0xA0, /0x0365.
// MVFR is selector 4, mode nibble 0xA, then source and destination
// registers. The length is AL and is not in the instruction.
// WIPL `67 4a 86` is MVFR -Z,-Y. load7 `67 4a 64` is memcpy AL, [Y], [X].
class BlockLit48<bits<4> sel, string name>
      : CenturionInst48<(outs),
          (ins uimm8:$count, i8imm:$byte, i16imm:$addr),
          name, "$count,$byte,(${addr})"> {
  bits<8> count;
  bits<8> byte;
  bits<16> addr;
  let Inst{47-40} = 0x47;
  let Inst{39-36} = sel;
  let Inst{35-32} = 0xC;
  let Inst{31-24} = count;
  let Inst{23-16} = byte;
  let Inst{15-0} = addr;
}
def MVF : BlockLit48<4, "MVF">;
def FIL : BlockLit48<9, "FIL">;

class MVFR24
      : CenturionInst24<(outs), (ins GPR:$src, GPR:$dst),
                        "MVFR", "$src,$dst"> {
  bits<4> src;
  bits<4> dst;
  let Inst{23-16} = 0x67;
  let Inst{15-12} = 4;
  let Inst{11-8} = 0xA;
  let Inst{7-4} = src;
  let Inst{3-0} = dst;
}
def MVFR : MVFR24;

// D6. The wiki (OpC_D0-DF) and webCenREE rrsrfetchw agree: the low nibble
// is the value being stored, and the high nibble's low bit picks the mode.
// High even, low odd: store low to a direct address. `d6 89 92 b7` is
// st Z, [0x92b7]. Both odd: store low to (high + big-endian imm16), the
// inverse of the 5x XFR indexed load. `d6 35 00 05` stores X to [B+5]:
// webCenREE writes get_rw(low) to imm + get_rw(high), and its disassembler
// prints the base first. load7's text for that byte reads the nibbles the
// other way round.
// Both-even and left-odd/right-even are the webCenREE rrsrfetchw modes
// added below.
class STRMem32
      : CenturionInst32<(outs), (ins GPR:$src, i16imm:$addr),
                        "STR", "$src,(${addr})"> {
  bits<4> src;
  bits<16> addr;
  let Inst{31-24} = 0xD6;
  let Inst{23} = src{3};
  let Inst{22} = src{2};
  let Inst{21} = src{1};
  let Inst{20} = 0;
  let Inst{19} = src{3};
  let Inst{18} = src{2};
  let Inst{17} = src{1};
  let Inst{16} = 1;
  let Inst{15-0} = addr;
}
def STRmem : STRMem32;
// storeRegToStackSlot emits this with S as the base and a frame index as
// the displacement.
let hasSideEffects = 0, mayLoad = 0, mayStore = 1 in
class STRIdx32
      : CenturionInst32<(outs), (ins GPR:$src, GPR:$base, i16imm:$disp),
                        "STR", "$src,(${base}),$disp"> {
  bits<4> src;
  bits<4> base;
  bits<16> disp;
  let Inst{31-24} = 0xD6;
  let Inst{23} = base{3};
  let Inst{22} = base{2};
  let Inst{21} = base{1};
  let Inst{20} = 1;
  let Inst{19} = src{3};
  let Inst{18} = src{2};
  let Inst{17} = src{1};
  let Inst{16} = 1;
  let Inst{15-0} = disp;
}
def STRidx : STRIdx32;

// webCenREE (Meisaka) operand widths.
// ex_decode / decode_exmode: mode 0 is a big-endian word,
// mode 1 is an index byte plus a displacement, mode 2 is one
// register byte, mode 3 is an inline literal. The index byte's
// low bit selects an 8-bit or 16-bit displacement. Its low
// nibble is 0 here; webCenREE also allows a second even register there.
// A register byte that is only a source keeps the register in
// the high nibble. A register byte that is only a destination
// keeps it in the low nibble. Both modes 2 share one byte.
class OpSel<string name, bits<4> sel> {
  string Name = name;
  bits<4> Sel = sel;
}

class Mem47RR<bits<4> sel, string name>
      : CenturionInst32<(outs), (ins uimm8:$count, GPR:$src, GPR:$dst),
        name, "$count,$src,$dst"> {
  bits<8> count;
  bits<4> src;
  bits<4> dst;
  let Inst{31-24} = 71;
  let Inst{23-20} = sel;
  let Inst{19-16} = 10;
  let Inst{15-8} = count;
  let Inst{7-4} = src;
  let Inst{3-0} = dst;
}

class Mem47RD<bits<4> sel, string name>
      : CenturionInst48<(outs), (ins uimm8:$count, GPR:$src, i16imm:$addr),
        name, "$count,$src,(${addr})"> {
  bits<8> count;
  bits<4> src;
  bits<16> addr;
  let Inst{47-40} = 71;
  let Inst{39-36} = sel;
  let Inst{35-32} = 8;
  let Inst{31-24} = count;
  let Inst{23-20} = src;
  let Inst{19-16} = 0;
  let Inst{15-0} = addr;
}

class Mem47DR<bits<4> sel, string name>
      : CenturionInst48<(outs), (ins uimm8:$count, i16imm:$addr, GPR:$dst),
        name, "$count,(${addr}),$dst"> {
  bits<8> count;
  bits<16> addr;
  bits<4> dst;
  let Inst{47-40} = 71;
  let Inst{39-36} = sel;
  let Inst{35-32} = 2;
  let Inst{31-24} = count;
  let Inst{23-8} = addr;
  let Inst{7-4} = 0;
  let Inst{3-0} = dst;
}

class Mem47DD<bits<4> sel, string name>
      : CenturionInst56<(outs), (ins uimm8:$count, i16imm:$addr, i16imm:$addr2),
        name, "$count,(${addr}),(${addr2})"> {
  bits<8> count;
  bits<16> addr;
  bits<16> addr2;
  let Inst{55-48} = 71;
  let Inst{47-44} = sel;
  let Inst{43-40} = 0;
  let Inst{39-32} = count;
  let Inst{31-16} = addr;
  let Inst{15-0} = addr2;
}

class Mem47I8D<bits<4> sel, string name>
      : CenturionInst56<(outs), (ins uimm8:$count, GPR:$base, simm8:$disp, i16imm:$addr),
        name, "$count,(${base}),$disp,(${addr})"> {
  bits<8> count;
  bits<4> base;
  bits<8> disp;
  bits<16> addr;
  let Inst{55-48} = 71;
  let Inst{47-44} = sel;
  let Inst{43-40} = 4;
  let Inst{39-32} = count;
  let Inst{31} = base{3};
  let Inst{30} = base{2};
  let Inst{29} = base{1};
  let Inst{28} = 0;
  let Inst{27-24} = 0;
  let Inst{23-16} = disp;
  let Inst{15-0} = addr;
}

class Mem47DI8<bits<4> sel, string name>
      : CenturionInst56<(outs), (ins uimm8:$count, i16imm:$addr, GPR:$base, simm8:$disp),
        name, "$count,(${addr}),(${base}),$disp"> {
  bits<8> count;
  bits<16> addr;
  bits<4> base;
  bits<8> disp;
  let Inst{55-48} = 71;
  let Inst{47-44} = sel;
  let Inst{43-40} = 1;
  let Inst{39-32} = count;
  let Inst{31-16} = addr;
  let Inst{15} = base{3};
  let Inst{14} = base{2};
  let Inst{13} = base{1};
  let Inst{12} = 0;
  let Inst{11-8} = 0;
  let Inst{7-0} = disp;
}

class Mem47I8I8<bits<4> sel, string name>
      : CenturionInst56<(outs), (ins uimm8:$count, GPR:$base, simm8:$disp, GPR:$base2, simm8:$disp2),
        name, "$count,(${base}),$disp,(${base2}),$disp2"> {
  bits<8> count;
  bits<4> base;
  bits<8> disp;
  bits<4> base2;
  bits<8> disp2;
  let Inst{55-48} = 71;
  let Inst{47-44} = sel;
  let Inst{43-40} = 5;
  let Inst{39-32} = count;
  let Inst{31} = base{3};
  let Inst{30} = base{2};
  let Inst{29} = base{1};
  let Inst{28} = 0;
  let Inst{27-24} = 0;
  let Inst{23-16} = disp;
  let Inst{15} = base2{3};
  let Inst{14} = base2{2};
  let Inst{13} = base2{1};
  let Inst{12} = 0;
  let Inst{11-8} = 0;
  let Inst{7-0} = disp2;
}

class Mem47I8R<bits<4> sel, string name>
      : CenturionInst48<(outs), (ins uimm8:$count, GPR:$base, simm8:$disp, GPR:$dst),
        name, "$count,(${base}),$disp,$dst"> {
  bits<8> count;
  bits<4> base;
  bits<8> disp;
  bits<4> dst;
  let Inst{47-40} = 71;
  let Inst{39-36} = sel;
  let Inst{35-32} = 6;
  let Inst{31-24} = count;
  let Inst{23} = base{3};
  let Inst{22} = base{2};
  let Inst{21} = base{1};
  let Inst{20} = 0;
  let Inst{19-16} = 0;
  let Inst{15-8} = disp;
  let Inst{7-4} = 0;
  let Inst{3-0} = dst;
}

class Mem47RI8<bits<4> sel, string name>
      : CenturionInst48<(outs), (ins uimm8:$count, GPR:$src, GPR:$base, simm8:$disp),
        name, "$count,$src,(${base}),$disp"> {
  bits<8> count;
  bits<4> src;
  bits<4> base;
  bits<8> disp;
  let Inst{47-40} = 71;
  let Inst{39-36} = sel;
  let Inst{35-32} = 9;
  let Inst{31-24} = count;
  let Inst{23-20} = src;
  let Inst{19-16} = 0;
  let Inst{15} = base{3};
  let Inst{14} = base{2};
  let Inst{13} = base{1};
  let Inst{12} = 0;
  let Inst{11-8} = 0;
  let Inst{7-0} = disp;
}

class Mem47I16R<bits<4> sel, string name>
      : CenturionInst56<(outs), (ins uimm8:$count, GPR:$base, simm16:$wdisp, GPR:$dst),
        name, "$count,(${base}),(${wdisp}),$dst"> {
  bits<8> count;
  bits<4> base;
  bits<16> wdisp;
  bits<4> dst;
  let Inst{55-48} = 71;
  let Inst{47-44} = sel;
  let Inst{43-40} = 6;
  let Inst{39-32} = count;
  let Inst{31} = base{3};
  let Inst{30} = base{2};
  let Inst{29} = base{1};
  let Inst{28} = 1;
  let Inst{27-24} = 0;
  let Inst{23-8} = wdisp;
  let Inst{7-4} = 0;
  let Inst{3-0} = dst;
}

class Mem47RI16<bits<4> sel, string name>
      : CenturionInst56<(outs), (ins uimm8:$count, GPR:$src, GPR:$base, simm16:$wdisp),
        name, "$count,$src,(${base}),(${wdisp})"> {
  bits<8> count;
  bits<4> src;
  bits<4> base;
  bits<16> wdisp;
  let Inst{55-48} = 71;
  let Inst{47-44} = sel;
  let Inst{43-40} = 9;
  let Inst{39-32} = count;
  let Inst{31-28} = src;
  let Inst{27-24} = 0;
  let Inst{23} = base{3};
  let Inst{22} = base{2};
  let Inst{21} = base{1};
  let Inst{20} = 1;
  let Inst{19-16} = 0;
  let Inst{15-0} = wdisp;
}

class Fil47R<bits<4> sel, string name>
      : CenturionInst40<(outs), (ins uimm8:$count, i8imm:$lit, GPR:$dst),
        name, "$count,$lit,$dst"> {
  bits<8> count;
  bits<8> lit;
  bits<4> dst;
  let Inst{39-32} = 71;
  let Inst{31-28} = sel;
  let Inst{27-24} = 14;
  let Inst{23-16} = count;
  let Inst{15-8} = lit;
  let Inst{7-4} = 0;
  let Inst{3-0} = dst;
}

class Fil47I8<bits<4> sel, string name>
      : CenturionInst48<(outs), (ins uimm8:$count, i8imm:$lit, GPR:$base, simm8:$disp),
        name, "$count,$lit,(${base}),$disp"> {
  bits<8> count;
  bits<8> lit;
  bits<4> base;
  bits<8> disp;
  let Inst{47-40} = 71;
  let Inst{39-36} = sel;
  let Inst{35-32} = 13;
  let Inst{31-24} = count;
  let Inst{23-16} = lit;
  let Inst{15} = base{3};
  let Inst{14} = base{2};
  let Inst{13} = base{1};
  let Inst{12} = 0;
  let Inst{11-8} = 0;
  let Inst{7-0} = disp;
}

class Fil47I16<bits<4> sel, string name>
      : CenturionInst56<(outs), (ins uimm8:$count, i8imm:$lit, GPR:$base, simm16:$wdisp),
        name, "$count,$lit,(${base}),(${wdisp})"> {
  bits<8> count;
  bits<8> lit;
  bits<4> base;
  bits<16> wdisp;
  let Inst{55-48} = 71;
  let Inst{47-44} = sel;
  let Inst{43-40} = 13;
  let Inst{39-32} = count;
  let Inst{31-24} = lit;
  let Inst{23} = base{3};
  let Inst{22} = base{2};
  let Inst{21} = base{1};
  let Inst{20} = 1;
  let Inst{19-16} = 0;
  let Inst{15-0} = wdisp;
}

class Mem67RR<bits<4> sel, string name>
      : CenturionInst24<(outs), (ins GPR:$src, GPR:$dst),
        name, "$src,$dst"> {
  bits<4> src;
  bits<4> dst;
  let Inst{23-16} = 103;
  let Inst{15-12} = sel;
  let Inst{11-8} = 10;
  let Inst{7-4} = src;
  let Inst{3-0} = dst;
}

class Mem67RD<bits<4> sel, string name>
      : CenturionInst40<(outs), (ins GPR:$src, i16imm:$addr),
        name, "$src,(${addr})"> {
  bits<4> src;
  bits<16> addr;
  let Inst{39-32} = 103;
  let Inst{31-28} = sel;
  let Inst{27-24} = 8;
  let Inst{23-20} = src;
  let Inst{19-16} = 0;
  let Inst{15-0} = addr;
}

class Mem67DR<bits<4> sel, string name>
      : CenturionInst40<(outs), (ins i16imm:$addr, GPR:$dst),
        name, "(${addr}),$dst"> {
  bits<16> addr;
  bits<4> dst;
  let Inst{39-32} = 103;
  let Inst{31-28} = sel;
  let Inst{27-24} = 2;
  let Inst{23-8} = addr;
  let Inst{7-4} = 0;
  let Inst{3-0} = dst;
}

class Mem67DD<bits<4> sel, string name>
      : CenturionInst48<(outs), (ins i16imm:$addr, i16imm:$addr2),
        name, "(${addr}),(${addr2})"> {
  bits<16> addr;
  bits<16> addr2;
  let Inst{47-40} = 103;
  let Inst{39-36} = sel;
  let Inst{35-32} = 0;
  let Inst{31-16} = addr;
  let Inst{15-0} = addr2;
}

class Mem67I8R<bits<4> sel, string name>
      : CenturionInst40<(outs), (ins GPR:$base, simm8:$disp, GPR:$dst),
        name, "(${base}),$disp,$dst"> {
  bits<4> base;
  bits<8> disp;
  bits<4> dst;
  let Inst{39-32} = 103;
  let Inst{31-28} = sel;
  let Inst{27-24} = 6;
  let Inst{23} = base{3};
  let Inst{22} = base{2};
  let Inst{21} = base{1};
  let Inst{20} = 0;
  let Inst{19-16} = 0;
  let Inst{15-8} = disp;
  let Inst{7-4} = 0;
  let Inst{3-0} = dst;
}

class Mem67RI8<bits<4> sel, string name>
      : CenturionInst40<(outs), (ins GPR:$src, GPR:$base, simm8:$disp),
        name, "$src,(${base}),$disp"> {
  bits<4> src;
  bits<4> base;
  bits<8> disp;
  let Inst{39-32} = 103;
  let Inst{31-28} = sel;
  let Inst{27-24} = 9;
  let Inst{23-20} = src;
  let Inst{19-16} = 0;
  let Inst{15} = base{3};
  let Inst{14} = base{2};
  let Inst{13} = base{1};
  let Inst{12} = 0;
  let Inst{11-8} = 0;
  let Inst{7-0} = disp;
}

class Mem67I8D<bits<4> sel, string name>
      : CenturionInst48<(outs), (ins GPR:$base, simm8:$disp, i16imm:$addr),
        name, "(${base}),$disp,(${addr})"> {
  bits<4> base;
  bits<8> disp;
  bits<16> addr;
  let Inst{47-40} = 103;
  let Inst{39-36} = sel;
  let Inst{35-32} = 4;
  let Inst{31} = base{3};
  let Inst{30} = base{2};
  let Inst{29} = base{1};
  let Inst{28} = 0;
  let Inst{27-24} = 0;
  let Inst{23-16} = disp;
  let Inst{15-0} = addr;
}

class Mem67DI8<bits<4> sel, string name>
      : CenturionInst48<(outs), (ins i16imm:$addr, GPR:$base, simm8:$disp),
        name, "(${addr}),(${base}),$disp"> {
  bits<16> addr;
  bits<4> base;
  bits<8> disp;
  let Inst{47-40} = 103;
  let Inst{39-36} = sel;
  let Inst{35-32} = 1;
  let Inst{31-16} = addr;
  let Inst{15} = base{3};
  let Inst{14} = base{2};
  let Inst{13} = base{1};
  let Inst{12} = 0;
  let Inst{11-8} = 0;
  let Inst{7-0} = disp;
}

class Mem67I8I8<bits<4> sel, string name>
      : CenturionInst48<(outs), (ins GPR:$base, simm8:$disp, GPR:$base2, simm8:$disp2),
        name, "(${base}),$disp,(${base2}),$disp2"> {
  bits<4> base;
  bits<8> disp;
  bits<4> base2;
  bits<8> disp2;
  let Inst{47-40} = 103;
  let Inst{39-36} = sel;
  let Inst{35-32} = 5;
  let Inst{31} = base{3};
  let Inst{30} = base{2};
  let Inst{29} = base{1};
  let Inst{28} = 0;
  let Inst{27-24} = 0;
  let Inst{23-16} = disp;
  let Inst{15} = base2{3};
  let Inst{14} = base2{2};
  let Inst{13} = base2{1};
  let Inst{12} = 0;
  let Inst{11-8} = 0;
  let Inst{7-0} = disp2;
}

class Mem67I16R<bits<4> sel, string name>
      : CenturionInst48<(outs), (ins GPR:$base, simm16:$wdisp, GPR:$dst),
        name, "(${base}),(${wdisp}),$dst"> {
  bits<4> base;
  bits<16> wdisp;
  bits<4> dst;
  let Inst{47-40} = 103;
  let Inst{39-36} = sel;
  let Inst{35-32} = 6;
  let Inst{31} = base{3};
  let Inst{30} = base{2};
  let Inst{29} = base{1};
  let Inst{28} = 1;
  let Inst{27-24} = 0;
  let Inst{23-8} = wdisp;
  let Inst{7-4} = 0;
  let Inst{3-0} = dst;
}

class Mem67RI16<bits<4> sel, string name>
      : CenturionInst48<(outs), (ins GPR:$src, GPR:$base, simm16:$wdisp),
        name, "$src,(${base}),(${wdisp})"> {
  bits<4> src;
  bits<4> base;
  bits<16> wdisp;
  let Inst{47-40} = 103;
  let Inst{39-36} = sel;
  let Inst{35-32} = 9;
  let Inst{31-28} = src;
  let Inst{27-24} = 0;
  let Inst{23} = base{3};
  let Inst{22} = base{2};
  let Inst{21} = base{1};
  let Inst{20} = 1;
  let Inst{19-16} = 0;
  let Inst{15-0} = wdisp;
}

class Mem67I16D<bits<4> sel, string name>
      : CenturionInst56<(outs), (ins GPR:$base, simm16:$wdisp, i16imm:$addr),
        name, "(${base}),(${wdisp}),(${addr})"> {
  bits<4> base;
  bits<16> wdisp;
  bits<16> addr;
  let Inst{55-48} = 103;
  let Inst{47-44} = sel;
  let Inst{43-40} = 4;
  let Inst{39} = base{3};
  let Inst{38} = base{2};
  let Inst{37} = base{1};
  let Inst{36} = 1;
  let Inst{35-32} = 0;
  let Inst{31-16} = wdisp;
  let Inst{15-0} = addr;
}

class Mem67DI16<bits<4> sel, string name>
      : CenturionInst56<(outs), (ins i16imm:$addr, GPR:$base, simm16:$wdisp),
        name, "(${addr}),(${base}),(${wdisp})"> {
  bits<16> addr;
  bits<4> base;
  bits<16> wdisp;
  let Inst{55-48} = 103;
  let Inst{47-44} = sel;
  let Inst{43-40} = 1;
  let Inst{39-24} = addr;
  let Inst{23} = base{3};
  let Inst{22} = base{2};
  let Inst{21} = base{1};
  let Inst{20} = 1;
  let Inst{19-16} = 0;
  let Inst{15-0} = wdisp;
}

class Mem67I8I16<bits<4> sel, string name>
      : CenturionInst56<(outs), (ins GPR:$base, simm8:$disp, GPR:$base2, simm16:$wdisp2),
        name, "(${base}),$disp,(${base2}),(${wdisp2})"> {
  bits<4> base;
  bits<8> disp;
  bits<4> base2;
  bits<16> wdisp2;
  let Inst{55-48} = 103;
  let Inst{47-44} = sel;
  let Inst{43-40} = 5;
  let Inst{39} = base{3};
  let Inst{38} = base{2};
  let Inst{37} = base{1};
  let Inst{36} = 0;
  let Inst{35-32} = 0;
  let Inst{31-24} = disp;
  let Inst{23} = base2{3};
  let Inst{22} = base2{2};
  let Inst{21} = base2{1};
  let Inst{20} = 1;
  let Inst{19-16} = 0;
  let Inst{15-0} = wdisp2;
}

class Mem67I16I8<bits<4> sel, string name>
      : CenturionInst56<(outs), (ins GPR:$base, simm16:$wdisp, GPR:$base2, simm8:$disp2),
        name, "(${base}),(${wdisp}),(${base2}),$disp2"> {
  bits<4> base;
  bits<16> wdisp;
  bits<4> base2;
  bits<8> disp2;
  let Inst{55-48} = 103;
  let Inst{47-44} = sel;
  let Inst{43-40} = 5;
  let Inst{39} = base{3};
  let Inst{38} = base{2};
  let Inst{37} = base{1};
  let Inst{36} = 1;
  let Inst{35-32} = 0;
  let Inst{31-16} = wdisp;
  let Inst{15} = base2{3};
  let Inst{14} = base2{2};
  let Inst{13} = base2{1};
  let Inst{12} = 0;
  let Inst{11-8} = 0;
  let Inst{7-0} = disp2;
}

class Fil67R<bits<4> sel, string name>
      : CenturionInst32<(outs), (ins i8imm:$lit, GPR:$dst),
        name, "$lit,$dst"> {
  bits<8> lit;
  bits<4> dst;
  let Inst{31-24} = 103;
  let Inst{23-20} = sel;
  let Inst{19-16} = 14;
  let Inst{15-8} = lit;
  let Inst{7-4} = 0;
  let Inst{3-0} = dst;
}

class Fil67D<bits<4> sel, string name>
      : CenturionInst40<(outs), (ins i8imm:$lit, i16imm:$addr),
        name, "$lit,(${addr})"> {
  bits<8> lit;
  bits<16> addr;
  let Inst{39-32} = 103;
  let Inst{31-28} = sel;
  let Inst{27-24} = 12;
  let Inst{23-16} = lit;
  let Inst{15-0} = addr;
}

class Fil67I8<bits<4> sel, string name>
      : CenturionInst40<(outs), (ins i8imm:$lit, GPR:$base, simm8:$disp),
        name, "$lit,(${base}),$disp"> {
  bits<8> lit;
  bits<4> base;
  bits<8> disp;
  let Inst{39-32} = 103;
  let Inst{31-28} = sel;
  let Inst{27-24} = 13;
  let Inst{23-16} = lit;
  let Inst{15} = base{3};
  let Inst{14} = base{2};
  let Inst{13} = base{1};
  let Inst{12} = 0;
  let Inst{11-8} = 0;
  let Inst{7-0} = disp;
}

class Fil67I16<bits<4> sel, string name>
      : CenturionInst48<(outs), (ins i8imm:$lit, GPR:$base, simm16:$wdisp),
        name, "$lit,(${base}),(${wdisp})"> {
  bits<8> lit;
  bits<4> base;
  bits<16> wdisp;
  let Inst{47-40} = 103;
  let Inst{39-36} = sel;
  let Inst{35-32} = 13;
  let Inst{31-24} = lit;
  let Inst{23} = base{3};
  let Inst{22} = base{2};
  let Inst{21} = base{1};
  let Inst{20} = 1;
  let Inst{19-16} = 0;
  let Inst{15-0} = wdisp;
}

class PageM3D<bits<4> sel, string name>
      : CenturionInst40<(outs), (ins uimm8:$imm, i16imm:$addr),
        name, "$imm,(${addr})"> {
  bits<8> imm;
  bits<16> addr;
  let Inst{39-32} = 46;
  let Inst{31-28} = sel;
  let Inst{27-24} = 12;
  let Inst{23-16} = imm;
  let Inst{15-0} = addr;
}

class PageM3R<bits<4> sel, string name>
      : CenturionInst32<(outs), (ins uimm8:$imm, GPR:$dst),
        name, "$imm,$dst"> {
  bits<8> imm;
  bits<4> dst;
  let Inst{31-24} = 46;
  let Inst{23-20} = sel;
  let Inst{19-16} = 14;
  let Inst{15-8} = imm;
  let Inst{7-4} = 0;
  let Inst{3-0} = dst;
}

class PageM3I8<bits<4> sel, string name>
      : CenturionInst40<(outs), (ins uimm8:$imm, GPR:$base, simm8:$disp),
        name, "$imm,(${base}),$disp"> {
  bits<8> imm;
  bits<4> base;
  bits<8> disp;
  let Inst{39-32} = 46;
  let Inst{31-28} = sel;
  let Inst{27-24} = 13;
  let Inst{23-16} = imm;
  let Inst{15} = base{3};
  let Inst{14} = base{2};
  let Inst{13} = base{1};
  let Inst{12} = 0;
  let Inst{11-8} = 0;
  let Inst{7-0} = disp;
}

class PageM3I16<bits<4> sel, string name>
      : CenturionInst48<(outs), (ins uimm8:$imm, GPR:$base, simm16:$wdisp),
        name, "$imm,(${base}),(${wdisp})"> {
  bits<8> imm;
  bits<4> base;
  bits<16> wdisp;
  let Inst{47-40} = 46;
  let Inst{39-36} = sel;
  let Inst{35-32} = 13;
  let Inst{31-24} = imm;
  let Inst{23} = base{3};
  let Inst{22} = base{2};
  let Inst{21} = base{1};
  let Inst{20} = 1;
  let Inst{19-16} = 0;
  let Inst{15-0} = wdisp;
}

class PageDD<bits<4> sel, string name>
      : CenturionInst48<(outs), (ins i16imm:$addr, i16imm:$addr2),
        name, "(${addr}),(${addr2})"> {
  bits<16> addr;
  bits<16> addr2;
  let Inst{47-40} = 46;
  let Inst{39-36} = sel;
  let Inst{35-32} = 0;
  let Inst{31-16} = addr;
  let Inst{15-0} = addr2;
}

class PageDR<bits<4> sel, string name>
      : CenturionInst40<(outs), (ins i16imm:$addr, GPR:$dst),
        name, "(${addr}),$dst"> {
  bits<16> addr;
  bits<4> dst;
  let Inst{39-32} = 46;
  let Inst{31-28} = sel;
  let Inst{27-24} = 2;
  let Inst{23-8} = addr;
  let Inst{7-4} = 0;
  let Inst{3-0} = dst;
}

class PageDI8<bits<4> sel, string name>
      : CenturionInst48<(outs), (ins i16imm:$addr, GPR:$base, simm8:$disp),
        name, "(${addr}),(${base}),$disp"> {
  bits<16> addr;
  bits<4> base;
  bits<8> disp;
  let Inst{47-40} = 46;
  let Inst{39-36} = sel;
  let Inst{35-32} = 1;
  let Inst{31-16} = addr;
  let Inst{15} = base{3};
  let Inst{14} = base{2};
  let Inst{13} = base{1};
  let Inst{12} = 0;
  let Inst{11-8} = 0;
  let Inst{7-0} = disp;
}

class PageDI16<bits<4> sel, string name>
      : CenturionInst56<(outs), (ins i16imm:$addr, GPR:$base, simm16:$wdisp),
        name, "(${addr}),(${base}),(${wdisp})"> {
  bits<16> addr;
  bits<4> base;
  bits<16> wdisp;
  let Inst{55-48} = 46;
  let Inst{47-44} = sel;
  let Inst{43-40} = 1;
  let Inst{39-24} = addr;
  let Inst{23} = base{3};
  let Inst{22} = base{2};
  let Inst{21} = base{1};
  let Inst{20} = 1;
  let Inst{19-16} = 0;
  let Inst{15-0} = wdisp;
}

class PageRD<bits<4> sel, string name>
      : CenturionInst40<(outs), (ins GPR:$src, i16imm:$addr),
        name, "$src,(${addr})"> {
  bits<4> src;
  bits<16> addr;
  let Inst{39-32} = 46;
  let Inst{31-28} = sel;
  let Inst{27-24} = 8;
  let Inst{23-20} = src;
  let Inst{19-16} = 0;
  let Inst{15-0} = addr;
}

class PageRR<bits<4> sel, string name>
      : CenturionInst24<(outs), (ins GPR:$src, GPR:$dst),
        name, "$src,$dst"> {
  bits<4> src;
  bits<4> dst;
  let Inst{23-16} = 46;
  let Inst{15-12} = sel;
  let Inst{11-8} = 10;
  let Inst{7-4} = src;
  let Inst{3-0} = dst;
}

class PageRI8<bits<4> sel, string name>
      : CenturionInst40<(outs), (ins GPR:$src, GPR:$base, simm8:$disp),
        name, "$src,(${base}),$disp"> {
  bits<4> src;
  bits<4> base;
  bits<8> disp;
  let Inst{39-32} = 46;
  let Inst{31-28} = sel;
  let Inst{27-24} = 9;
  let Inst{23-20} = src;
  let Inst{19-16} = 0;
  let Inst{15} = base{3};
  let Inst{14} = base{2};
  let Inst{13} = base{1};
  let Inst{12} = 0;
  let Inst{11-8} = 0;
  let Inst{7-0} = disp;
}

class PageRI16<bits<4> sel, string name>
      : CenturionInst48<(outs), (ins GPR:$src, GPR:$base, simm16:$wdisp),
        name, "$src,(${base}),(${wdisp})"> {
  bits<4> src;
  bits<4> base;
  bits<16> wdisp;
  let Inst{47-40} = 46;
  let Inst{39-36} = sel;
  let Inst{35-32} = 9;
  let Inst{31-28} = src;
  let Inst{27-24} = 0;
  let Inst{23} = base{3};
  let Inst{22} = base{2};
  let Inst{21} = base{1};
  let Inst{20} = 1;
  let Inst{19-16} = 0;
  let Inst{15-0} = wdisp;
}

class PageI8D<bits<4> sel, string name>
      : CenturionInst48<(outs), (ins GPR:$base, simm8:$disp, i16imm:$addr),
        name, "(${base}),$disp,(${addr})"> {
  bits<4> base;
  bits<8> disp;
  bits<16> addr;
  let Inst{47-40} = 46;
  let Inst{39-36} = sel;
  let Inst{35-32} = 4;
  let Inst{31} = base{3};
  let Inst{30} = base{2};
  let Inst{29} = base{1};
  let Inst{28} = 0;
  let Inst{27-24} = 0;
  let Inst{23-16} = disp;
  let Inst{15-0} = addr;
}

class PageI8R<bits<4> sel, string name>
      : CenturionInst40<(outs), (ins GPR:$base, simm8:$disp, GPR:$dst),
        name, "(${base}),$disp,$dst"> {
  bits<4> base;
  bits<8> disp;
  bits<4> dst;
  let Inst{39-32} = 46;
  let Inst{31-28} = sel;
  let Inst{27-24} = 6;
  let Inst{23} = base{3};
  let Inst{22} = base{2};
  let Inst{21} = base{1};
  let Inst{20} = 0;
  let Inst{19-16} = 0;
  let Inst{15-8} = disp;
  let Inst{7-4} = 0;
  let Inst{3-0} = dst;
}

class PageI8I8<bits<4> sel, string name>
      : CenturionInst48<(outs), (ins GPR:$base, simm8:$disp, GPR:$base2, simm8:$disp2),
        name, "(${base}),$disp,(${base2}),$disp2"> {
  bits<4> base;
  bits<8> disp;
  bits<4> base2;
  bits<8> disp2;
  let Inst{47-40} = 46;
  let Inst{39-36} = sel;
  let Inst{35-32} = 5;
  let Inst{31} = base{3};
  let Inst{30} = base{2};
  let Inst{29} = base{1};
  let Inst{28} = 0;
  let Inst{27-24} = 0;
  let Inst{23-16} = disp;
  let Inst{15} = base2{3};
  let Inst{14} = base2{2};
  let Inst{13} = base2{1};
  let Inst{12} = 0;
  let Inst{11-8} = 0;
  let Inst{7-0} = disp2;
}

class PageI8I16<bits<4> sel, string name>
      : CenturionInst56<(outs), (ins GPR:$base, simm8:$disp, GPR:$base2, simm16:$wdisp2),
        name, "(${base}),$disp,(${base2}),(${wdisp2})"> {
  bits<4> base;
  bits<8> disp;
  bits<4> base2;
  bits<16> wdisp2;
  let Inst{55-48} = 46;
  let Inst{47-44} = sel;
  let Inst{43-40} = 5;
  let Inst{39} = base{3};
  let Inst{38} = base{2};
  let Inst{37} = base{1};
  let Inst{36} = 0;
  let Inst{35-32} = 0;
  let Inst{31-24} = disp;
  let Inst{23} = base2{3};
  let Inst{22} = base2{2};
  let Inst{21} = base2{1};
  let Inst{20} = 1;
  let Inst{19-16} = 0;
  let Inst{15-0} = wdisp2;
}

class PageI16D<bits<4> sel, string name>
      : CenturionInst56<(outs), (ins GPR:$base, simm16:$wdisp, i16imm:$addr),
        name, "(${base}),(${wdisp}),(${addr})"> {
  bits<4> base;
  bits<16> wdisp;
  bits<16> addr;
  let Inst{55-48} = 46;
  let Inst{47-44} = sel;
  let Inst{43-40} = 4;
  let Inst{39} = base{3};
  let Inst{38} = base{2};
  let Inst{37} = base{1};
  let Inst{36} = 1;
  let Inst{35-32} = 0;
  let Inst{31-16} = wdisp;
  let Inst{15-0} = addr;
}

class PageI16R<bits<4> sel, string name>
      : CenturionInst48<(outs), (ins GPR:$base, simm16:$wdisp, GPR:$dst),
        name, "(${base}),(${wdisp}),$dst"> {
  bits<4> base;
  bits<16> wdisp;
  bits<4> dst;
  let Inst{47-40} = 46;
  let Inst{39-36} = sel;
  let Inst{35-32} = 6;
  let Inst{31} = base{3};
  let Inst{30} = base{2};
  let Inst{29} = base{1};
  let Inst{28} = 1;
  let Inst{27-24} = 0;
  let Inst{23-8} = wdisp;
  let Inst{7-4} = 0;
  let Inst{3-0} = dst;
}

class PageI16I8<bits<4> sel, string name>
      : CenturionInst56<(outs), (ins GPR:$base, simm16:$wdisp, GPR:$base2, simm8:$disp2),
        name, "(${base}),(${wdisp}),(${base2}),$disp2"> {
  bits<4> base;
  bits<16> wdisp;
  bits<4> base2;
  bits<8> disp2;
  let Inst{55-48} = 46;
  let Inst{47-44} = sel;
  let Inst{43-40} = 5;
  let Inst{39} = base{3};
  let Inst{38} = base{2};
  let Inst{37} = base{1};
  let Inst{36} = 1;
  let Inst{35-32} = 0;
  let Inst{31-16} = wdisp;
  let Inst{15} = base2{3};
  let Inst{14} = base2{2};
  let Inst{13} = base2{1};
  let Inst{12} = 0;
  let Inst{11-8} = 0;
  let Inst{7-0} = disp2;
}

class BN6LitD<bits<4> sel, string name>
      : CenturionInst48<(outs), (ins uimm4:$k, i8imm:$lit, i16imm:$addr),
        name, "$k,$lit,(${addr})"> {
  bits<4> k;
  bits<8> lit;
  bits<16> addr;
  let Inst{47-40} = 70;
  let Inst{39-36} = 0;
  let Inst{35-32} = k;
  let Inst{31-28} = sel;
  let Inst{27-24} = 12;
  let Inst{23-16} = lit;
  let Inst{15-0} = addr;
}

class BN6LitI8<bits<4> sel, string name>
      : CenturionInst48<(outs), (ins uimm4:$k, i8imm:$lit, GPR:$base, simm8:$disp),
        name, "$k,$lit,(${base}),$disp"> {
  bits<4> k;
  bits<8> lit;
  bits<4> base;
  bits<8> disp;
  let Inst{47-40} = 70;
  let Inst{39-36} = 0;
  let Inst{35-32} = k;
  let Inst{31-28} = sel;
  let Inst{27-24} = 13;
  let Inst{23-16} = lit;
  let Inst{15} = base{3};
  let Inst{14} = base{2};
  let Inst{13} = base{1};
  let Inst{12} = 0;
  let Inst{11-8} = 0;
  let Inst{7-0} = disp;
}

class BN6LitR<bits<4> sel, string name>
      : CenturionInst40<(outs), (ins uimm4:$k, i8imm:$lit, GPR:$dst),
        name, "$k,$lit,$dst"> {
  bits<4> k;
  bits<8> lit;
  bits<4> dst;
  let Inst{39-32} = 70;
  let Inst{31-28} = 0;
  let Inst{27-24} = k;
  let Inst{23-20} = sel;
  let Inst{19-16} = 14;
  let Inst{15-8} = lit;
  let Inst{7-4} = 0;
  let Inst{3-0} = dst;
}

class BN6LitI16<bits<4> sel, string name>
      : CenturionInst56<(outs), (ins uimm4:$k, i8imm:$lit, GPR:$base, simm16:$wdisp),
        name, "$k,$lit,(${base}),(${wdisp})"> {
  bits<4> k;
  bits<8> lit;
  bits<4> base;
  bits<16> wdisp;
  let Inst{55-48} = 70;
  let Inst{47-44} = 0;
  let Inst{43-40} = k;
  let Inst{39-36} = sel;
  let Inst{35-32} = 13;
  let Inst{31-24} = lit;
  let Inst{23} = base{3};
  let Inst{22} = base{2};
  let Inst{21} = base{1};
  let Inst{20} = 1;
  let Inst{19-16} = 0;
  let Inst{15-0} = wdisp;
}

class STRReg16
      : CenturionInst16<(outs), (ins GPR:$src, GPR:$dst),
        "STR", "$src,$dst"> {
  bits<4> src;
  bits<4> dst;
  let Inst{15-8} = 214;
  let Inst{7-4} = src;
  let Inst{3-0} = dst;
}

class STRLit32
      : CenturionInst32<(outs), (ins GPR:$dst, i16imm:$imm),
        "STR", "$dst,$imm"> {
  bits<4> dst;
  bits<16> imm;
  let Inst{31-24} = 214;
  let Inst{23-20} = 1;
  let Inst{19-16} = dst;
  let Inst{15-0} = imm;
}

foreach OP = [
    OpSel<"MVF", 4>,
    OpSel<"CPF", 8>
] in {
  def OP.Name#_RR : Mem47RR<OP.Sel, OP.Name>;
}

foreach OP = [
    OpSel<"MVF", 4>,
    OpSel<"CPF", 8>
] in {
  def OP.Name#_RD : Mem47RD<OP.Sel, OP.Name>;
}

foreach OP = [
    OpSel<"MVF", 4>,
    OpSel<"CPF", 8>
] in {
  def OP.Name#_DR : Mem47DR<OP.Sel, OP.Name>;
}

foreach OP = [
    OpSel<"MVF", 4>,
    OpSel<"CPF", 8>
] in {
  def OP.Name#_DD : Mem47DD<OP.Sel, OP.Name>;
}

foreach OP = [
    OpSel<"MVF", 4>,
    OpSel<"CPF", 8>
] in {
  def OP.Name#_I8D : Mem47I8D<OP.Sel, OP.Name>;
}

foreach OP = [
    OpSel<"MVF", 4>,
    OpSel<"CPF", 8>
] in {
  def OP.Name#_DI8 : Mem47DI8<OP.Sel, OP.Name>;
}

foreach OP = [
    OpSel<"MVF", 4>,
    OpSel<"CPF", 8>
] in {
  def OP.Name#_I8I8 : Mem47I8I8<OP.Sel, OP.Name>;
}

foreach OP = [
    OpSel<"MVF", 4>,
    OpSel<"CPF", 8>
] in {
  def OP.Name#_I8R : Mem47I8R<OP.Sel, OP.Name>;
}

foreach OP = [
    OpSel<"MVF", 4>,
    OpSel<"CPF", 8>
] in {
  def OP.Name#_RI8 : Mem47RI8<OP.Sel, OP.Name>;
}

foreach OP = [
    OpSel<"MVF", 4>,
    OpSel<"CPF", 8>
] in {
  def OP.Name#_I16R : Mem47I16R<OP.Sel, OP.Name>;
}

foreach OP = [
    OpSel<"MVF", 4>,
    OpSel<"CPF", 8>
] in {
  def OP.Name#_RI16 : Mem47RI16<OP.Sel, OP.Name>;
}

foreach OP = [
    OpSel<"FIL", 9>
] in {
  def OP.Name#_R : Fil47R<OP.Sel, OP.Name>;
}

foreach OP = [
    OpSel<"FIL", 9>
] in {
  def OP.Name#_I8 : Fil47I8<OP.Sel, OP.Name>;
}

foreach OP = [
    OpSel<"FIL", 9>
] in {
  def OP.Name#_I16 : Fil47I16<OP.Sel, OP.Name>;
}

foreach OP = [
    OpSel<"CPFR", 8>
] in {
  def OP.Name#_RR : Mem67RR<OP.Sel, OP.Name>;
}

foreach OP = [
    OpSel<"MVFR", 4>,
    OpSel<"CPFR", 8>
] in {
  def OP.Name#_RD : Mem67RD<OP.Sel, OP.Name>;
}

foreach OP = [
    OpSel<"MVFR", 4>,
    OpSel<"CPFR", 8>
] in {
  def OP.Name#_DR : Mem67DR<OP.Sel, OP.Name>;
}

foreach OP = [
    OpSel<"MVFR", 4>,
    OpSel<"CPFR", 8>
] in {
  def OP.Name#_DD : Mem67DD<OP.Sel, OP.Name>;
}

foreach OP = [
    OpSel<"MVFR", 4>,
    OpSel<"CPFR", 8>
] in {
  def OP.Name#_I8R : Mem67I8R<OP.Sel, OP.Name>;
}

foreach OP = [
    OpSel<"MVFR", 4>,
    OpSel<"CPFR", 8>
] in {
  def OP.Name#_RI8 : Mem67RI8<OP.Sel, OP.Name>;
}

foreach OP = [
    OpSel<"MVFR", 4>,
    OpSel<"CPFR", 8>
] in {
  def OP.Name#_I8D : Mem67I8D<OP.Sel, OP.Name>;
}

foreach OP = [
    OpSel<"MVFR", 4>,
    OpSel<"CPFR", 8>
] in {
  def OP.Name#_DI8 : Mem67DI8<OP.Sel, OP.Name>;
}

foreach OP = [
    OpSel<"MVFR", 4>,
    OpSel<"CPFR", 8>
] in {
  def OP.Name#_I8I8 : Mem67I8I8<OP.Sel, OP.Name>;
}

foreach OP = [
    OpSel<"MVFR", 4>,
    OpSel<"CPFR", 8>
] in {
  def OP.Name#_I16R : Mem67I16R<OP.Sel, OP.Name>;
}

foreach OP = [
    OpSel<"MVFR", 4>,
    OpSel<"CPFR", 8>
] in {
  def OP.Name#_RI16 : Mem67RI16<OP.Sel, OP.Name>;
}

foreach OP = [
    OpSel<"MVFR", 4>,
    OpSel<"CPFR", 8>
] in {
  def OP.Name#_I16D : Mem67I16D<OP.Sel, OP.Name>;
}

foreach OP = [
    OpSel<"MVFR", 4>,
    OpSel<"CPFR", 8>
] in {
  def OP.Name#_DI16 : Mem67DI16<OP.Sel, OP.Name>;
}

foreach OP = [
    OpSel<"MVFR", 4>,
    OpSel<"CPFR", 8>
] in {
  def OP.Name#_I8I16 : Mem67I8I16<OP.Sel, OP.Name>;
}

foreach OP = [
    OpSel<"MVFR", 4>,
    OpSel<"CPFR", 8>
] in {
  def OP.Name#_I16I8 : Mem67I16I8<OP.Sel, OP.Name>;
}

foreach OP = [
    OpSel<"FILR", 9>
] in {
  def OP.Name#_R : Fil67R<OP.Sel, OP.Name>;
}

foreach OP = [
    OpSel<"FILR", 9>
] in {
  def OP.Name#_D : Fil67D<OP.Sel, OP.Name>;
}

foreach OP = [
    OpSel<"FILR", 9>
] in {
  def OP.Name#_I8 : Fil67I8<OP.Sel, OP.Name>;
}

foreach OP = [
    OpSel<"FILR", 9>
] in {
  def OP.Name#_I16 : Fil67I16<OP.Sel, OP.Name>;
}

foreach OP = [
    OpSel<"LDM", 0>,
    OpSel<"STM", 1>,
    OpSel<"LSM", 2>,
    OpSel<"SSM", 3>,
    OpSel<"FLM", 4>,
    OpSel<"MFM", 5>
] in {
  def OP.Name#_M3D : PageM3D<OP.Sel, OP.Name>;
}

foreach OP = [
    OpSel<"LDM", 0>,
    OpSel<"STM", 1>,
    OpSel<"LSM", 2>,
    OpSel<"SSM", 3>,
    OpSel<"FLM", 4>,
    OpSel<"MFM", 5>
] in {
  def OP.Name#_M3R : PageM3R<OP.Sel, OP.Name>;
}

foreach OP = [
    OpSel<"LDM", 0>,
    OpSel<"STM", 1>,
    OpSel<"LSM", 2>,
    OpSel<"SSM", 3>,
    OpSel<"FLM", 4>,
    OpSel<"MFM", 5>
] in {
  def OP.Name#_M3I8 : PageM3I8<OP.Sel, OP.Name>;
}

foreach OP = [
    OpSel<"LDM", 0>,
    OpSel<"STM", 1>,
    OpSel<"LSM", 2>,
    OpSel<"SSM", 3>,
    OpSel<"FLM", 4>,
    OpSel<"MFM", 5>
] in {
  def OP.Name#_M3I16 : PageM3I16<OP.Sel, OP.Name>;
}

foreach OP = [
    OpSel<"LDM", 0>,
    OpSel<"STM", 1>,
    OpSel<"LSM", 2>,
    OpSel<"SSM", 3>,
    OpSel<"FLM", 4>,
    OpSel<"MFM", 5>
] in {
  def OP.Name#_DD : PageDD<OP.Sel, OP.Name>;
}

foreach OP = [
    OpSel<"LDM", 0>,
    OpSel<"STM", 1>,
    OpSel<"LSM", 2>,
    OpSel<"SSM", 3>,
    OpSel<"FLM", 4>,
    OpSel<"MFM", 5>
] in {
  def OP.Name#_DR : PageDR<OP.Sel, OP.Name>;
}

foreach OP = [
    OpSel<"LDM", 0>,
    OpSel<"STM", 1>,
    OpSel<"LSM", 2>,
    OpSel<"SSM", 3>,
    OpSel<"FLM", 4>,
    OpSel<"MFM", 5>
] in {
  def OP.Name#_DI8 : PageDI8<OP.Sel, OP.Name>;
}

foreach OP = [
    OpSel<"LDM", 0>,
    OpSel<"STM", 1>,
    OpSel<"LSM", 2>,
    OpSel<"SSM", 3>,
    OpSel<"FLM", 4>,
    OpSel<"MFM", 5>
] in {
  def OP.Name#_DI16 : PageDI16<OP.Sel, OP.Name>;
}

foreach OP = [
    OpSel<"LDM", 0>,
    OpSel<"STM", 1>,
    OpSel<"LSM", 2>,
    OpSel<"SSM", 3>,
    OpSel<"FLM", 4>,
    OpSel<"MFM", 5>
] in {
  def OP.Name#_RD : PageRD<OP.Sel, OP.Name>;
}

foreach OP = [
    OpSel<"LDM", 0>,
    OpSel<"STM", 1>,
    OpSel<"LSM", 2>,
    OpSel<"SSM", 3>,
    OpSel<"FLM", 4>,
    OpSel<"MFM", 5>
] in {
  def OP.Name#_RR : PageRR<OP.Sel, OP.Name>;
}

foreach OP = [
    OpSel<"LDM", 0>,
    OpSel<"STM", 1>,
    OpSel<"LSM", 2>,
    OpSel<"SSM", 3>,
    OpSel<"FLM", 4>,
    OpSel<"MFM", 5>
] in {
  def OP.Name#_RI8 : PageRI8<OP.Sel, OP.Name>;
}

foreach OP = [
    OpSel<"LDM", 0>,
    OpSel<"STM", 1>,
    OpSel<"LSM", 2>,
    OpSel<"SSM", 3>,
    OpSel<"FLM", 4>,
    OpSel<"MFM", 5>
] in {
  def OP.Name#_RI16 : PageRI16<OP.Sel, OP.Name>;
}

foreach OP = [
    OpSel<"LDM", 0>,
    OpSel<"STM", 1>,
    OpSel<"LSM", 2>,
    OpSel<"SSM", 3>,
    OpSel<"FLM", 4>,
    OpSel<"MFM", 5>
] in {
  def OP.Name#_I8D : PageI8D<OP.Sel, OP.Name>;
}

foreach OP = [
    OpSel<"LDM", 0>,
    OpSel<"STM", 1>,
    OpSel<"LSM", 2>,
    OpSel<"SSM", 3>,
    OpSel<"FLM", 4>,
    OpSel<"MFM", 5>
] in {
  def OP.Name#_I8R : PageI8R<OP.Sel, OP.Name>;
}

foreach OP = [
    OpSel<"LDM", 0>,
    OpSel<"STM", 1>,
    OpSel<"LSM", 2>,
    OpSel<"SSM", 3>,
    OpSel<"FLM", 4>,
    OpSel<"MFM", 5>
] in {
  def OP.Name#_I8I8 : PageI8I8<OP.Sel, OP.Name>;
}

foreach OP = [
    OpSel<"LDM", 0>,
    OpSel<"STM", 1>,
    OpSel<"LSM", 2>,
    OpSel<"SSM", 3>,
    OpSel<"FLM", 4>,
    OpSel<"MFM", 5>
] in {
  def OP.Name#_I8I16 : PageI8I16<OP.Sel, OP.Name>;
}

foreach OP = [
    OpSel<"LDM", 0>,
    OpSel<"STM", 1>,
    OpSel<"LSM", 2>,
    OpSel<"SSM", 3>,
    OpSel<"FLM", 4>,
    OpSel<"MFM", 5>
] in {
  def OP.Name#_I16D : PageI16D<OP.Sel, OP.Name>;
}

foreach OP = [
    OpSel<"LDM", 0>,
    OpSel<"STM", 1>,
    OpSel<"LSM", 2>,
    OpSel<"SSM", 3>,
    OpSel<"FLM", 4>,
    OpSel<"MFM", 5>
] in {
  def OP.Name#_I16R : PageI16R<OP.Sel, OP.Name>;
}

foreach OP = [
    OpSel<"LDM", 0>,
    OpSel<"STM", 1>,
    OpSel<"LSM", 2>,
    OpSel<"SSM", 3>,
    OpSel<"FLM", 4>,
    OpSel<"MFM", 5>
] in {
  def OP.Name#_I16I8 : PageI16I8<OP.Sel, OP.Name>;
}

foreach OP = [
    OpSel<"BNA", 0>,
    OpSel<"BNS", 1>,
    OpSel<"BNC", 2>,
    OpSel<"ZAD", 3>,
    OpSel<"ZSU", 4>,
    OpSel<"M", 5>,
    OpSel<"D", 6>,
    OpSel<"DRM", 7>,
    OpSel<"CTB", 8>,
    OpSel<"CFB", 9>
] in {
  def OP.Name#_LitD : BN6LitD<OP.Sel, OP.Name>;
}

foreach OP = [
    OpSel<"BNA", 0>,
    OpSel<"BNS", 1>,
    OpSel<"BNC", 2>,
    OpSel<"ZAD", 3>,
    OpSel<"ZSU", 4>,
    OpSel<"M", 5>,
    OpSel<"D", 6>,
    OpSel<"DRM", 7>,
    OpSel<"CTB", 8>,
    OpSel<"CFB", 9>
] in {
  def OP.Name#_LitI8 : BN6LitI8<OP.Sel, OP.Name>;
}

foreach OP = [
    OpSel<"BNA", 0>,
    OpSel<"BNS", 1>,
    OpSel<"BNC", 2>,
    OpSel<"ZAD", 3>,
    OpSel<"ZSU", 4>,
    OpSel<"M", 5>,
    OpSel<"D", 6>,
    OpSel<"DRM", 7>,
    OpSel<"CTB", 8>,
    OpSel<"CFB", 9>
] in {
  def OP.Name#_LitR : BN6LitR<OP.Sel, OP.Name>;
}

foreach OP = [
    OpSel<"BNA", 0>,
    OpSel<"BNS", 1>,
    OpSel<"BNC", 2>,
    OpSel<"ZAD", 3>,
    OpSel<"ZSU", 4>,
    OpSel<"M", 5>,
    OpSel<"D", 6>,
    OpSel<"DRM", 7>,
    OpSel<"CTB", 8>,
    OpSel<"CFB", 9>
] in {
  def OP.Name#_LitI16 : BN6LitI16<OP.Sel, OP.Name>;
}

def STRReg : STRReg16;
def STRLit : STRLit32;



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
def DCX : Implicit<0x3F, "DCX">;        // Decrement X Register


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
class DoubleReg16<bits<8> opcode, string opstr, DAGOperand optype1=GPR, DAGOperand optype2=GPR>
      : SingleArg16HL<opcode, (outs optype1: $arglnibble), (ins optype2: $arghnibble),
                     opstr, "$arghnibble,$arglnibble"> { }
// Byte operation flavor
class DoubleReg16_B<bits<8> opcode,  string opstr>
      : SingleArg16HL<opcode, (outs GPRB: $arglnibble), (ins GPRB: $arghnibble),
                     opstr, "$arghnibble,$arglnibble"> { }

// Assembler form. $arglnibble is only an output, so a SelectionDAG pattern
// cannot say "this register is both read and written". Codegen wants its own
// def in CPU6InstrPatterns.td.
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

// 5x extended form. The low bit of each nibble is a mode, not a register.
// This def is mode 2: source nibble odd, destination nibble even, then a
// big-endian imm16. webCenREE rrfetchw reads $src (low bit ignored) and the
// literal, and writes $dst. ADD is dst = src + imm. Phire `50 54 ff ec` is
// ADD X, X, 0xffec. The even/even register form is DoubleReg16, so the two
// encodings do not alias. Condition codes change and are not modeled yet.
let hasSideEffects = 0, mayLoad = 0, mayStore = 0 in
class DoubleRegImm32<bits<8> opcode, string opstr>
      : CenturionInst32<(outs GPR:$dst), (ins GPR:$src, i16imm:$imm),
                        opstr, "$src,$dst,$imm"> {
  bits<4> src;
  bits<4> dst;
  bits<16> imm;
  let Inst{31-24} = opcode;
  let Inst{23} = src{3};
  let Inst{22} = src{2};
  let Inst{21} = src{1};
  let Inst{20} = 1;
  let Inst{19-16} = dst;
  let Inst{15-0} = imm;
}
def ADDimm : DoubleRegImm32<0x50, "ADD">;
// Same literal tail: odd high nibble, even destination, big-endian imm16.
// load7: `51 10 7f ff` sub A,A; `52 10 00 02` and A,A; `53 10 00 01` or A,A;
// `53 32 00 03` or B,B; `54 10 00 02` xor A,A. `77 32 00 0a` is multiply
// and `78 32 01 90` is divide. load7's text swaps those two names; the
// wiki's 0x78 row is DIV.
def SUBimm : DoubleRegImm32<0x51, "SUB">;
def ANDimm : DoubleRegImm32<0x52, "AND">;
def ORIimm : DoubleRegImm32<0x53, "ORI">;
def OREimm : DoubleRegImm32<0x54, "ORE">;

// XFR literal ignores the source register. Phire writes the destination
// into both nibbles and sets the source nibble's low bit: `55 98 f2 00`
// is mov Z, 0xf200. $dst is an output so the assembler and instruction
// selection share this record. The pattern is in CPU6InstrPatterns.td.
let hasSideEffects = 0, mayLoad = 0, mayStore = 0, isMoveImm = 1,
    isAsCheapAsAMove = 1, isReMaterializable = 1 in
class XFRImm32
      : CenturionInst32<(outs GPR:$dst), (ins i16imm:$imm),
                        "XFR", "$dst,$imm"> {
  bits<4> dst;
  bits<16> imm;
  let Inst{31-24} = 0x55;
  let Inst{23} = dst{3};
  let Inst{22} = dst{2};
  let Inst{21} = dst{1};
  let Inst{20} = 1;
  let Inst{19} = dst{3};
  let Inst{18} = dst{2};
  let Inst{17} = dst{1};
  let Inst{16} = dst{0};
  let Inst{15-0} = imm;
}
def XFRimm : XFRImm32;

// Mode 3, both nibbles odd: dst <- word at (base + big-endian imm16).
// webCenREE rrfetchw adds get_rw(high) to the literal and loads low from
// there. The inverse of STRidx, and loadRegFromStackSlot's reload with S
// as the base and a frame index as the displacement.
let hasSideEffects = 0, mayLoad = 1, mayStore = 0 in
class XFRIdx32
      : CenturionInst32<(outs GPR:$dst), (ins GPR:$base, i16imm:$disp),
                        "XFR", "(${base}),$dst,$disp"> {
  bits<4> dst;
  bits<4> base;
  bits<16> disp;
  let Inst{31-24} = 0x55;
  let Inst{23} = base{3};
  let Inst{22} = base{2};
  let Inst{21} = base{1};
  let Inst{20} = 1;
  let Inst{19} = dst{3};
  let Inst{18} = dst{2};
  let Inst{17} = dst{1};
  let Inst{16} = 1;
  let Inst{15-0} = disp;
}
def XFRidx : XFRIdx32;
def MUL: DoubleReg16<0x77, "MUL">;    // Unsigned multiply
def DIV: DoubleReg16<0x78, "DIV">;    // Unsigned divide
def MULimm : DoubleRegImm32<0x77, "MUL">;
def DIVimm : DoubleRegImm32<0x78, "DIV">;
// Odd/odd is indexed, not another imm16. load7 `78 93 00 1c` is
// div B, [Z+0x001c], B. Wiki: dest <- dest / index(src). High nibble
// is the index with its low bit set. Low nibble is the destination
// with its low bit set. The tail is a big-endian displacement.
// The literal form keeps the destination even, so the two do not alias.
class DIVIdx32
      : CenturionInst32<(outs), (ins GPR:$src, GPR:$dst, i16imm:$disp),
                        "DIV", "(${src}),$dst,$disp"> {
  bits<4> src;
  bits<4> dst;
  bits<16> disp;
  let Inst{31-24} = 0x78;
  let Inst{23} = src{3};
  let Inst{22} = src{2};
  let Inst{21} = src{1};
  let Inst{20} = 1;
  let Inst{19} = dst{3};
  let Inst{18} = dst{2};
  let Inst{17} = dst{1};
  let Inst{16} = 1;
  let Inst{15-0} = disp;
}
def DIVidx : DIVIdx32;
// Push or pop a run of bytes through S. The high nibble names the first
// register. The low nibble is one less than the number of bytes moved, so
// 5 means 6 bytes and 1 means 2. An even count covers whole words:
// `7e 45` is `STK X,5` and pushes X, Y, Z; `7e 81` is `STK Z,1` and pushes Z.
// STK walks down from the end of that run and leaves S pointing at the
// first byte. POP uses the same operand byte (`7f 45`, `7f 81`), fills the
// registers from S upward, and moves S back.
// STK reads the named register (and, at the prologue, the rest of the run as
// implicit uses). POP writes it. S is both: the instruction reads the old
// pointer and leaves the new one. The assembler syntax stays `STK X,5`.
let Uses = [rS], Defs = [rS], mayStore = 1 in
def STK : SingleArg16HL<0x7E, (outs),
                        (ins GPR:$arghnibble, uimm4:$arglnibble),
                        "STK", "$arghnibble,$arglnibble">;
let Uses = [rS], Defs = [rS], mayLoad = 1 in
def POP : SingleArg16HL<0x7F, (outs GPR:$arghnibble),
                        (ins uimm4:$arglnibble),
                        "POP", "$arghnibble,$arglnibble">;

// High nibble is the interrupt level. Low nibble is the word register.
// `d7 6e` stores A into P at level 6. `e6 60` loads A from A at level 6.
class ILMove16<bits<8> opcode, string opstr>
      : SingleArg16HL<opcode, (outs), (ins uimm4:$arghnibble, GPR:$arglnibble),
                     opstr, "$arghnibble,$arglnibble"> {}
def SAR : ILMove16<0xD7, "SAR">;
def LAR : ILMove16<0xE6, "LAR">;

// F6 byte move between a low byte register and MMIO[base + disp8].
// The base nibble's low bit is 0 for load and 1 for store.
// `f6 18 00` loads AL from Device[Z]. `f6 19 0d` stores AL to Device[Z+0x0d].
class MMIO24<bit dir, string opstr>
      : CenturionInst24<(outs), (ins GPRlo:$sr, GPR:$base, i8imm:$disp),
                        opstr, "$sr,$base,$disp"> {
  bits<4> sr;
  bits<4> base;
  bits<8> disp;
  let Inst{23-16} = 0xF6;
  let Inst{15-12} = sr;
  let Inst{11} = base{3};
  let Inst{10} = base{2};
  let Inst{9} = base{1};
  let Inst{8} = dir;
  let Inst{7-0} = disp;
}
def LIO : MMIO24<0, "LIO">;
def SIO : MMIO24<1, "SIO">;

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
    def OP.Name#_0 : MemRef24<OP.Opcodew, 0x0, i16imm, OP.Name>;                    //immediate
    // Byte literal is the opcode byte and one immediate byte:
    // LDAB 0x80, STAB 0xA0, LDBB 0xC0, STBB 0xE0. Word literals stay 16-bit.
    def OP.Name#B_0 : MemRef16<OP.Opcodeb, 0x0, i8imm, OP.Name#"B">;
    def OP.Name#_1 : MemRef24<OP.Opcodew, 0x1, i16imm, OP.Name, "(${arg})">;        //(ptr)
    def OP.Name#B_1 : MemRef24<OP.Opcodeb, 0x1, i16imm, OP.Name#"B", "(${arg})">;   //(ptr)
    def OP.Name#_2 : MemRef24<OP.Opcodew, 0x2, i16imm, OP.Name, "((${arg}))">;      //((ptr))
    def OP.Name#B_2 : MemRef24<OP.Opcodeb, 0x2, i16imm, OP.Name#"B", "((${arg}))">; //((ptr))
    def OP.Name#_3 : MemRef16<OP.Opcodew, 0x3, i8imm, OP.Name, "(PC),$arg">;        //((offset)
    def OP.Name#B_3 : MemRef16<OP.Opcodeb, 0x3, i8imm, OP.Name#"B", "(PC),$arg">;   //(offset)
    def OP.Name#_4 : MemRef16<OP.Opcodew, 0x4, i8imm, OP.Name, "((PC),${arg})">;    //((offset))
    def OP.Name#B_4 : MemRef16<OP.Opcodeb, 0x4, i8imm, OP.Name#"B", "((PC),${arg})">; //((offset))
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
    def OP.Name#_5_C: MemRef24Index<OP.Opcodew, 0xC, GPR, OP.Name#"_?", "(${r}),$arg">;  //(r),disp
    def OP.Name#B_5_C: MemRef24Index<OP.Opcodeb, 0xC, GPRB, OP.Name#"B_?", "(${r}),$arg">;  //(r),disp
    def OP.Name#_5_D: MemRef24Index<OP.Opcodew, 0xD, GPR, OP.Name#"_I", "((${r})),$arg">;   //I ((r)),disp
    def OP.Name#B_5_D: MemRef24Index<OP.Opcodeb, 0xD, GPRB, OP.Name#"B_I", "((${r})),$arg">;   //I ((r)),disp
    def OP.Name#_5_E: MemRef24Index<OP.Opcodew, 0xE, GPR, OP.Name#"_D", "((${r})),$arg">;   //D ((r)),disp
    def OP.Name#B_5_E: MemRef24Index<OP.Opcodeb, 0xE, GPRB, OP.Name#"B_D", "((${r})),$arg">;   //D ((r)),disp
    // F is not used
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
    def OP.Name#_3 : MemRef16Strange<OP.Opcode, 0b011, i8imm, OP.Name, "(PC),$arg">;
    def OP.Name#_4 : MemRef16Strange<OP.Opcode, 0b100, i8imm, OP.Name, "((PC),${arg})">;
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
    def OP.Name#_5_C: MemRef24IndexStrange<OP.Opcode, 0xC, GPR, OP.Name#"_?", "(${r}),${arg}">;
    def OP.Name#_5_D: MemRef24IndexStrange<OP.Opcode, 0xD, GPR, OP.Name#"_I", "((${r})),$arg">;
    def OP.Name#_5_E: MemRef24IndexStrange<OP.Opcode, 0xE, GPR, OP.Name#"_D", "((${r})),$arg">;
}

class TwoArg24<bits<8> opcode, string opstr, string argstr="$arg1,$arg2">
      : DoubleArg24<opcode, (outs), (ins i8imm: $arg1, i8imm: $arg2), opstr, argstr> { }

def LST: TwoArg24<0x6E, "LST", "(${arg1}),(${arg2})">;
def SST: TwoArg24<0x6F, "SST", "(${arg1}),(${arg2})">;