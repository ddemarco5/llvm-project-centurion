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
// OtherVT lets selection put a basic block here.
def BRTargetAsmOperand : AsmOperandClass {
    let Name = "BRTarget";
    let RenderMethod = "addImmOperands";
    let DiagnosticType = "InvalidBRTarget";
}
def brtarget : Operand<OtherVT> {
    let ParserMatchClass = BRTargetAsmOperand;
    let EncoderMethod = "getPCRel8OpValue";
    let DecoderMethod = "decodeSImmOperand<8>";
}
// (PC)+b accepts the same signed range and also the unsigned byte the
// numeric tests already use (LDA (PC),205 is the bit pattern of -51).
// OtherVT for the same reason as brtarget: JMP (PC),b is the short jump.
def PCOff8AsmOperand : AsmOperandClass {
    let Name = "PCOff8";
    let RenderMethod = "addImmOperands";
    let DiagnosticType = "InvalidPCOff8";
}
def pcoff8 : Operand<OtherVT> {
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
// A 16-bit absolute address word. Tail is how many bytes of the instruction
// follow the word, which is where a symbol's relocation has to point. Most
// instructions end in the word, so Tail is 0 and the relocation sits at
// Size - 2. A bignum operand pair puts the second operand after the first.
class Abs16Operand<int tail> : Operand<i16> {
    let ParserMatchClass = Abs16AsmOperand;
    let EncoderMethod = "getAbs16OpValue<" # tail # ">";
}
def abs16 : Abs16Operand<0>;
def abs16_t1 : Abs16Operand<1>;
def abs16_t2 : Abs16Operand<2>;

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
// SF and RF write Fault and leave the other three bits alone.
let Defs = [rF] in {
def SF : Control<0x02, "SF">;       // Set Fault
def RF : Control<0x03, "RF">;       // Reset Fault
}
def EI : Control<0x04, "EI">;       // Enable Interrupt System
def DI : Control<0x05, "DI">;       // Disable Interrupt System
// SL and RL write Link. CL reads it as well, because it flips the bit.
let Defs = [rL] in {
def SL : Control<0x06, "SL">;       // Set Link
def RL : Control<0x07, "RL">;       // Reset Link
}
let Uses = [rL], Defs = [rL] in
def CL : Control<0x08, "CL">;       // Complement Link
// isReturn marks the function exit. isTerminator and isBarrier tell the
// machine verifier that control does not fall out of the block. The
// CPU6retglue pattern in CPU6InstrPatterns.td selects this opcode.
let isReturn = 1, isTerminator = 1, isBarrier = 1 in
def RSR : Control<0x09, "RSR">;     // Return from Subroutine
// RI is marked FLMV: returning from an interrupt restores the flags.
let Defs = [rF, rL, rM, rV] in
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

// webCenREE f_branch tests one bit, or Minus|Value for BGZ and BLE.
// BGZ is taken when neither bit is set. BLE is taken when either is.
let isBranch = 1, isTerminator = 1 in {
let Uses = [rL] in {
def BL : Branch<0x10, "BL">;    // Branch if Link Set
def BNL: Branch<0x11, "BNL">;   // Branch if Link Not Set
}
let Uses = [rF] in {
def BF : Branch<0x12, "BF">;    // Branch if Fault Set
def BNF: Branch<0x13, "BNF">;    // Branch if Fault Not Set
}
let Uses = [rV] in {
def BZ : Branch<0x14, "BZ">;    // Branch if Equal to Zero
def BNZ: Branch<0x15, "BNZ">;   // Branch if Not Equal to Zero
}
let Uses = [rM] in {
def BM : Branch<0x16, "BM">;    // Branch if Minus Set
def BP : Branch<0x17, "BP">;    // Branch on Puls
}
let Uses = [rM, rV] in {
def BGZ: Branch<0x18, "BGZ">;   // Branch if Greater than Zero
def BLE: Branch<0x19, "BLE">;   // Branch if Less Than or Equal to Zero
}
def BS1: Branch<0x1A, "BS1">;   // Branch if Sense Switch 1 Set
def BS2: Branch<0x1B, "BS2">;   // Branch if Sense Switch 2 Set
def BS3: Branch<0x1C, "BS3">;   // Branch if Sense Switch 3 Set
def BS4: Branch<0x1D, "BS4">;   // Branch if Sense Switch 4 Set
def BI: Branch<0x1E, "BI">;   // Branch on interrupts enabled
def BCK: Branch<0x1F, "BCK">;   // Branch on AH at interrupt level 1 bit 0 set (probably)
}
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

// CLR has no bias: CLR r,n writes n (0-15), as CLRB does. It also writes
// all four flags (AOP.CLR), so it cannot be rematerialized: a second copy
// would clobber flags the first one produced.
let hasSideEffects = 0, mayLoad = 0, mayStore = 0, isMoveImm = 1,
    isAsCheapAsAMove = 1 in
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
// count field. Same flag write as CLR, so not rematerializable.
let hasSideEffects = 0, mayLoad = 0, mayStore = 0, isMoveImm = 1,
    isAsCheapAsAMove = 1 in
class SingleReg16W_B<bits<8> opcode, string opstr>
      : SingleArg16HL<opcode, (outs GPRB:$arghnibble), (ins uimm4:$arglnibble),
                      opstr, "$arghnibble,$arglnibble"> { }

let Constraints = "$arghnibble = $src", hasSideEffects = 0, mayLoad = 0,
    mayStore = 0 in
class SingleReg16H_B<bits<8> opcode, string opstr>
      : SingleArg16H<opcode, (outs GPRB:$arghnibble), (ins GPRB:$src),
                     opstr, "$arghnibble"> { }

// AOP.ADD and AOP.SUB go through flags_a*vmfl, which replaces all four
// bits. The fl label on INR says ArithFMV, but the handler does not
// consult it.
let Defs = [rF, rL, rM, rV] in {
def INR : SingleReg16<0x30, "INR">;      // Increment Register
def INRB: SingleReg16_B<0x20, "INRB">;   // Increment Register (Byte mode)
def DCR : SingleReg16<0x31, "DCR">;      // Decrement Register
def DCRB: SingleReg16_B<0x21, "DCRB">;   // Decrement Register (Byte mode)
}
// The low nibble is the value, not forced to 0. load7 `32 01` is
// clr A, #1 and `32 02` is clr A, #2. f1 `22 32` is clr BL, #2.
// Phire prints that nibble as the count; the encoded nibble is the value.
// CLR writes Fault and Link as 0 and sets Minus and Value from the result.
let Defs = [rF, rL, rM, rV] in {
def CLR : SingleReg16W<0x32, "CLR">;     // Clear Register
def CLRB: SingleReg16W_B<0x22, "CLRB">;  // Clear Register (Byte mode)
}
// NOT only updates Minus and Value (flags_*vm keeps Fault and Link).
let Defs = [rM, rV] in {
def IVR : SingleReg16<0x33, "IVR">;      // Invert Register
def IVRB: SingleReg16H_B<0x23, "IVRB">;  // Invert Register (Byte mode)
}
// Shifts compute a new Fault and Link from the data and write all four bits.
// They do not read the old flags. SLR shifts left and SRR shifts right
// arithmetically; the count nibble n means a shift of n + 1.
let Defs = [rF, rL, rM, rV] in {
def SRR : SingleReg16<0x34, "SRR">;      // Shift Register Right
def SRRB: SingleReg16_B<0x24, "SRRB">;   // Shift Register Right (Byte mode)
def SLR : SingleReg16<0x35, "SLR">;      // Shift Register Left
def SLRB: SingleReg16_B<0x25, "SLRB">;   // Shift Register Left (Byte mode)
}
// Rotate through Link, count nibble n meaning n + 1 bits. The bit shifted
// out of the register becomes the new Link, and the old Link is shifted in,
// so this is a 17-bit (or 9-bit) rotate: a longer count brings those bits
// back. With Link clear, a count of 0 is a logical shift of one. The diag
// ROM checks that an RR of 0xFF then leaves Minus clear, which is 0x7F.
// CenREE's live interpreter has no handler. Its dead 0x36 path is the
// one-bit case; the dead 0x26 loop refills from the original Link and does
// not match that diag.
let Uses = [rL], Defs = [rF, rL, rM, rV] in {
def RRR : SingleReg16<0x36, "RRR">;      // Rotate Register Right
def RRRB: SingleReg16_B<0x26, "RRRB">;   // Rotate Register Right (Byte mode)
def RLR : SingleReg16<0x37, "RLR">;      // Rotate Register Left
def RLRB: SingleReg16_B<0x27, "RLRB">;   // Rotate Register Left (Byte mode)
}

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
let Defs = [rF, rL, rM, rV] in {
def INRmem : CountMem32<0x30, "INR">;
def INRidx : CountIdx32<0x30, "INR">;
def DCRmem : CountMem32<0x31, "DCR">;
def DCRidx : CountIdx32<0x31, "DCR">;
}
let mayLoad = 0, Defs = [rF, rL, rM, rV] in {
def CLRmem : CountMem32<0x32, "CLR">;
def CLRidx : CountIdx32<0x32, "CLR">;
}
let Defs = [rM, rV] in {
def IVRmem : CountMem32<0x33, "IVR">;
def IVRidx : CountIdx32<0x33, "IVR">;
}
let Defs = [rF, rL, rM, rV] in {
def SRRmem : CountMem32<0x34, "SRR">;
def SRRidx : CountIdx32<0x34, "SRR">;
}

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
let Uses = [rA], Defs = [rA, rF, rL, rM, rV], hasSideEffects = 0 in
def INA : Implicit<0x38, "INA">;        // Increment Accumulator by 1
let Uses = [rAL], Defs = [rAL, rF, rL, rM, rV], hasSideEffects = 0 in
def INAB: Implicit<0x28, "INAB">;       // Increment Accumulator by 1 (Byte mode)
let Uses = [rA], Defs = [rA, rF, rL, rM, rV], hasSideEffects = 0 in
def DCA : Implicit<0x39, "DCA">;        // Decrement Accumulator by 1
let Uses = [rAL], Defs = [rAL, rF, rL, rM, rV], hasSideEffects = 0 in
def DCAB: Implicit<0x29, "DCAB">;       // Decrement Accumulator by 1 (Byte mode)
let Defs = [rA, rF, rL, rM, rV], hasSideEffects = 0 in
def CLA : Implicit<0x3A, "CLA">;        // Clear Accumulator
let Defs = [rAL, rF, rL, rM, rV], hasSideEffects = 0 in
def CLAB: Implicit<0x2A, "CLAB">;       // Clear Accumulator (Byte mode)
let Uses = [rA], Defs = [rA, rM, rV], hasSideEffects = 0 in
def IVA : Implicit<0x3B, "IVA">;        // Invert Accumulator
let Uses = [rAL], Defs = [rAL, rM, rV], hasSideEffects = 0 in
def IVAB: Implicit<0x2B, "IVAB">;       // Invert Accumulator (Byte mode)
let Uses = [rA], Defs = [rA, rF, rL, rM, rV], hasSideEffects = 0 in
def SRA : Implicit<0x3C, "SRA">;        // Shift Accumulator Right
let Uses = [rAL], Defs = [rAL, rF, rL, rM, rV], hasSideEffects = 0 in
def SRAB: Implicit<0x2C, "SRAB">;       // Shift Accumulator Right (Byte mode)
let Uses = [rA], Defs = [rA, rF, rL, rM, rV], hasSideEffects = 0 in
def SLA : Implicit<0x3D, "SLA">;        // Shift Accumulator Left
let Uses = [rAL], Defs = [rAL, rF, rL, rM, rV], hasSideEffects = 0 in
def SLAB: Implicit<0x2D, "SLAB">;       // Shift Accumulator Left (Byte mode)
let Uses = [rX], Defs = [rX, rF, rL, rM, rV], hasSideEffects = 0 in {
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
// ADD and SUB replace all four flags (flags_a*vmfl). AND, OR and XOR do
// too: flags_n*vmfl clears Link and sets Fault from a sign change, even
// though the fl label on those opcodes says MV.
let Defs = [rF, rL, rM, rV], isCommutable = 1 in {
def ADD : DoubleReg16RMW<0x50, "ADD">;     // Add
def ADDB: DoubleReg16_BRMW<0x40, "ADDB">;  // Add (Byte mode)
}
let Defs = [rF, rL, rM, rV] in {
def SUB : DoubleReg16RMW<0x51, "SUB">;     // Subtract
def SUBB: DoubleReg16_BRMW<0x41, "SUBB">;  // Subtract (Byte mode)
}
let Defs = [rF, rL, rM, rV], isCommutable = 1 in {
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
// encodings do not alias. The literal forms write the same flags as the
// register forms.
let hasSideEffects = 0, mayLoad = 0, mayStore = 0, Defs = [rF, rL, rM, rV] in
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

// XFR sets Minus and Value from the value moved and leaves Fault and Link.
let hasSideEffects = 0, mayLoad = 0, mayStore = 0, Defs = [rM, rV] in
def XFR : DoubleReg16<0x55, "XFR">;     // Transfer
let hasSideEffects = 0, mayLoad = 0, mayStore = 0, Defs = [rM, rV] in
def XFRB: DoubleReg16_B<0x45, "XFRB">;  // Transfer (Byte mode)

// XFR literal ignores the source register. Phire writes the destination
// into both nibbles and sets the source nibble's low bit: `55 98 f2 00`
// is mov Z, 0xf200. $dst is an output so the assembler and instruction
// selection share this record. The pattern is in CPU6InstrPatterns.td.
// Same Minus/Value update as XFR. Not rematerializable: a second copy
// would clobber flags the first one produced.
let hasSideEffects = 0, mayLoad = 0, mayStore = 0, isMoveImm = 1,
    isAsCheapAsAMove = 1, Defs = [rM, rV] in
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
let hasSideEffects = 0, mayLoad = 1, mayStore = 0, Defs = [rM, rV] in
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

// Mode 1 of rrfetchw: high nibble even, low nibble odd, then a big-endian
// address. The low bit of each nibble is the mode. rrfetchw fetches the
// address word, loads the word at that address, and set_rw writes it to
// the low nibble (bit 0 ignored). XFR replaces that with the loaded word,
// so the high nibble is not a second operand. Both nibbles name the
// destination, matching STRmem (`d6 89 92 b7` stores Z; `55 89 92 b7`
// loads Z). The result is any word register, not only A.
let hasSideEffects = 0, mayLoad = 1, mayStore = 0, Defs = [rM, rV] in
class XFRAbs32
      : CenturionInst32<(outs GPR:$dst), (ins abs16:$addr),
                        "XFR", "(${addr}),$dst"> {
  bits<4> dst;
  bits<16> addr;
  let Inst{31-24} = 0x55;
  let Inst{23} = dst{3};
  let Inst{22} = dst{2};
  let Inst{21} = dst{1};
  let Inst{20} = 0;
  let Inst{19} = dst{3};
  let Inst{18} = dst{2};
  let Inst{17} = dst{1};
  let Inst{16} = 1;
  let Inst{15-0} = addr;
}
def XFRabs : XFRAbs32;

//===----------------------------------------------------------------------===//
// Multiply and divide
//===----------------------------------------------------------------------===//

// Register form is the two-address word ALU: both nibbles even, the
// destination is read and written, and all four flags are replaced
// (ArithFLMV). MUL src,dst is an unsigned 32-bit product of dst * src.
// webCenREE prints a pair when the destination nibble has bit 1 clear:
//   A:B, X:Y, Z:S, C:P — high 16 in the named register, low 16 in the next.
// B, Y, S, and P are written alone, and that register is the low 16.
// Z would clobber S and C would clobber P. The assembler still accepts
// every word register. An i16 product is the low half, so codegen uses
// MULlo / MULimmLo and only allocates B or Y as the destination.
// A widened multiply needs both halves. MULAB is that form with the
// destination fixed as A, so the low half is written to B. An i16 product
// is MULB, destination fixed as B, so only the low half is written. B and
// Y are the only registers that receive a low half, and they are also
// argument registers, so a MulLo class cannot be allocated while those
// arguments are still live.
// DIV uses the same pair write as MUL. The 32-bit result is the remainder
// in the high half and the quotient in the low half. A destination whose
// nibble has bit 1 clear (A, X, Z, C) leaves the remainder in that register
// and the quotient in the next one. B, Y, S, and P are written alone, and
// that register is the quotient. rem-O0's DIV B,X left i % 10 in X; treating
// X as the quotient made the reconstructed remainder i - (i % 10) * 10.
// An i16 quotient therefore uses DIVB / DIVimmLo, the same way an i16
// product uses MULB / MULimmLo. The register form still reads the dividend
// from the destination: DIVB is B = B / src. The literal form is
// three-address, like ADDimm: dst = src / imm.
let Defs = [rF, rL, rM, rV], isCommutable = 1 in
def MUL: DoubleReg16RMW<0x77, "MUL">;
let Defs = [rF, rL, rM, rV] in
def DIV: DoubleReg16RMW<0x78, "DIV">;
def MULimm : DoubleRegImm32<0x77, "MUL">;
def DIVimm : DoubleRegImm32<0x78, "DIV">;
// Same encoding as MUL. The tied destination is MulLo, so the register that
// holds the i16 result is the one the hardware fills with the low half.
let Constraints = "$arglnibble = $base", hasSideEffects = 0,
    mayLoad = 0, mayStore = 0 in
class DoubleReg16RMWLo<bits<8> opcode, string opstr>
      : SingleArg16HL<opcode, (outs MulLo:$arglnibble),
                      (ins GPR:$arghnibble, MulLo:$base),
                      opstr, "$arghnibble,$arglnibble"> { }
let Defs = [rF, rL, rM, rV], isCodeGenOnly = 1 in
def MULlo : DoubleReg16RMWLo<0x77, "MUL">;
// Same encoding as MUL with destination A. The operand in A is one factor
// and is overwritten with the high half. B receives the low half and is
// not read. The other factor is $src and may be A or B: both are read
// before either is written.
let Uses = [rA], Defs = [rA, rB, rF, rL, rM, rV], isCodeGenOnly = 1,
    hasSideEffects = 0, mayLoad = 0, mayStore = 0 in
def MULAB : CenturionInst16<(outs), (ins GPR:$src), "MUL", "$src,A"> {
  bits<4> src;
  let Inst{15-8} = 0x77;
  let Inst{7-4} = src;
  let Inst{3-0} = 0;
}
// Destination B. The nibble's low bit is set, so B is written with the low
// half and A is left alone. B is read as the other factor.
let Uses = [rB], Defs = [rB, rF, rL, rM, rV], isCodeGenOnly = 1,
    hasSideEffects = 0, mayLoad = 0, mayStore = 0 in
def MULB : CenturionInst16<(outs), (ins GPR:$src), "MUL", "$src,B"> {
  bits<4> src;
  let Inst{15-8} = 0x77;
  let Inst{7-4} = src;
  let Inst{3-0} = 2;
}
// Destination B. The nibble's low bit is set, so B is written with the
// quotient and A is left alone. B is read as the dividend.
let Uses = [rB], Defs = [rB, rF, rL, rM, rV], isCodeGenOnly = 1,
    hasSideEffects = 0, mayLoad = 0, mayStore = 0 in
def DIVB : CenturionInst16<(outs), (ins GPR:$src), "DIV", "$src,B"> {
  bits<4> src;
  let Inst{15-8} = 0x78;
  let Inst{7-4} = src;
  let Inst{3-0} = 2;
}
// Literal MUL, destination restricted the same way. dst = src * imm, and
// only B or Y are selected, so the written register is the low half.
let hasSideEffects = 0, mayLoad = 0, mayStore = 0, isCodeGenOnly = 1,
    Defs = [rF, rL, rM, rV] in
def MULimmLo : CenturionInst32<(outs MulLo:$dst), (ins GPR:$src, abs16:$imm),
                               "MUL", "$src,$dst,$imm"> {
  bits<4> src;
  bits<4> dst;
  bits<16> imm;
  let Inst{31-24} = 0x77;
  let Inst{23} = src{3};
  let Inst{22} = src{2};
  let Inst{21} = src{1};
  let Inst{20} = 1;
  let Inst{19-16} = dst;
  let Inst{15-0} = imm;
}
// Literal DIV, destination restricted the same way. dst = src / imm, and
// only B or Y are selected, so the written register is the quotient.
let hasSideEffects = 0, mayLoad = 0, mayStore = 0, isCodeGenOnly = 1,
    Defs = [rF, rL, rM, rV] in
def DIVimmLo : CenturionInst32<(outs MulLo:$dst), (ins GPR:$src, abs16:$imm),
                               "DIV", "$src,$dst,$imm"> {
  bits<4> src;
  bits<4> dst;
  bits<16> imm;
  let Inst{31-24} = 0x78;
  let Inst{23} = src{3};
  let Inst{22} = src{2};
  let Inst{21} = src{1};
  let Inst{20} = 1;
  let Inst{19-16} = dst;
  let Inst{15-0} = imm;
}
// Odd/odd is indexed, not another imm16. load7 `78 93 00 1c` is
// div B, [Z+0x001c], B. Wiki: dest <- dest / index(src). High nibble
// is the index with its low bit set. Low nibble is the destination
// with its low bit set. The tail is a big-endian displacement.
// The literal form keeps the destination even, so the two do not alias.
let Defs = [rF, rL, rM, rV] in
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
let Uses = [rA, rB], Defs = [rB, rF, rL, rM, rV], hasSideEffects = 0 in
def AAB : ImplicitReg<0x58, "AAB">;     // Add A Register and B Register
let Uses = [rAL, rBL], Defs = [rBL, rF, rL, rM, rV], hasSideEffects = 0 in
def AABB: ImplicitReg<0x48, "AABB">;    // Add A Register and B Register (Byte mode)
let Uses = [rA, rB], Defs = [rB, rF, rL, rM, rV], hasSideEffects = 0 in
def SAB : ImplicitReg<0x59, "SAB">;     // Subtract A Register and B Register
let Uses = [rAL, rBL], Defs = [rBL, rF, rL, rM, rV], hasSideEffects = 0 in
def SABB: ImplicitReg<0x49, "SABB">;    // Subtract A Register and B Register (Byte mode)
let Uses = [rA, rB], Defs = [rB, rF, rL, rM, rV], hasSideEffects = 0 in
def NAB : ImplicitReg<0x5A, "NAB">;     // AND A Register and B Register
let Uses = [rAL, rBL], Defs = [rBL, rF, rL, rM, rV], hasSideEffects = 0 in
def NABB: ImplicitReg<0x4A, "NABB">;    // AND A Register and B Register (Byte mode)
let Uses = [rA], Defs = [rX, rM, rV], hasSideEffects = 0 in
def XAX : ImplicitReg<0x5B, "XAX">;     // Transfer A Register to X Register
let Uses = [rAL], Defs = [rXL, rM, rV], hasSideEffects = 0 in
def XAXB: ImplicitReg<0x4B, "XAXB">;    // Transfer A Register to X Register (Byte mode)
let Uses = [rA], Defs = [rY, rM, rV], hasSideEffects = 0 in
def XAY : ImplicitReg<0x5C, "XAY">;     // Transfer A Register to Y Register
let Uses = [rAL], Defs = [rYL, rM, rV], hasSideEffects = 0 in
def XAYB: ImplicitReg<0x4C, "XAYB">;    // Transfer A Register to Y Register (Byte mode)
let Uses = [rA], Defs = [rB, rM, rV], hasSideEffects = 0 in
def XAB : ImplicitReg<0x5D, "XAB">;     // Transfer A Register to B Register
let Uses = [rAL], Defs = [rBL, rM, rV], hasSideEffects = 0 in
def XABB: ImplicitReg<0x4D, "XABB">;    // Transfer A Register to B Register (Byte mode)
let Uses = [rA], Defs = [rZ, rM, rV], hasSideEffects = 0 in
def XAZ : ImplicitReg<0x5E, "XAZ">;     // Transfer A Register to Z Register
let Uses = [rAL], Defs = [rZL, rM, rV], hasSideEffects = 0 in
def XAZB: ImplicitReg<0x4E, "XAZB">;    // Transfer A Register to Z Register (Byte mode)
let Uses = [rA], Defs = [rS, rM, rV], hasSideEffects = 0 in
def XAS : ImplicitReg<0x5F, "XAS">;     // Transfer A Register to S Register
let Uses = [rAL], Defs = [rSL, rM, rV], hasSideEffects = 0 in
def XASB: ImplicitReg<0x4F, "XASB">;    // Transfer A Register to S Register (Byte mode)

//===----------------------------------------------------------------------===//
// Compression
//===----------------------------------------------------------------------===//

// The AsmPrinter swaps in the one-byte implicit form once registers are
// known (compressInst). Each pair has the same result and the same webCenREE
// flag set, so nothing that reads the flags can tell them apart. ADD A,A,1
// is not INA: one adds a literal, the other adds 1. Hand-written assembly is
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
  // Every one of these is AOP.XFR: Minus and Value follow the value moved.
  let Defs = !listconcat(DataDefs, [rM, rV]), Uses = DataUses, hasSideEffects = 0 in {
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
    let Defs = !listconcat(DataDefs, [rM, rV]), Uses = !listconcat(DataUses, [R.Reg]),
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
  let Defs = !listconcat(!if(OP.IsLoad, [OP.Reg], []<Register>), [rM, rV]),
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
// STR is AOP.XFR, so it sets Minus and Value from the stored word.
let Defs = [rM, rV] in
class STRMem32
      : CenturionInst32<(outs), (ins GPR:$src, abs16:$addr),
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
let hasSideEffects = 0, mayLoad = 0, mayStore = 1, Defs = [rM, rV] in
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

let Defs = [rM, rV] in
class STRReg16
      : CenturionInst16<(outs), (ins GPR:$src, GPR:$dst),
        "STR", "$src,$dst"> {
  bits<4> src;
  bits<4> dst;
  let Inst{15-8} = 214;
  let Inst{7-4} = src;
  let Inst{3-0} = dst;
}

let Defs = [rM, rV] in
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
// Ind marks the forms whose target is read from a register or memory.
multiclass DirJump<bits<5> opcode, bit Ind = 0> {
  def _1 : MemRef24Strange<opcode, 0b001, abs16, NAME, "(${arg})">;
  def _3 : MemRef16Strange<opcode, 0b011, pcoff8, NAME, "(PC),$arg">;
  let isIndirectBranch = Ind in {
  def _2 : MemRef24Strange<opcode, 0b010, abs16, NAME, "((${arg}))">;
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
}
// JMP (PC),b is the selected jump; JMP (addr) is its long form after branch
// relaxation.
let isBranch = 1, isTerminator = 1, isBarrier = 1 in
defm JMP : DirJump<0b01110, 1>;

// Tail call. Same transfer as JMP (addr): X is left holding this function's
// return address, and the callee's RSR returns to our caller. isReturn puts
// the epilogue in front of it. It is not a branch, because branch relaxation
// treats every unconditional branch as a jump to a block. The encoding is
// JMP_1's; CPU6MCInstLower swaps the opcode at emit so the disassembler,
// which already knows JMP (addr), does not grow a second copy of those bits.
// Size is 3 so a short branch that jumps over this call measures it.
let isReturn = 1, isTerminator = 1, isBarrier = 1, isCodeGenOnly = 1,
    isPseudo = 1, hasSideEffects = 1, Size = 3 in
def TAILJMP : CenturionInst<(outs), (ins abs16:$dst), "JMP", "(${dst})">;
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

// Opcode families 0x47 (immediate count-1) and 0x67 (count in AL). The
// Mem47*/Mem67*/Fil47*/Fil67* classes below cover the addressing-mode
// matrix (4- through 7-byte encodings). WIPL / load7 reference forms:
//   `47 4c 00 ff 02 65`  MVF (1)=0xFF, /0x0265   (mode 0xC, lit + abs)
//   `47 9c 09 a0 03 65`  FIL (10)=0xA0, /0x0365
//   `67 4a 86`           MVFR -Z,-Y              (mode 0xA, two regs)
//   `67 4a 64`           memcpy AL, [Y], [X]
//
// MVF is selector 4, FIL is 9, CPF is 8. A 0x47 length is immediate
// count-1 (at most 256 bytes); MVFR/FILR/CPFR take that length in AL.
// Codegen selects the register forms and, for a single-use address, the
// absolute and indexed 0x47 forms. MVFR is the variable-length copy.
// CPFR_RR is the variable-length compare; the other 0x67 compare forms
// stay in the assembler.
//
// Run in the CenREE microcode simulator: the copy goes one byte at a time
// from the lowest address up, so a destination one byte above its source
// repeats the first byte. Register operands are only read. MVFR ignores AU.
// MVF and MVFR set Minus and Value from the bytes copied. FIL left both
// flags as they were. Each costs about 60 microcycles plus 8 per byte copied
// or 5 per byte filled.
class BlockLit48<bits<4> sel, string name>
      : CenturionInst48<(outs),
          (ins uimm8:$count, i8imm:$byte, abs16:$addr),
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
// MVF clears Minus and Value, then sets them from the bytes it copied.
// Fault and Link are left alone. FIL does not touch the flags. The absolute
// FIL is the memset of a global; MVF's literal form is assembler-only.
let Defs = [rM, rV] in
def MVF : BlockLit48<4, "MVF">;
let mayStore = 1, hasSideEffects = 0 in
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
let Uses = [rAL], Defs = [rM, rV], mayLoad = 1, mayStore = 1,
    hasSideEffects = 0 in
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
// Flags is the condition bits this selector writes. Empty means none.
class OpSel<string name, bits<4> sel, list<Register> flags = []> {
  string Name = name;
  bits<4> Sel = sel;
  list<Register> Flags = flags;
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
      : CenturionInst48<(outs), (ins uimm8:$count, GPR:$src, abs16:$addr),
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
      : CenturionInst48<(outs), (ins uimm8:$count, abs16_t1:$addr, GPR:$dst),
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
      : CenturionInst56<(outs), (ins uimm8:$count, abs16_t2:$addr, abs16:$addr2),
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
      : CenturionInst56<(outs), (ins uimm8:$count, GPR:$base, simm8:$disp, abs16:$addr),
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
      : CenturionInst56<(outs), (ins uimm8:$count, abs16_t2:$addr, GPR:$base, simm8:$disp),
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
    OpSel<"MVF", 4, [rM, rV]>,
    OpSel<"CPF", 8, [rF, rL, rM, rV]>
] in {
  let Defs = OP.Flags, mayLoad = 1, mayStore = !ne(OP.Name, "CPF"),
      hasSideEffects = 0 in
  def OP.Name#_RR : Mem47RR<OP.Sel, OP.Name>;
}

foreach OP = [
    OpSel<"MVF", 4, [rM, rV]>,
    OpSel<"CPF", 8, [rF, rL, rM, rV]>
] in {
  let Defs = OP.Flags, mayLoad = 1, mayStore = !ne(OP.Name, "CPF"),
      hasSideEffects = 0 in
  def OP.Name#_RD : Mem47RD<OP.Sel, OP.Name>;
}

foreach OP = [
    OpSel<"MVF", 4, [rM, rV]>,
    OpSel<"CPF", 8, [rF, rL, rM, rV]>
] in {
  let Defs = OP.Flags, mayLoad = 1, mayStore = !ne(OP.Name, "CPF"),
      hasSideEffects = 0 in
  def OP.Name#_DR : Mem47DR<OP.Sel, OP.Name>;
}

foreach OP = [
    OpSel<"MVF", 4, [rM, rV]>,
    OpSel<"CPF", 8, [rF, rL, rM, rV]>
] in {
  let Defs = OP.Flags, mayLoad = 1, mayStore = !ne(OP.Name, "CPF"),
      hasSideEffects = 0 in
  def OP.Name#_DD : Mem47DD<OP.Sel, OP.Name>;
}

foreach OP = [
    OpSel<"MVF", 4, [rM, rV]>,
    OpSel<"CPF", 8, [rF, rL, rM, rV]>
] in {
  let Defs = OP.Flags, mayLoad = 1, mayStore = !ne(OP.Name, "CPF"),
      hasSideEffects = 0 in
  def OP.Name#_I8D : Mem47I8D<OP.Sel, OP.Name>;
}

foreach OP = [
    OpSel<"MVF", 4, [rM, rV]>,
    OpSel<"CPF", 8, [rF, rL, rM, rV]>
] in {
  let Defs = OP.Flags, mayLoad = 1, mayStore = !ne(OP.Name, "CPF"),
      hasSideEffects = 0 in
  def OP.Name#_DI8 : Mem47DI8<OP.Sel, OP.Name>;
}

foreach OP = [
    OpSel<"MVF", 4, [rM, rV]>,
    OpSel<"CPF", 8, [rF, rL, rM, rV]>
] in {
  let Defs = OP.Flags, mayLoad = 1, mayStore = !ne(OP.Name, "CPF"),
      hasSideEffects = 0 in
  def OP.Name#_I8I8 : Mem47I8I8<OP.Sel, OP.Name>;
}

foreach OP = [
    OpSel<"MVF", 4, [rM, rV]>,
    OpSel<"CPF", 8, [rF, rL, rM, rV]>
] in {
  let Defs = OP.Flags, mayLoad = 1, mayStore = !ne(OP.Name, "CPF"),
      hasSideEffects = 0 in
  def OP.Name#_I8R : Mem47I8R<OP.Sel, OP.Name>;
}

foreach OP = [
    OpSel<"MVF", 4, [rM, rV]>,
    OpSel<"CPF", 8, [rF, rL, rM, rV]>
] in {
  let Defs = OP.Flags, mayLoad = 1, mayStore = !ne(OP.Name, "CPF"),
      hasSideEffects = 0 in
  def OP.Name#_RI8 : Mem47RI8<OP.Sel, OP.Name>;
}

foreach OP = [
    OpSel<"MVF", 4, [rM, rV]>,
    OpSel<"CPF", 8, [rF, rL, rM, rV]>
] in {
  let Defs = OP.Flags, mayLoad = 1, mayStore = !ne(OP.Name, "CPF"),
      hasSideEffects = 0 in
  def OP.Name#_I16R : Mem47I16R<OP.Sel, OP.Name>;
}

foreach OP = [
    OpSel<"MVF", 4, [rM, rV]>,
    OpSel<"CPF", 8, [rF, rL, rM, rV]>
] in {
  let Defs = OP.Flags, mayLoad = 1, mayStore = !ne(OP.Name, "CPF"),
      hasSideEffects = 0 in
  def OP.Name#_RI16 : Mem47RI16<OP.Sel, OP.Name>;
}

foreach OP = [
    OpSel<"FIL", 9>
] in {
  let Defs = OP.Flags, mayLoad = 0, mayStore = 1, hasSideEffects = 0 in
  def OP.Name#_R : Fil47R<OP.Sel, OP.Name>;
}

foreach OP = [
    OpSel<"FIL", 9>
] in {
  let Defs = OP.Flags, mayLoad = 0, mayStore = 1, hasSideEffects = 0 in
  def OP.Name#_I8 : Fil47I8<OP.Sel, OP.Name>;
}

foreach OP = [
    OpSel<"FIL", 9>
] in {
  let Defs = OP.Flags, mayLoad = 0, mayStore = 1, hasSideEffects = 0 in
  def OP.Name#_I16 : Fil47I16<OP.Sel, OP.Name>;
}

// CenREE: AL is count-1, AU is ignored, and the flags match CPF (V equal,
// Minus if dst's first differing byte is unsigned-less than src).
foreach OP = [
    OpSel<"CPFR", 8, [rF, rL, rM, rV]>
] in {
  let Uses = [rAL], Defs = OP.Flags, mayLoad = 1, mayStore = 0,
      hasSideEffects = 0 in
  def OP.Name#_RR : Mem67RR<OP.Sel, OP.Name>;
}

foreach OP = [
    OpSel<"MVFR", 4>,
    OpSel<"CPFR", 8>
] in {
  let Defs = OP.Flags in
  def OP.Name#_RD : Mem67RD<OP.Sel, OP.Name>;
}

foreach OP = [
    OpSel<"MVFR", 4>,
    OpSel<"CPFR", 8>
] in {
  let Defs = OP.Flags in
  def OP.Name#_DR : Mem67DR<OP.Sel, OP.Name>;
}

foreach OP = [
    OpSel<"MVFR", 4>,
    OpSel<"CPFR", 8>
] in {
  let Defs = OP.Flags in
  def OP.Name#_DD : Mem67DD<OP.Sel, OP.Name>;
}

foreach OP = [
    OpSel<"MVFR", 4>,
    OpSel<"CPFR", 8>
] in {
  let Defs = OP.Flags in
  def OP.Name#_I8R : Mem67I8R<OP.Sel, OP.Name>;
}

foreach OP = [
    OpSel<"MVFR", 4>,
    OpSel<"CPFR", 8>
] in {
  let Defs = OP.Flags in
  def OP.Name#_RI8 : Mem67RI8<OP.Sel, OP.Name>;
}

foreach OP = [
    OpSel<"MVFR", 4>,
    OpSel<"CPFR", 8>
] in {
  let Defs = OP.Flags in
  def OP.Name#_I8D : Mem67I8D<OP.Sel, OP.Name>;
}

foreach OP = [
    OpSel<"MVFR", 4>,
    OpSel<"CPFR", 8>
] in {
  let Defs = OP.Flags in
  def OP.Name#_DI8 : Mem67DI8<OP.Sel, OP.Name>;
}

foreach OP = [
    OpSel<"MVFR", 4>,
    OpSel<"CPFR", 8>
] in {
  let Defs = OP.Flags in
  def OP.Name#_I8I8 : Mem67I8I8<OP.Sel, OP.Name>;
}

foreach OP = [
    OpSel<"MVFR", 4>,
    OpSel<"CPFR", 8>
] in {
  let Defs = OP.Flags in
  def OP.Name#_I16R : Mem67I16R<OP.Sel, OP.Name>;
}

foreach OP = [
    OpSel<"MVFR", 4>,
    OpSel<"CPFR", 8>
] in {
  let Defs = OP.Flags in
  def OP.Name#_RI16 : Mem67RI16<OP.Sel, OP.Name>;
}

foreach OP = [
    OpSel<"MVFR", 4>,
    OpSel<"CPFR", 8>
] in {
  let Defs = OP.Flags in
  def OP.Name#_I16D : Mem67I16D<OP.Sel, OP.Name>;
}

foreach OP = [
    OpSel<"MVFR", 4>,
    OpSel<"CPFR", 8>
] in {
  let Defs = OP.Flags in
  def OP.Name#_DI16 : Mem67DI16<OP.Sel, OP.Name>;
}

foreach OP = [
    OpSel<"MVFR", 4>,
    OpSel<"CPFR", 8>
] in {
  let Defs = OP.Flags in
  def OP.Name#_I8I16 : Mem67I8I16<OP.Sel, OP.Name>;
}

foreach OP = [
    OpSel<"MVFR", 4>,
    OpSel<"CPFR", 8>
] in {
  let Defs = OP.Flags in
  def OP.Name#_I16I8 : Mem67I16I8<OP.Sel, OP.Name>;
}

foreach OP = [
    OpSel<"FILR", 9>
] in {
  let Defs = OP.Flags in
  def OP.Name#_R : Fil67R<OP.Sel, OP.Name>;
}

foreach OP = [
    OpSel<"FILR", 9>
] in {
  let Defs = OP.Flags in
  def OP.Name#_D : Fil67D<OP.Sel, OP.Name>;
}

foreach OP = [
    OpSel<"FILR", 9>
] in {
  let Defs = OP.Flags in
  def OP.Name#_I8 : Fil67I8<OP.Sel, OP.Name>;
}

foreach OP = [
    OpSel<"FILR", 9>
] in {
  let Defs = OP.Flags in
  def OP.Name#_I16 : Fil67I16<OP.Sel, OP.Name>;
}

//===----------------------------------------------------------------------===//
// Bignum
//===----------------------------------------------------------------------===//

// Opcode family 0x46: `46 llllkkkk ssssmmnn`, then the operand tails, as
// webCenREE decodes them (cen.ts ex_decode; decode_exmode prints them).
//
//   llll, kkkk  Source and destination length-1. 3 is a 4-byte operand (an
//               i32), 7 is 8 bytes (an i64), and 15 is 16 bytes (an i128).
//               1 to 16 bytes are valid.
//               Memory is big-endian: the address names the most significant
//               byte.
//   ssss        Selector, see BigOps below.
//   mm, nn      Source and destination addressing mode:
//                 0 address   a 16-bit big-endian address word             (A)
//                 1 indexed   an index byte, then a disp8                  (X)
//                 2 register  one byte, source in the high nibble and
//                             destination in the low one. Two register
//                             operands share that byte.                    (R)
//                 3 literal   inline bytes, source only. See BN6Lit*.
//   The tails follow the prefix, source first. Selectors 0-8 compute
//   Dest := Dest op Src. CFB (9) swaps the operand order.
//
// Index byte: the base register in the high nibble, whose low bit selects a
// disp16 instead of the disp8 used here, and a second register to add in the
// low nibble, 0 here. webCenREE rejects an odd register nibble.
//
// A def name ends in the source and destination mode: BNA_AA is two address
// words and BNA_RR is two registers. Assembly spells A as `(sym)`, X as
// `(reg),disp` and R as a bare register. Codegen selects every mode. The
// indexed displacement is the signed byte here; a slot that does not fit is
// materialized with ADD and the register form.
//
// Selectors:
//   0 BNA  ADD    Dest := Dest + Src                         F L M V
//   1 BNS  SUB    Dest := Dest - Src                         F L M V
//   2 BNC  CMP    flags of Dest - Src, Dest unchanged        F L M V
//   3 ZAD  MOV    Dest := Src, zero filled if Dest is wider  F M V
//   4 ZSU  NEG    Dest := -Src
//   5 M    SMUL   Dest := Dest * Src, the low bytes of the product
//   6 D    DIV    Dest := Dest / Src, signed, truncated toward zero
//   7 DRM  DIVREM Dest := Dest / Src as D does, and the remainder (sign of
//                 the dividend) is written to the Dest-sized bytes at the
//                 address in A. A is read and left unchanged.
//   8 CTB  TOBIN  9 CFB  FMBIN
// A, S and C are register names, so the first three are spelled BNA, BNS and
// BNC. cen.ts implements only ZAD and CTB. ZAD walks from the least
// significant byte: V is set when every byte written is zero, M follows the
// source sign byte, F is set when the source and final destination sign bytes
// differ in sign, and Link is untouched.
//
// The results of BNA, BNS, BNC, ZSU, M, D and DRM were confirmed on the machine
// (bignum*.c and bnprobe.c in cent_stdlibs), including where DRM puts its
// remainder. They were run on 4 and 8 bytes, with negative values, and with
// Src and Dest at one address (for DRM: the divisor, as the remainder's
// address). The one surprise: DRM writes the remainder after the quotient, but
// with the remainder sent to the Dest bytes the quotient's sign fix also hits
// it, so -22 % 7 gave +1 and 22 % -7 gave -1. A remainder sent to the Src
// bytes was right for every sign combination. The values of the flags other
// than what BNC's users read are not known, so every
// selector that computes lists all of F, L, M and V as clobbered. Codegen
// reads V for == and !=, and Link for unsigned order, as it does after SUB:
// Link set means no borrow.
//
// Microcode bugs. People who have reverse engineered this machine report
// that the 0x46 arithmetic is wrong for some values, and that the bugs
// show up more as the length grows (the hardware length goes to 16 bytes,
// 128 bits). CPL's remedy is to run the operation at a higher length and
// then narrow to the precision the program asked for. This backend does
// not do that. combineBignumStore / combineBignumSetCC select the
// operation at the width of the IR value. A wrong result from an
// instruction whose selector, lengths, operand order, and addresses are
// right is a microcode bug. Leave the instruction in place. Do not drop
// the fold, retarget the operation at compiler-rt, or synthesize a wider
// intermediate to hide it. The DRM alias above is different: that one is
// understood, and the selector keeps the remainder off the quotient's
// bytes. An uncharacterized wrong answer is not a selection failure.
//
// M (selector 5) is one of those, and the wrong part is Fault. Stepping
// webCenREE's microcode (cpu.step; cen.ts does not implement this
// selector) stored the low Dest bytes of the signed product on every
// trial, big-endian two's complement. Trials: all 65536 one-byte pairs
// with both operands in -128..127; the sign, zero, and power-of-two
// corners at 2, 4, and 8 bytes, including unequal lengths, Src and Dest
// at one address, and Fault both clear and set on entry; the same
// corners at 3, 5, 6, 7, and 16 bytes, including a 1-byte operand
// against a 16-byte one. Same-address operands were part of the 1, 2,
// 4, and 8 byte runs. Operands were absolute addresses. Value was set
// exactly when the stored bytes were zero, and Minus followed their
// sign bit. A product of zero was stored as zeros with Value set, and so
// was a product of exactly -(2^(8*DestLen)), whose low Dest bytes are zero.
// The stored zero is the right truncation. Link was clear after every
// multiply in those sweeps. M also cleared an incoming Link: ADD of
// 0x8000 and 0x8000 leaves V, Fault, and Link set, and the following
// one-byte M ended with Link clear for 2*3, for 0*-1, and for -128*2.
//
// Fault is computed and written. The bit on entry does not stick: RF
// and SF before the same multiply produce the same Fault, and the
// incoming Link test above had Fault set and a fitting 2*3 cleared it.
// Two products write the wrong Fault. Both show up at every Dest length
// tried, with the negative factor on either side. The width below is
// the Dest length. A 1-byte Src against a 16-byte Dest, and a 16-byte
// Src against a 1-byte Dest, followed these rules.
//
//   The product is 0 and either operand is negative. Fault is set.
//   0*0, 0 times a positive, and a positive times 0 leave Fault clear.
//   All 256 one-byte
//   pairs of that shape set Fault, and no other one-byte pair whose
//   product was 0 did. The bytes are zero and Value is set; only Fault is
//   wrong. 0 is not negative, so a negative times a negative is not in
//   this set.
//
//   The product is exactly -(2^(8*DestLen)). Fault is clear. The stored
//   bytes are zero and Value is set, but the product does not fit in a
//   signed Dest, so Fault should be set. On one byte the only such
//   pairs are the twelve factorizations of -256 that fit in a signed
//   byte: 2*-128, 4*-64, 8*-32, 16*-16, 32*-8, 64*-4, and each swap.
//   Every other one-byte pair set Fault exactly when the product did
//   not fit. The neighbors of this product do set Fault:
//   +2^(8*DestLen) (the most negative Dest value times -2, and
//   4*2^(8*DestLen-2)), -(2^(8*DestLen+1)) (that value times 4, and
//   -8*2^(8*DestLen-2)), and the most negative Dest value times -1,
//   which overflows to +2^(8*DestLen-1). The most negative value itself
//   fits (times 1, and -2*2^(8*DestLen-2)) and Fault stays clear.
//   A 16-byte most-negative value times a 1-byte 2 misses Fault. A
//   1-byte 0 times a 16-byte -1 sets it.
//
// A branch on Fault after M therefore treats a negative times zero as
// overflow, and treats an overflow to exactly -(2^(8*DestLen)) as a
// zero result that fit. The stored bits and Value are still the low part
// of the signed product. Selector, lengths, operand order, and
// addresses are right. Leave M at the width of the IR value.

// The prefix shared by every layout: opcode, lengths, selector, modes.
class BNHead<bits<4> sel, bits<2> sm, bits<2> dm> {
  bits<4> l;
  bits<4> k;
  bits<24> Head = {0b01000110, l, k, sel, sm, dm};
}

class BN_AA<bits<4> sel, string name>
      : CenturionInst56<(outs),
          (ins uimm4:$l, uimm4:$k, abs16_t2:$src, abs16:$dst),
          name, "$l,$k,(${src}),(${dst})">,
        BNHead<sel, 0, 0> {
  bits<16> src;
  bits<16> dst;
  let Inst{55-32} = Head;
  let Inst{31-16} = src;
  let Inst{15-0} = dst;
}

class BN_AX<bits<4> sel, string name>
      : CenturionInst56<(outs),
          (ins uimm4:$l, uimm4:$k, abs16_t2:$src, GPR:$dbase, simm8:$ddisp),
          name, "$l,$k,(${src}),(${dbase}),$ddisp">,
        BNHead<sel, 0, 1> {
  bits<16> src;
  bits<4> dbase;
  bits<8> ddisp;
  let Inst{55-32} = Head;
  let Inst{31-16} = src;
  let Inst{15-0} = {dbase{3-1}, 0b0, 0b0000, ddisp};
}

class BN_AR<bits<4> sel, string name>
      : CenturionInst48<(outs),
          (ins uimm4:$l, uimm4:$k, abs16_t1:$src, GPR:$dst),
          name, "$l,$k,(${src}),$dst">,
        BNHead<sel, 0, 2> {
  bits<16> src;
  bits<4> dst;
  let Inst{47-24} = Head;
  let Inst{23-8} = src;
  let Inst{7-0} = {0b0000, dst};
}

class BN_XA<bits<4> sel, string name>
      : CenturionInst56<(outs),
          (ins uimm4:$l, uimm4:$k, GPR:$sbase, simm8:$sdisp, abs16:$dst),
          name, "$l,$k,(${sbase}),$sdisp,(${dst})">,
        BNHead<sel, 1, 0> {
  bits<4> sbase;
  bits<8> sdisp;
  bits<16> dst;
  let Inst{55-32} = Head;
  let Inst{31-16} = {sbase{3-1}, 0b0, 0b0000, sdisp};
  let Inst{15-0} = dst;
}

class BN_XX<bits<4> sel, string name>
      : CenturionInst56<(outs),
          (ins uimm4:$l, uimm4:$k, GPR:$sbase, simm8:$sdisp,
               GPR:$dbase, simm8:$ddisp),
          name, "$l,$k,(${sbase}),$sdisp,(${dbase}),$ddisp">,
        BNHead<sel, 1, 1> {
  bits<4> sbase;
  bits<8> sdisp;
  bits<4> dbase;
  bits<8> ddisp;
  let Inst{55-32} = Head;
  let Inst{31-16} = {sbase{3-1}, 0b0, 0b0000, sdisp};
  let Inst{15-0} = {dbase{3-1}, 0b0, 0b0000, ddisp};
}

class BN_XR<bits<4> sel, string name>
      : CenturionInst48<(outs),
          (ins uimm4:$l, uimm4:$k, GPR:$sbase, simm8:$sdisp, GPR:$dst),
          name, "$l,$k,(${sbase}),$sdisp,$dst">,
        BNHead<sel, 1, 2> {
  bits<4> sbase;
  bits<8> sdisp;
  bits<4> dst;
  let Inst{47-24} = Head;
  let Inst{23-8} = {sbase{3-1}, 0b0, 0b0000, sdisp};
  let Inst{7-0} = {0b0000, dst};
}

class BN_RA<bits<4> sel, string name>
      : CenturionInst48<(outs),
          (ins uimm4:$l, uimm4:$k, GPR:$src, abs16:$dst),
          name, "$l,$k,$src,(${dst})">,
        BNHead<sel, 2, 0> {
  bits<4> src;
  bits<16> dst;
  let Inst{47-24} = Head;
  let Inst{23-16} = {src, 0b0000};
  let Inst{15-0} = dst;
}

class BN_RX<bits<4> sel, string name>
      : CenturionInst48<(outs),
          (ins uimm4:$l, uimm4:$k, GPR:$src, GPR:$dbase, simm8:$ddisp),
          name, "$l,$k,$src,(${dbase}),$ddisp">,
        BNHead<sel, 2, 1> {
  bits<4> src;
  bits<4> dbase;
  bits<8> ddisp;
  let Inst{47-24} = Head;
  let Inst{23-16} = {src, 0b0000};
  let Inst{15-0} = {dbase{3-1}, 0b0, 0b0000, ddisp};
}

class BN_RR<bits<4> sel, string name>
      : CenturionInst32<(outs),
          (ins uimm4:$l, uimm4:$k, GPR:$src, GPR:$dst),
          name, "$l,$k,$src,$dst">,
        BNHead<sel, 2, 2> {
  bits<4> src;
  bits<4> dst;
  let Inst{31-8} = Head;
  let Inst{7-0} = {src, dst};
}

// Every 0x46 selector, shared by the register/address forms and the literal
// forms below. Flags is what the selector writes.
defvar BigOps = [
    OpSel<"BNA", 0, [rF, rL, rM, rV]>,
    OpSel<"BNS", 1, [rF, rL, rM, rV]>,
    OpSel<"BNC", 2, [rF, rL, rM, rV]>,
    OpSel<"ZAD", 3, [rF, rM, rV]>,
    OpSel<"ZSU", 4, [rF, rL, rM, rV]>,
    OpSel<"M", 5, [rF, rL, rM, rV]>,
    OpSel<"D", 6, [rF, rL, rM, rV]>,
    OpSel<"DRM", 7, [rF, rL, rM, rV]>,
    OpSel<"CTB", 8, [rL]>,
    OpSel<"CFB", 9>
];

// The operands are read from memory, and every selector but BNC writes the
// destination back. DRM also reads the remainder's address from A.
foreach OP = BigOps in {
  let Defs = OP.Flags, mayLoad = 1, mayStore = !ne(OP.Name, "BNC"),
      Uses = !if(!eq(OP.Name, "DRM"), [rA], []<Register>) in {
    def OP.Name#_AA : BN_AA<OP.Sel, OP.Name>;
    def OP.Name#_AX : BN_AX<OP.Sel, OP.Name>;
    def OP.Name#_AR : BN_AR<OP.Sel, OP.Name>;
    def OP.Name#_XA : BN_XA<OP.Sel, OP.Name>;
    def OP.Name#_XX : BN_XX<OP.Sel, OP.Name>;
    def OP.Name#_XR : BN_XR<OP.Sel, OP.Name>;
    def OP.Name#_RA : BN_RA<OP.Sel, OP.Name>;
    def OP.Name#_RX : BN_RX<OP.Sel, OP.Name>;
    def OP.Name#_RR : BN_RR<OP.Sel, OP.Name>;
  }
}

class BN6LitD<bits<4> sel, string name>
      : CenturionInst48<(outs), (ins uimm4:$k, i8imm:$lit, abs16:$addr),
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

// Literal source (mode 3, one inline byte) into each destination mode.
// CenREE sign-extends that byte and adds it at the low byte: 0xFF into a
// zero i32 is -1, and 0x000000FF + 1 carries to 0x100. The address word is
// the last two bytes, so its relocation is abs16 (tail 0). A number still
// assembles: BNA 1,255,(613).
foreach OP = BigOps in {
  let Defs = OP.Flags, mayLoad = 1, mayStore = !ne(OP.Name, "BNC"),
      Uses = !if(!eq(OP.Name, "DRM"), [rA], []<Register>) in {
    def OP.Name#_LitD : BN6LitD<OP.Sel, OP.Name>;
    def OP.Name#_LitI8 : BN6LitI8<OP.Sel, OP.Name>;
    def OP.Name#_LitR : BN6LitR<OP.Sel, OP.Name>;
    def OP.Name#_LitI16 : BN6LitI16<OP.Sel, OP.Name>;
  }
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
  let Defs = OP.Flags in
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
  let Defs = OP.Flags in
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
  let Defs = OP.Flags in
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
  let Defs = OP.Flags in
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
  let Defs = OP.Flags in
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
  let Defs = OP.Flags in
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
  let Defs = OP.Flags in
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
  let Defs = OP.Flags in
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
  let Defs = OP.Flags in
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
  let Defs = OP.Flags in
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
  let Defs = OP.Flags in
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
  let Defs = OP.Flags in
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
  let Defs = OP.Flags in
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
  let Defs = OP.Flags in
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
  let Defs = OP.Flags in
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
  let Defs = OP.Flags in
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
  let Defs = OP.Flags in
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
  let Defs = OP.Flags in
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
  let Defs = OP.Flags in
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
// fl is ArithFLMV. The interpreter does not implement the body.
let Defs = [rF, rL, rM, rV] in {
def SAR : ILMove16<0xD7, "SAR">;
def LAR : ILMove16<0xE6, "LAR">;
}

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

let Defs = [rF, rL, rM, rV] in {
def LST: TwoArg24<0x6E, "LST", "(${arg1}),(${arg2})">;
def SST: TwoArg24<0x6F, "SST", "(${arg1}),(${arg2})">;
}
