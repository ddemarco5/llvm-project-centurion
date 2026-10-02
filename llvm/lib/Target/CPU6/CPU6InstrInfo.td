include "CPU6InstrFormats.td"

//===----------------------------------------------------------------------===//
//
// CPU6 instructions, grouped as in CPU6InstrPatterns.td. Control, branches,
// the register/count family, ALU, transfers, stack, memory, and calls come
// first. Block move, bignum, the page table, DMA, interrupt and MMIO, and
// status follow. Instructions that share a mnemonic stay in their previous
// order.
//
//===----------------------------------------------------------------------===//

//===----------------------------------------------------------------------===//
// Operands
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
// unsigned 4 bit immediate. The parser class limits it to 0-15; the i8 type
// is what instruction selection builds the constant as.
def uimm4 : Operand<i8> {
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

// A branch target or other PC-relative byte. A symbol is fixup_cpu6_pcrel_8:
// the displacement is from the next instruction. The field is the last byte
// of the instruction, which is true of every 2-byte branch and (PC)+b form.
def BRTargetAsmOperand : AsmOperandClass {
    let Name = "BRTarget";
    let RenderMethod = "addImmOperands";
    let DiagnosticType = "InvalidBRTarget";
}
def brtarget : Operand<i8> {
    let ParserMatchClass = BRTargetAsmOperand;
    let EncoderMethod = "getPCRel8OpValue";
    let DecoderMethod = "decodeSImmOperand<8>";
}
// (PC)+b accepts the same signed range and also the unsigned byte the
// numeric tests already use (LDA (PC),205 is the bit pattern of -51).
def PCOff8AsmOperand : AsmOperandClass {
    let Name = "PCOff8";
    let RenderMethod = "addImmOperands";
    let DiagnosticType = "InvalidPCOff8";
}
def pcoff8 : Operand<i8> {
    let ParserMatchClass = PCOff8AsmOperand;
    let EncoderMethod = "getPCRel8OpValue";
    let DecoderMethod = "decodeUImmOperand<8>";
}
// Trailing big-endian address or address immediate. A symbol is
// fixup_cpu6_abs_16. The encoder places that fixup at Size-2, so this
// operand is only for instructions whose imm16 is the last two bytes.
def Abs16AsmOperand : AsmOperandClass {
    let Name = "Abs16";
    let RenderMethod = "addImmOperands";
    let DiagnosticType = "InvalidAbs16";
}
def abs16 : Operand<i16> {
    let ParserMatchClass = Abs16AsmOperand;
    let EncoderMethod = "getAbs16OpValue";
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

//===----------------------------------------------------------------------===//
// Control
//===----------------------------------------------------------------------===//

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

//===----------------------------------------------------------------------===//
// Branches
//===----------------------------------------------------------------------===//

// The operation code byte defines the condition being tested
// The displacement byte, b, contains an eight-bit signed value which specifies
// a jump location relative to PC
// Instruction: <| one |opcode|+127, -128|>
//               |  op code   | disp (b) |
// opcode = 8 bits (high half ones)
// displacement = 8 bits
//------------------------------------//
class Branch<bits<8> opcode, string opstr>
      : SingleArg16<opcode, (outs), (ins brtarget:$argbyte), opstr, "$argbyte"> { }

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

//===----------------------------------------------------------------------===//
// Register and count
//===----------------------------------------------------------------------===//

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
// Word operation flavor of opcode. webCenREE rcfetchw reads the word
// register in the high nibble (an odd nibble is the memory form, CountMem32
// and CountIdx32 below) and writes the result back to it. The count is the
// low nibble plus the opcode's bias: 1 for INR, DCR, SRR, SLR, RRR, RLR.
// IVR ignores it.
let Constraints = "$arghnibble = $src", hasSideEffects = 0, mayLoad = 0,
    mayStore = 0 in
class SingleReg16<bits<8> opcode, string opstr>
      : SingleArg16HL<opcode, (outs GPR:$arghnibble),
                      (ins GPR:$src, uimm4:$arglnibble),
                      opstr, "$arghnibble,$arglnibble"> { }

// CLR has no bias: CLR r,n writes n (0-15), as CLRB does.
let hasSideEffects = 0, mayLoad = 0, mayStore = 0, isMoveImm = 1,
    isAsCheapAsAMove = 1, isReMaterializable = 1 in
class SingleReg16W<bits<8> opcode, string opstr>
      : SingleArg16HL<opcode, (outs GPR:$arghnibble), (ins uimm4:$arglnibble),
                      opstr, "$arghnibble,$arglnibble"> { }

// Byte operation flavor. webCenREE rcfetchb reads the byte register in the
// high nibble, adds the opcode's bias to the low nibble (1 for INRB, DCRB,
// SRRB, SLRB, RRRB, RLRB; 0 for CLRB), and writes the result back to the
// same register. $src is the register's incoming value.
let Constraints = "$arghnibble = $src", hasSideEffects = 0, mayLoad = 0,
    mayStore = 0 in
class SingleReg16_B<bits<8> opcode, string opstr>
      : SingleArg16HL<opcode, (outs GPRB:$arghnibble),
                      (ins GPRB:$src, uimm4:$arglnibble),
                      opstr, "$arghnibble,$arglnibble"> { }

// CLRB r,n writes n (0-15) into r without reading it: AOP.CLR stores the
// count field.
let hasSideEffects = 0, mayLoad = 0, mayStore = 0, isMoveImm = 1,
    isAsCheapAsAMove = 1, isReMaterializable = 1 in
class SingleReg16W_B<bits<8> opcode, string opstr>
      : SingleArg16HL<opcode, (outs GPRB:$arghnibble), (ins uimm4:$arglnibble),
                      opstr, "$arghnibble,$arglnibble"> { }

let Constraints = "$arghnibble = $src", hasSideEffects = 0, mayLoad = 0,
    mayStore = 0 in
class SingleReg16H_B<bits<8> opcode, string opstr>
      : SingleArg16H<opcode, (outs GPRB:$arghnibble), (ins GPRB:$src),
                     opstr, "$arghnibble"> { }

def INR : SingleReg16<0x30, "INR">;      // Increment Register
def INRB: SingleReg16_B<0x20, "INRB">;   // Increment Register (Byte mode)
def DCR : SingleReg16<0x31, "DCR">;      // Decrement Register
def DCRB: SingleReg16_B<0x21, "DCRB">;   // Decrement Register (Byte mode)
// The low nibble is the value, not forced to 0. load7 `32 01` is
// clr A, #1 and `32 02` is clr A, #2. f1 `22 32` is clr BL, #2.
// Phire prints that nibble as the count; the encoded nibble is the value.
def CLR : SingleReg16W<0x32, "CLR">;     // Clear Register
def CLRB: SingleReg16W_B<0x22, "CLRB">;  // Clear Register (Byte mode)
def IVR : SingleReg16<0x33, "IVR">;      // Invert Register
def IVRB: SingleReg16H_B<0x23, "IVRB">;  // Invert Register (Byte mode)
def SRR : SingleReg16<0x34, "SRR">;      // Shift Register Right
// webCenREE's SRRB/SRR opf shifts left (src << count), same as SLRB/SLR.
// The sra patterns in CPU6InstrPatterns.td are commented out until that is
// confirmed as an emulator bug or a microcode bug. RRRB/RLRB/RRR/RLR have
// no handler.
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
// They read, modify and write the memory word; CLR only writes it.
let hasSideEffects = 0, mayLoad = 1, mayStore = 1 in
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
let hasSideEffects = 0, mayLoad = 1, mayStore = 1 in
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
let mayLoad = 0 in {
def CLRmem : CountMem32<0x32, "CLR">;
def CLRidx : CountIdx32<0x32, "CLR">;
}
def IVRmem : CountMem32<0x33, "IVR">;
def IVRidx : CountIdx32<0x33, "IVR">;
def SRRmem : CountMem32<0x34, "SRR">;
def SRRidx : CountIdx32<0x34, "SRR">;

//===----------------------------------------------------------------------===//
// One-byte forms
//===----------------------------------------------------------------------===//

// Instruction: <|opcode|>
// opcode = 8 bits
//---------------------------------------------------//
// This is the same as Control near the top of the file, but I want a new name for it to be pretty
class Implicit<bits<8> opcode, string opstr>
        : CenturionInst8<(outs), (ins), opstr> {
    let Inst{7-0} = opcode;
}

// The byte forms work on AL (webCenREE dr: REG.AL). INAB/DCAB add or subtract
// 1, CLAB writes 0, IVAB inverts, SRAB is an arithmetic shift right by 1 and
// SLAB a shift left by 1. They are one byte shorter than the explicit
// INRB AL,0 family, which selection uses because it takes any byte register.
// The word forms do the same to A, and INX/DCX to X.
let Uses = [rA], Defs = [rA], hasSideEffects = 0 in
def INA : Implicit<0x38, "INA">;        // Increment Accumulator by 1
let Uses = [rAL], Defs = [rAL], hasSideEffects = 0 in
def INAB: Implicit<0x28, "INAB">;       // Increment Accumulator by 1 (Byte mode)
let Uses = [rA], Defs = [rA], hasSideEffects = 0 in
def DCA : Implicit<0x39, "DCA">;        // Decrement Accumulator by 1
let Uses = [rAL], Defs = [rAL], hasSideEffects = 0 in
def DCAB: Implicit<0x29, "DCAB">;       // Decrement Accumulator by 1 (Byte mode)
let Defs = [rA], hasSideEffects = 0 in
def CLA : Implicit<0x3A, "CLA">;        // Clear Accumulator
let Defs = [rAL], hasSideEffects = 0 in
def CLAB: Implicit<0x2A, "CLAB">;       // Clear Accumulator (Byte mode)
let Uses = [rA], Defs = [rA], hasSideEffects = 0 in
def IVA : Implicit<0x3B, "IVA">;        // Invert Accumulator
let Uses = [rAL], Defs = [rAL], hasSideEffects = 0 in
def IVAB: Implicit<0x2B, "IVAB">;       // Invert Accumulator (Byte mode)
let Uses = [rA], Defs = [rA], hasSideEffects = 0 in
def SRA : Implicit<0x3C, "SRA">;        // Shift Accumulator Right
let Uses = [rAL], Defs = [rAL], hasSideEffects = 0 in
def SRAB: Implicit<0x2C, "SRAB">;       // Shift Accumulator Right (Byte mode)
let Uses = [rA], Defs = [rA], hasSideEffects = 0 in
def SLA : Implicit<0x3D, "SLA">;        // Shift Accumulator Left
let Uses = [rAL], Defs = [rAL], hasSideEffects = 0 in
def SLAB: Implicit<0x2D, "SLAB">;       // Shift Accumulator Left (Byte mode)
let Uses = [rX], Defs = [rX], hasSideEffects = 0 in {
def INX : Implicit<0x3E, "INX">;        // Inrement X Register
def DCX : Implicit<0x3F, "DCX">;        // Decrement X Register
}

//===----------------------------------------------------------------------===//
// ALU
//===----------------------------------------------------------------------===//

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
// Word operation flavor of opcode. Both nibbles even: webCenREE rrfetchw
// mode 0 reads two word registers. Odd nibbles are the literal and indexed
// forms (DoubleRegImm32, XFRIdx32 and friends).
class DoubleReg16<bits<8> opcode, string opstr>
      : SingleArg16HL<opcode, (outs GPR:$arglnibble), (ins GPR:$arghnibble),
                     opstr, "$arghnibble,$arglnibble"> { }
// Word ALU ops read the destination too, with the same operand order as the
// byte forms: SUB src,dst is dst = src - dst.
let Constraints = "$arglnibble = $base", hasSideEffects = 0,
    mayLoad = 0, mayStore = 0 in
class DoubleReg16RMW<bits<8> opcode, string opstr>
      : SingleArg16HL<opcode, (outs GPR:$arglnibble),
                      (ins GPR:$arghnibble, GPR:$base),
                      opstr, "$arghnibble,$arglnibble"> { }
// Byte operation flavor. webCenREE rrfetchb reads both nibbles as byte
// register numbers (AL is 1, BU is 2); the byte form has no literal or
// indexed modes, so odd nibbles are registers here.
class DoubleReg16_B<bits<8> opcode,  string opstr>
      : SingleArg16HL<opcode, (outs GPRB: $arglnibble), (ins GPRB: $arghnibble),
                     opstr, "$arghnibble,$arglnibble"> { }
// Byte ALU ops read the destination as well as writing it: dst = dst op src,
// except SUBB, which is dst = src - dst (flags_a8vmfl(src, dst, 1)). $base is
// the incoming value of the destination register.
let Constraints = "$arglnibble = $base", hasSideEffects = 0,
    mayLoad = 0, mayStore = 0 in
class DoubleReg16_BRMW<bits<8> opcode, string opstr>
      : SingleArg16HL<opcode, (outs GPRB:$arglnibble),
                      (ins GPRB:$arghnibble, GPRB:$base),
                      opstr, "$arghnibble,$arglnibble"> { }

// The two-address pass may swap source and destination of all but SUB to
// leave the result where it is wanted.
let isCommutable = 1 in {
def ADD : DoubleReg16RMW<0x50, "ADD">;     // Add
def ADDB: DoubleReg16_BRMW<0x40, "ADDB">;  // Add (Byte mode)
}
def SUB : DoubleReg16RMW<0x51, "SUB">;     // Subtract
def SUBB: DoubleReg16_BRMW<0x41, "SUBB">;  // Subtract (Byte mode)
let isCommutable = 1 in {
def AND : DoubleReg16RMW<0x52, "AND">;     // AND
def ANDB: DoubleReg16_BRMW<0x42, "ANDB">;  // AND (Byte mode)
def ORI : DoubleReg16RMW<0x53, "ORI">;     // OR Inlusive
def ORIB: DoubleReg16_BRMW<0x43, "ORIB">;  // OR Inclusive (Byte mode)
def ORE : DoubleReg16RMW<0x54, "ORE">;     // OR Exclusive
def OREB: DoubleReg16_BRMW<0x44, "OREB">;  // OR Exclusive (Byte mode)
}

// 5x extended form. The low bit of each nibble is a mode, not a register.
// This def is mode 2: source nibble odd, destination nibble even, then a
// big-endian imm16. webCenREE rrfetchw reads $src (low bit ignored) and the
// literal, and writes $dst. ADD is dst = src + imm. Phire `50 54 ff ec` is
// ADD X, X, 0xffec. The even/even register form is DoubleReg16, so the two
// encodings do not alias. Condition codes change and are not modeled yet.
let hasSideEffects = 0, mayLoad = 0, mayStore = 0 in
class DoubleRegImm32<bits<8> opcode, string opstr>
      : CenturionInst32<(outs GPR:$dst), (ins GPR:$src, abs16:$imm),
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

//===----------------------------------------------------------------------===//
// Transfers
//===----------------------------------------------------------------------===//

let hasSideEffects = 0, mayLoad = 0, mayStore = 0 in
def XFR : DoubleReg16<0x55, "XFR">;     // Transfer
let hasSideEffects = 0, mayLoad = 0, mayStore = 0 in
def XFRB: DoubleReg16_B<0x45, "XFRB">;  // Transfer (Byte mode)

// XFR literal ignores the source register. Phire writes the destination
// into both nibbles and sets the source nibble's low bit: `55 98 f2 00`
// is mov Z, 0xf200. $dst is an output so the assembler and instruction
// selection share this record. The pattern is in CPU6InstrPatterns.td.
let hasSideEffects = 0, mayLoad = 0, mayStore = 0, isMoveImm = 1,
    isAsCheapAsAMove = 1, isReMaterializable = 1 in
class XFRImm32
      : CenturionInst32<(outs GPR:$dst), (ins abs16:$imm),
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

//===----------------------------------------------------------------------===//
// Multiply and divide
//===----------------------------------------------------------------------===//

// webCenREE decodes MUL and DIV as OPM.RRX, which throws, so which registers
// they read and write (a remainder or a 32-bit product) is not settled. The
// operand lists stay as the assembler needs them and nothing selects them.
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

//===----------------------------------------------------------------------===//
// One-byte register forms
//===----------------------------------------------------------------------===//

// Instruction: <|opcode|>
// opcode = 8 bits
//------------------------------------------------------------//
// This is the same as Control near the top of the file, but I want a new name for it to be pretty
class ImplicitReg<bits<8> opcode, string opstr>
        : CenturionInst8<(outs), (ins), opstr> {
    let Inst{7-0} = opcode;
}

// webCenREE sr: REG.A, dr: the named register; the byte forms use the low
// bytes. AAB is B = A + B, SAB is B = A - B (same src - dst order as SUB),
// NAB is B = A & B, and XAx copies A into x. XAS/XASB write the stack
// pointer (or its low byte).
let Uses = [rA, rB], Defs = [rB], hasSideEffects = 0 in
def AAB : ImplicitReg<0x58, "AAB">;     // Add A Register and B Register
let Uses = [rAL, rBL], Defs = [rBL], hasSideEffects = 0 in
def AABB: ImplicitReg<0x48, "AABB">;    // Add A Register and B Register (Byte mode)
let Uses = [rA, rB], Defs = [rB], hasSideEffects = 0 in
def SAB : ImplicitReg<0x59, "SAB">;     // Subtract A Register and B Register
let Uses = [rAL, rBL], Defs = [rBL], hasSideEffects = 0 in
def SABB: ImplicitReg<0x49, "SABB">;    // Subtract A Register and B Register (Byte mode)
let Uses = [rA, rB], Defs = [rB], hasSideEffects = 0 in
def NAB : ImplicitReg<0x5A, "NAB">;     // AND A Register and B Register
let Uses = [rAL, rBL], Defs = [rBL], hasSideEffects = 0 in
def NABB: ImplicitReg<0x4A, "NABB">;    // AND A Register and B Register (Byte mode)
let Uses = [rA], Defs = [rX], hasSideEffects = 0 in
def XAX : ImplicitReg<0x5B, "XAX">;     // Transfer A Register to X Register
let Uses = [rAL], Defs = [rXL], hasSideEffects = 0 in
def XAXB: ImplicitReg<0x4B, "XAXB">;    // Transfer A Register to X Register (Byte mode)
let Uses = [rA], Defs = [rY], hasSideEffects = 0 in
def XAY : ImplicitReg<0x5C, "XAY">;     // Transfer A Register to Y Register
let Uses = [rAL], Defs = [rYL], hasSideEffects = 0 in
def XAYB: ImplicitReg<0x4C, "XAYB">;    // Transfer A Register to Y Register (Byte mode)
let Uses = [rA], Defs = [rB], hasSideEffects = 0 in
def XAB : ImplicitReg<0x5D, "XAB">;     // Transfer A Register to B Register
let Uses = [rAL], Defs = [rBL], hasSideEffects = 0 in
def XABB: ImplicitReg<0x4D, "XABB">;    // Transfer A Register to B Register (Byte mode)
let Uses = [rA], Defs = [rZ], hasSideEffects = 0 in
def XAZ : ImplicitReg<0x5E, "XAZ">;     // Transfer A Register to Z Register
let Uses = [rAL], Defs = [rZL], hasSideEffects = 0 in
def XAZB: ImplicitReg<0x4E, "XAZB">;    // Transfer A Register to Z Register (Byte mode)
let Uses = [rA], Defs = [rS], hasSideEffects = 0 in
def XAS : ImplicitReg<0x5F, "XAS">;     // Transfer A Register to S Register
let Uses = [rAL], Defs = [rSL], hasSideEffects = 0 in
def XASB: ImplicitReg<0x4F, "XASB">;    // Transfer A Register to S Register (Byte mode)

//===----------------------------------------------------------------------===//
// Compression
//===----------------------------------------------------------------------===//

// The AsmPrinter swaps in the one-byte implicit form once registers are
// known (compressInst). Each pair has the same result and the same webCenREE
// flag set, so nothing that reads the flags can tell them apart. ADD A,A,1
// is not INA: ADD updates link, INA does not. Hand-written assembly is
// emitted as written.
let isCompressOnly = true in {
def : CompressPat<(INRB rAL, 0), (INAB)>;
def : CompressPat<(DCRB rAL, 0), (DCAB)>;
def : CompressPat<(CLRB rAL, 0), (CLAB)>;
def : CompressPat<(IVRB rAL), (IVAB)>;
def : CompressPat<(SLRB rAL, 0), (SLAB)>;
def : CompressPat<(ADDB rBL, rAL), (AABB)>;
def : CompressPat<(SUBB rBL, rAL), (SABB)>;
def : CompressPat<(ANDB rBL, rAL), (NABB)>;
def : CompressPat<(INR rA, 0), (INA)>;
def : CompressPat<(DCR rA, 0), (DCA)>;
def : CompressPat<(CLR rA, 0), (CLA)>;
def : CompressPat<(IVR rA, 0), (IVA)>;
def : CompressPat<(SLR rA, 0), (SLA)>;
def : CompressPat<(INR rX, 0), (INX)>;
def : CompressPat<(DCR rX, 0), (DCX)>;
def : CompressPat<(ADD rB, rA), (AAB)>;
def : CompressPat<(SUB rB, rA), (SAB)>;
def : CompressPat<(AND rB, rA), (NAB)>;
def : CompressPat<(XFRB rXL, rAL), (XAXB)>;
def : CompressPat<(XFRB rYL, rAL), (XAYB)>;
def : CompressPat<(XFRB rBL, rAL), (XABB)>;
def : CompressPat<(XFRB rZL, rAL), (XAZB)>;
def : CompressPat<(XFRB rSL, rAL), (XASB)>;
def : CompressPat<(XFR rX, rA), (XAX)>;
def : CompressPat<(XFR rY, rA), (XAY)>;
def : CompressPat<(XFR rB, rA), (XAB)>;
def : CompressPat<(XFR rZ, rA), (XAZ)>;
def : CompressPat<(XFR rS, rA), (XAS)>;
}

//===----------------------------------------------------------------------===//
// Stack
//===----------------------------------------------------------------------===//

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

//===----------------------------------------------------------------------===//
// Memory
//===----------------------------------------------------------------------===//

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
// Two byte m prime flavor of opcode. The index register is a word register in
// byte mode too: webCenREE lea_mod reads it with get_rw, and its disassembler
// prints an odd nibble as <invalid>. LDAB (X),21 loads one byte at X+21.
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

// Loads and stores through A and B. Byte: LDAB 0x8x and STAB 0xAx move AL,
// LDBB 0xCx and STBB 0xEx move BL. Word: LDA 0x9x, STA 0xBx, LDB 0xDx and
// STB 0xFx move A and B (webCenREE dr/sr: REG.AL, REG.BL, REG.A, REG.B). The
// data register is fixed, so it is an implicit def or use rather than an
// operand.
//
// The literal form is the opcode and the value: one byte for the byte ops, a
// big-endian word for the word ops. The load reads it; the store writes it,
// patching the instruction stream.
//
// Modes 1, 2, 9, A, 5 and 6, D and E post-increment or pre-decrement the
// index register (by the operand size, or by two when indirect: the pointer
// is a word), so it is also an output tied to the index. Modes with bit 2
// set (4, 5, 6, C, D, E) and the ((ptr)) forms read a pointer first, so a
// store through them loads as well.
class DataMemop<string name, int opc, Register reg, bit isload, bit isword> {
    string Name = name;
    int Opcode = opc;
    Register Reg = reg;
    bit IsLoad = isload;
    bit IsWord = isword;
}
class MemRef16IndexWB<bits<4> opcode, bits<4> m_prime, string opstr, string argstr>
      : Memory16Index<opcode, m_prime, (outs GPR:$wb), (ins GPR:$arg), opstr, argstr> {
    let Constraints = "$wb = $arg";
}
class MemRef24IndexWB<bits<4> opcode, bits<4> m_prime, string opstr, string argstr>
      : Memory24Index<opcode, m_prime, (outs GPR:$wb), (ins GPR:$r, i8imm:$arg),
                      opstr, argstr> {
    let Constraints = "$wb = $r";
}
// 0x88-0x8F style: the address is the named word register.
class RegDirect<string sfx, Register reg, bits<4> m> {
    string Sfx = sfx;
    Register Reg = reg;
    bits<4> M = m;
}

foreach OP = [
            DataMemop<"LDAB", 0x8, rAL, 1, 0>,
            DataMemop<"LDA",  0x9, rA,  1, 1>,
            DataMemop<"STAB", 0xA, rAL, 0, 0>,
            DataMemop<"STA",  0xB, rA,  0, 1>,
            DataMemop<"LDBB", 0xC, rBL, 1, 0>,
            DataMemop<"LDB",  0xD, rB,  1, 1>,
            DataMemop<"STBB", 0xE, rBL, 0, 0>,
            DataMemop<"STB",  0xF, rB,  0, 1>
        ] in {
  defvar DataDefs = !if(OP.IsLoad, [OP.Reg], []<Register>);
  defvar DataUses = !if(OP.IsLoad, []<Register>, [OP.Reg]);
  defvar IsStore = !not(OP.IsLoad);
  let Defs = DataDefs, Uses = DataUses, hasSideEffects = 0 in {
    let mayLoad = 0, mayStore = IsStore in {
      if OP.IsWord then
        def OP.Name#_0 : MemRef24<OP.Opcode, 0x0, abs16, OP.Name>;                   //literal
      else
        def OP.Name#_0 : MemRef16<OP.Opcode, 0x0, i8imm, OP.Name>;                   //literal
    }

    let mayLoad = OP.IsLoad, mayStore = IsStore in {
      def OP.Name#_1 : MemRef24<OP.Opcode, 0x1, abs16, OP.Name, "(${arg})">;         //(ptr)
      def OP.Name#_3 : MemRef16<OP.Opcode, 0x3, pcoff8, OP.Name, "(PC),$arg">;       //(offset)
      def OP.Name#_5_0: MemRef16Index<OP.Opcode, 0x0, GPR, OP.Name, "(${arg})">;     //(r)
      def OP.Name#_5_1: MemRef16IndexWB<OP.Opcode, 0x1, OP.Name#"_I", "(${arg})">;   //I (r)
      def OP.Name#_5_2: MemRef16IndexWB<OP.Opcode, 0x2, OP.Name#"_D", "(${arg})">;   //D (r)
      def OP.Name#_5_8: MemRef24Index<OP.Opcode, 0x8, GPR, OP.Name, "(${r}),$arg">;  //(r),disp
      def OP.Name#_5_9: MemRef24IndexWB<OP.Opcode, 0x9, OP.Name#"_I", "(${r}),$arg">; //I (r),disp
      def OP.Name#_5_A: MemRef24IndexWB<OP.Opcode, 0xA, OP.Name#"_D", "(${r}),$arg">; //D (r),disp
    }

    let mayLoad = 1, mayStore = IsStore in {
      def OP.Name#_2 : MemRef24<OP.Opcode, 0x2, abs16, OP.Name, "((${arg}))">;       //((ptr))
      def OP.Name#_4 : MemRef16<OP.Opcode, 0x4, pcoff8, OP.Name, "((PC),${arg})">;   //((offset))
      def OP.Name#_5_4: MemRef16Index<OP.Opcode, 0x4, GPR, OP.Name, "((${arg}))">;   //((r))
      def OP.Name#_5_5: MemRef16IndexWB<OP.Opcode, 0x5, OP.Name#"_I", "((${arg}))">; //I ((r))
      def OP.Name#_5_6: MemRef16IndexWB<OP.Opcode, 0x6, OP.Name#"_D", "((${arg}))">; //D ((r))
      def OP.Name#_5_C: MemRef24Index<OP.Opcode, 0xC, GPR, OP.Name#"_?", "(${r}),$arg">; //((r)),disp
      def OP.Name#_5_D: MemRef24IndexWB<OP.Opcode, 0xD, OP.Name#"_I", "((${r})),$arg">; //I ((r)),disp
      def OP.Name#_5_E: MemRef24IndexWB<OP.Opcode, 0xE, OP.Name#"_D", "((${r})),$arg">; //D ((r)),disp
    }
  }

  foreach R = [RegDirect<"A", rA, 0x8>, RegDirect<"B", rB, 0x9>,
               RegDirect<"X", rX, 0xA>, RegDirect<"Y", rY, 0xB>,
               RegDirect<"Z", rZ, 0xC>, RegDirect<"S", rS, 0xD>,
               RegDirect<"C", rC, 0xE>, RegDirect<"P", rP, 0xF>] in
    let Defs = DataDefs, Uses = !listconcat(DataUses, [R.Reg]),
        hasSideEffects = 0, mayLoad = OP.IsLoad, mayStore = IsStore in
    def OP.Name#_#R.Sfx : MemRef8<OP.Opcode, R.M, OP.Name#"_"#R.Sfx>;
}

// LDX 0x6x and STX 0x6x+8 move X (webCenREE dr/sr: REG.X) with the same
// modes and operand rules as LDA/STA, minus register-direct: 0x66 is SVC and
// 0x67 is the MEM. group.
class MemRef16IndexStrangeWB<bits<5> opcode, bits<4> m_prime, string opstr, string argstr>
      : Memory16IndexStrange<opcode, m_prime, (outs GPR:$wb), (ins GPR:$arg), opstr, argstr> {
    let Constraints = "$wb = $arg";
}
class MemRef24IndexStrangeWB<bits<5> opcode, bits<4> m_prime, string opstr, string argstr>
      : Memory24IndexStrange<opcode, m_prime, (outs GPR:$wb), (ins GPR:$r, i8imm:$arg),
                             opstr, argstr> {
    let Constraints = "$wb = $r";
}
foreach OP = [
            DataMemop<"LDX", 0b01100, rX, 1, 1>,
            DataMemop<"STX", 0b01101, rX, 0, 1>
        ] in {
  defvar IsStore = !not(OP.IsLoad);
  let Defs = !if(OP.IsLoad, [OP.Reg], []<Register>),
      Uses = !if(OP.IsLoad, []<Register>, [OP.Reg]), hasSideEffects = 0 in {
    let mayLoad = 0, mayStore = IsStore in
    def OP.Name#_0 : MemRef24Strange<OP.Opcode, 0b000, abs16, OP.Name>;
    let mayLoad = OP.IsLoad, mayStore = IsStore in {
      def OP.Name#_1 : MemRef24Strange<OP.Opcode, 0b001, abs16, OP.Name, "(${arg})">;
      def OP.Name#_3 : MemRef16Strange<OP.Opcode, 0b011, pcoff8, OP.Name, "(PC),$arg">;
      def OP.Name#_5_0: MemRef16IndexStrange<OP.Opcode, 0x0, GPR, OP.Name, "(${arg})">;
      def OP.Name#_5_1: MemRef16IndexStrangeWB<OP.Opcode, 0x1, OP.Name#"_I", "(${arg})">;
      def OP.Name#_5_2: MemRef16IndexStrangeWB<OP.Opcode, 0x2, OP.Name#"_D", "(${arg})">;
      def OP.Name#_5_8: MemRef24IndexStrange<OP.Opcode, 0x8, GPR, OP.Name, "(${r}),$arg">;
      def OP.Name#_5_9: MemRef24IndexStrangeWB<OP.Opcode, 0x9, OP.Name#"_I", "(${r}),$arg">;
      def OP.Name#_5_A: MemRef24IndexStrangeWB<OP.Opcode, 0xA, OP.Name#"_D", "(${r}),$arg">;
    }
    let mayLoad = 1, mayStore = IsStore in {
      def OP.Name#_2 : MemRef24Strange<OP.Opcode, 0b010, abs16, OP.Name, "((${arg}))">;
      def OP.Name#_4 : MemRef16Strange<OP.Opcode, 0b100, pcoff8, OP.Name, "((PC),${arg})">;
      def OP.Name#_5_4: MemRef16IndexStrange<OP.Opcode, 0x4, GPR, OP.Name, "((${arg}))">;
      def OP.Name#_5_5: MemRef16IndexStrangeWB<OP.Opcode, 0x5, OP.Name#"_I", "((${arg}))">;
      def OP.Name#_5_6: MemRef16IndexStrangeWB<OP.Opcode, 0x6, OP.Name#"_D", "((${arg}))">;
      def OP.Name#_5_C: MemRef24IndexStrange<OP.Opcode, 0xC, GPR, OP.Name#"_?", "(${r}),${arg}">;
      def OP.Name#_5_D: MemRef24IndexStrangeWB<OP.Opcode, 0xD, OP.Name#"_I", "((${r})),$arg">;
      def OP.Name#_5_E: MemRef24IndexStrangeWB<OP.Opcode, 0xE, OP.Name#"_D", "((${r})),$arg">;
    }
  }
}

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
      : CenturionInst32<(outs), (ins GPR:$dst, abs16:$imm),
        "STR", "$dst,$imm"> {
  bits<4> dst;
  bits<16> imm;
  let Inst{31-24} = 214;
  let Inst{23-20} = 1;
  let Inst{19-16} = dst;
  let Inst{15-0} = imm;
}
def STRReg : STRReg16;
def STRLit : STRLit32;

//===----------------------------------------------------------------------===//
// Jumps and calls
//===----------------------------------------------------------------------===//

// JMP and JSR have no literal form. Direct is opcode 0x79/0x71 plus a
// big-endian address: webCenREE lea_dir reads it with pcfetchw, then f_jsr
// pushes X and sets X to the PC it just advanced past that word. RSR copies
// X into the PC and pops the saved X, so from the caller X is unchanged.
// X is callee-saved, which is that fact: listing it as a use here would
// demand a defined X even in a function that never touches it. S is a use
// because the push reads it. The call's register mask says which other
// registers the callee gives back.
multiclass DirJump<bits<5> opcode> {
  def _1 : MemRef24Strange<opcode, 0b001, abs16, NAME, "(${arg})">;
  def _2 : MemRef24Strange<opcode, 0b010, abs16, NAME, "((${arg}))">;
  def _3 : MemRef16Strange<opcode, 0b011, pcoff8, NAME, "(PC),$arg">;
  def _4 : MemRef16Strange<opcode, 0b100, pcoff8, NAME, "((PC),${arg})">;
  def _5_0: MemRef16IndexStrange<opcode, 0x0, GPR, NAME, "(${arg})">;
  def _5_1: MemRef16IndexStrange<opcode, 0x1, GPR, NAME#"_I", "(${arg})">;
  def _5_2: MemRef16IndexStrange<opcode, 0x2, GPR, NAME#"_D", "(${arg})">;
  // 3 is not used
  def _5_4: MemRef16IndexStrange<opcode, 0x4, GPR, NAME, "((${arg}))">;
  def _5_5: MemRef16IndexStrange<opcode, 0x5, GPR, NAME#"_I", "((${arg}))">;
  def _5_6: MemRef16IndexStrange<opcode, 0x6, GPR, NAME#"_D", "((${arg}))">;
  // 7 is not used
  def _5_8: MemRef24IndexStrange<opcode, 0x8, GPR, NAME, "(${r}),$arg">;
  def _5_9: MemRef24IndexStrange<opcode, 0x9, GPR, NAME#"_I", "(${r}),$arg">;
  def _5_A: MemRef24IndexStrange<opcode, 0xA, GPR, NAME#"_D", "(${r}),$arg">;
  // B is not used
  def _5_C: MemRef24IndexStrange<opcode, 0xC, GPR, NAME#"_?", "(${r}),${arg}">;
  def _5_D: MemRef24IndexStrange<opcode, 0xD, GPR, NAME#"_I", "((${r})),$arg">;
  def _5_E: MemRef24IndexStrange<opcode, 0xE, GPR, NAME#"_D", "((${r})),$arg">;
}
defm JMP : DirJump<0b01110>;
let isCall = 1, hasSideEffects = 1, Uses = [rS] in
defm JSR : DirJump<0b01111>;

// CALLSEQ_START/END. The outgoing area is reserved in the prologue, so
// CPU6FrameLowering::eliminateCallFramePseudoInstr deletes these.
let isPseudo = 1, isCodeGenOnly = 1, hasSideEffects = 1, Uses = [rS],
    Defs = [rS] in {
def ADJCALLSTACKDOWN : CenturionInst<(outs), (ins i16imm:$amt1, i16imm:$amt2),
                                    "#ADJCALLSTACKDOWN", "$amt1, $amt2">;
def ADJCALLSTACKUP   : CenturionInst<(outs), (ins i16imm:$amt1, i16imm:$amt2),
                                    "#ADJCALLSTACKUP", "$amt1, $amt2">;
}

//===----------------------------------------------------------------------===//
// Block move
//===----------------------------------------------------------------------===//

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

//===----------------------------------------------------------------------===//
// Bignum
//===----------------------------------------------------------------------===//

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

//===----------------------------------------------------------------------===//
// Page table
//===----------------------------------------------------------------------===//

//---------- CPU6 2E instructions-----//
// Instruction: <|  opcode   |  sel | M | N |>
//               |  byte 1   |     byte 2   | 
// opcode: 1 byte
// sel: byte 2 high nibble
// M and N: byte 2 low nibble, 2 bits each

// 0x2E page-table ops. The wiki form is `2E ssssmmnn`
// and load7 uses both 5-byte and 6-byte tails (`2e 1c 78 80 d3`,
// `2e 30 a1 fc a0 fb`). The mode bits change the tail width.

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

//===----------------------------------------------------------------------===//
// DMA
//===----------------------------------------------------------------------===//

// ------------------
// Opcode byte is 0x2F. Phire's WIPL encodes these as 2F 00/02/04/06.
// Second byte is | r | s | (register nibble, then selector). The wiki
// form text says `2e rs`. 0x2E is the page-table group above.
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

//===----------------------------------------------------------------------===//
// Interrupt level and MMIO
//===----------------------------------------------------------------------===//

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

//===----------------------------------------------------------------------===//
// Status
//===----------------------------------------------------------------------===//

class TwoArg24<bits<8> opcode, string opstr, string argstr="$arg1,$arg2">
      : DoubleArg24<opcode, (outs), (ins i8imm: $arg1, i8imm: $arg2), opstr, argstr> { }

def LST: TwoArg24<0x6E, "LST", "(${arg1}),(${arg2})">;
def SST: TwoArg24<0x6F, "SST", "(${arg1}),(${arg2})">;
