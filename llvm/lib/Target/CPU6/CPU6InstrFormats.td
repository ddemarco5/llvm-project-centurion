// We'll define the formats of our instructions here.
// CPU4 has instructions anywhere from 1 to 3 bytes

// Generic Centurion instruction
class CenturionInst<dag outs, dag ins, string asmstr> : Instruction {
    let Namespace = "Centurion";

    dag OutOperandList = outs;
    dag InOperandList = ins;
    let AsmString = asmstr;
}


// A one byte instruction
class CenturionInst8<dag outs, dag ins, string asmstr>
      : CenturionInst<outs, ins, asmstr> {

    field bits<8> Inst;

    let Size = 1;
}

// A two byte instruction
class CenturionInst16<dag outs, dag ins, string asmstr>
      : CenturionInst<outs, ins, asmstr> {

    field bits<16> Inst;

    let Size = 2;
}

// And three byte instruction
class CenturionInst24<dag outs, dag ins, string asmstr>
      : CenturionInst<outs, ins, asmstr> {

    field bits<24> Inst;

    let Size = 3;
}

// TODO: There may be a need for pseudo instructions like in AVRInstrFormats here, we'll see

// FROM EE200 doc:
// Instructions can be categorized into the following groups:
// - Control
// - Branch
// - Single Register
// - Double Register
// - Memory Reference

//-----------  Control  ---------------//
// Instruction: <|zeros|opcode|>
// opcode = 4 bits
// zeroes = 4 bits of 0
//------------------------------------//
class Control<bits<4> opcode, dag outs, dag ins, string asmstr>
      : CenturionInst8<outs, ins, asmstr> {
    
    let Inst{7-4} = 0;
    let Inst{3-0} = opcode;
}

//-----------  Branch  ---------------//
// The operation code byte defines the condition being tested
// The displacement byte, b, contains an eight-bit signed value which specifies
// a jump location relative to PC
// Instruction: <| one |opcode|+127, -128|>
//               |  op code   | disp (b) |
// opcode = 8 bits (high half ones)
// displacement = 8 bits
//------------------------------------//
class Branch<bits<4> opcode, bits<8> disp, dag outs, dag ins, string asmstr>
      : CenturionInst16<outs, ins, asmstr> {
    
    let Inst{15-12} = 1;
    let Inst{11-8} = opcode;
    let Inst{7-0} = disp;
}

//-----------  SingleReg  --------------//
// There are two types of single-register operations, explicit and implicit.
// Explicit register instructions are two-byte instructions with the source
// register address contained in the second byte.
// Instruction: <| 3(2) |opcode| sr |   |>
// The low-order bits of the second byte are used only for the Increment Register
// and Decrement Register instrucitons and are otherwise ignored
// opcode = 8 bits
// sr = 8 bits (low 4 often ignored)
//------------------------------------//
// one byte flavor of opcode
class SingleReg8<bits<8> opcode, dag outs, dag ins, 
      string asmstr> : CenturionInst8<outs, ins, asmstr> {
    
    let Inst{7-0} = opcode;
}
// two byte flavor of opcode
class SingleReg16< bits<8> opcode, bits<8> sr, dag outs, dag ins, 
      string asmstr> : CenturionInst16<outs, ins, asmstr> {
    
    let Inst{15-8} = opcode;
    let Inst{7-0} = sr;
}

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
// one byte flavor of opcode
class DoubleReg8<bits<8> opcode, dag outs, dag ins, 
      string asmstr> : CenturionInst8<outs, ins, asmstr> {
    
    let Inst{7-0} = opcode;
}
// two byte flavor of opcode
class DoubleReg16<bits<8> opcode, dag outs, dag ins, 
      string asmstr> : CenturionInst16<outs, ins, asmstr> {
    
    bits<4> sr;
    bits<4> dr;

    let Inst{15-8} = opcode;
    let Inst{7-4} = sr;
    let Inst{3-0} = dr;
}


//-----------  Memory  --------------//
// Memory reference instructions are those which access an operatnd from addressable memory.
// They can operate on either byte operands or word operands. When operating in the byte mode,
// the least-significant half of the register is used. The instructions can be 8, 16, or 24
// bits long, depending on the address modification used.
// Instruction: <|opcode|  M  | optional second or third byte |>
// The low-order bits of the second byte are used only for the Increment Register
// and Decrement Register instrucitons and are otherwise ignored
// opcode = 4 bits
// M = 4 bits
// optional second or third byte = 0-16 bits
//------------------------------------//
// one byte flavor of opcode
class Memory8<bits<4> opcode, bits<4> M, dag outs, dag ins, 
      string asmstr> : CenturionInst8<outs, ins, asmstr> {
    
    let Inst{7-4} = opcode;
    let Inst{3-0} = M;
}

// two byte flavor of opcode
class Memory16<bits<4> opcode, bits<4> M, bits<8> arg, dag outs, dag ins, 
      string asmstr> : CenturionInst16<outs, ins, asmstr> {
    
    let Inst{15-12} = opcode;
    let Inst{11-8} = M;
    let Inst{7-0} = arg;
}

// three byte flavor of opcode
class Memory24<bits<4> opcode, bits<4> M, dag outs, dag ins, 
      string asmstr> : CenturionInst24<outs, ins, asmstr> {
    
    //bits<4> M;
    bits<16> argword;

    let Inst{23-20} = opcode;
    let Inst{19-16} = M;
    let Inst{15-0} = argword;
}
// three byte flavor of opcode, special indexed addressing case
class Memory24Index<bits<4> opcode, bits<4> r, bits<4> m_prime, bits<8> disp, dag outs, dag ins, 
      string asmstr> : CenturionInst24<outs, ins, asmstr> {
    
    let Inst{23-20} = opcode;
    let Inst{19-16} = 5; // this is the M = 5 case
    let Inst{15-12} = r;
    let Inst{11-8} = m_prime;
    let Inst{7-0} = disp;
}