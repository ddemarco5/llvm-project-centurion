// We'll define the formats of our instructions here.
// CPU4 has instructions anywhere from 1 to 3 bytes

// Generic Centurion instruction
class CenturionInst<dag outs, dag ins, string opstr, string argstr> : Instruction {
    let Namespace = "CPU6";

    dag OutOperandList = outs;
    dag InOperandList = ins;
    let AsmString = opstr # "\t" # argstr;
}


// A one byte instruction
class CenturionInst8<dag outs, dag ins, string opstr>
      : CenturionInst<outs, ins, opstr, ""> {

    field bits<8> Inst;

    let Size = 1;
}

// A two byte instruction
class CenturionInst16<dag outs, dag ins, string opstr, string argstr>
      : CenturionInst<outs, ins, opstr, argstr> {

    field bits<16> Inst;

    let Size = 2;
}

// And three byte instruction
class CenturionInst24<dag outs, dag ins, string opstr, string argstr>
      : CenturionInst<outs, ins, opstr, argstr> {

    field bits<24> Inst;

    let Size = 3;
}

class SingleArg16<bits<8> op, dag outs, dag ins, string opstr, string argstr>
      : CenturionInst16<outs, ins, opstr, argstr> {


    bits<8> argbyte;
    let Inst{15-8} = op;
    let Inst{7-0} = argbyte;
}

// A 16 bit opcode, where the high and low nibble of our 2nd byte are the arguments
class SingleArg16HL<bits<8> op, dag outs, dag ins, string opstr, string argstr>
      : CenturionInst16<outs, ins, opstr, argstr> {


    bits<4> arghnibble;
    bits<4> arglnibble;
    let Inst{15-8} = op;
    let Inst{7-4} = arghnibble;
    let Inst{3-0} = arglnibble;
}

// A 16 bit opcode, where the high and low nibble of our 2nd byte are the arguments
class SingleArg16H<bits<8> op, dag outs, dag ins, string opstr, string argstr>
      : CenturionInst16<outs, ins, opstr, argstr> {


    bits<4> arghnibble;
    let Inst{15-8} = op;
    let Inst{7-4} = arghnibble;
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
      string opstr> : CenturionInst8<outs, ins, opstr> {
    
    let Inst{7-4} = opcode;
    let Inst{3-0} = M;
}

// two byte flavor of opcode
class Memory16<bits<4> opcode, bits<4> M, bits<8> arg, dag outs, dag ins, 
      string opstr, string argstr> : CenturionInst16<outs, ins, opstr, argstr> {
    
    let Inst{15-12} = opcode;
    let Inst{11-8} = M;
    let Inst{7-0} = arg;
}

// three byte flavor of opcode
class Memory24<bits<4> opcode, bits<4> M, dag outs, dag ins, 
      string opstr, string argstr> : CenturionInst24<outs, ins, opstr, argstr> {
    
    //bits<4> M;
    bits<16> argword;

    let Inst{23-20} = opcode;
    let Inst{19-16} = M;
    let Inst{15-0} = argword;
}
// three byte flavor of opcode, special indexed addressing case
class Memory24Index<bits<4> opcode, bits<4> r, bits<4> m_prime, bits<8> disp, dag outs, dag ins, 
      string opstr, string argstr> : CenturionInst24<outs, ins, opstr, argstr> {
    
    let Inst{23-20} = opcode;
    let Inst{19-16} = 5; // this is the M = 5 case
    let Inst{15-12} = r;
    let Inst{11-8} = m_prime;
    let Inst{7-0} = disp;
}