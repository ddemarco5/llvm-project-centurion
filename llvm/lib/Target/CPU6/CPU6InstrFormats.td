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

class SingleArg16DMA<bits<8> op, bits<4> sel, dag outs, dag ins, string opstr, string argstr>
      : CenturionInst16<outs, ins, opstr, argstr> {


    bits<4> argnib;
    let Inst{15-8} = op;
    let Inst{7-4} = argnib;
    let Inst{3-0} = sel;
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

// A 24 bit opcode with two 8 bit args
class DoubleArg24<bits<8> op, dag outs, dag ins, string opstr, string argstr>
      : CenturionInst24<outs, ins, opstr, argstr> {


    bits<8> arg1;
    bits<8> arg2;
    let Inst{23-16} = op;
    let Inst{15-8} = arg1;
    let Inst{7-0} = arg2;
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
class Memory16<bits<4> opcode, bits<4> M, dag outs, dag ins, 
      string opstr, string argstr> : CenturionInst16<outs, ins, opstr, argstr> {
    
    bits<8> arg;
    let Inst{15-12} = opcode;
    let Inst{11-8} = M;
    let Inst{7-0} = arg;
}

// two byte flavor of opcode, LDX, STX, JMP, and JSR use a strange opcode format
// where the opcode is 5 bits in size and the M is 3, they only use M flavors 0-5
class Memory16Strange<bits<5> opcode, bits<3> M, dag outs, dag ins, 
      string opstr, string argstr> : CenturionInst16<outs, ins, opstr, argstr> {
    
    bits<8> arg;
    let Inst{15-11} = opcode;
    let Inst{10-8} = M;
    let Inst{7-0} = arg;
}

// two byte flavor of opcode, special indexed addressing case
class Memory16Index<bits<4> opcode, bits<4> m_prime, dag outs, dag ins, string opstr, string argstr>
        : CenturionInst16<outs, ins, opstr, argstr> {
    
    bits<4> arg;
    let Inst{15-12} = opcode;
    let Inst{11-8} = 5; // This is always the M = 5 case
    let Inst{7-4} = arg;
    let Inst{3-0} = m_prime;
}
class Memory16IndexStrange<bits<5> opcode, bits<4> m_prime, dag outs, dag ins, string opstr, string argstr>
        : CenturionInst16<outs, ins, opstr, argstr> {
    
    bits<4> arg;
    let Inst{15-11} = opcode;
    let Inst{10-8} = 0b101; // This is always the M = 5 case
    let Inst{7-4} = arg;
    let Inst{3-0} = m_prime;
}

// three byte flavor of opcode
class Memory24<bits<4> opcode, bits<4> M, dag outs, dag ins, 
      string opstr, string argstr> : CenturionInst24<outs, ins, opstr, argstr> {
    
    //bits<4> M;
    bits<16> arg;

    let Inst{23-20} = opcode;
    let Inst{19-16} = M;
    let Inst{15-0} = arg;
}
class Memory24Strange<bits<5> opcode, bits<3> M, dag outs, dag ins, 
      string opstr, string argstr> : CenturionInst24<outs, ins, opstr, argstr> {
    
    //bits<4> M;
    bits<16> arg;

    let Inst{23-19} = opcode;
    let Inst{18-16} = M;
    let Inst{15-0} = arg;
}
// three byte flavor of opcode, special indexed addressing case
class Memory24Index<bits<4> opcode, bits<4> m_prime, dag outs, dag ins, string opstr, string argstr>
        : CenturionInst24<outs, ins, opstr, argstr> {
    
    bits<4> r;
    bits<8> arg;
    let Inst{23-20} = opcode;
    let Inst{19-16} = 5; // this is the M = 5 case
    let Inst{15-12} = r;
    let Inst{11-8} = m_prime;
    let Inst{7-0} = arg;
}
class Memory24IndexStrange<bits<5> opcode, bits<4> m_prime, dag outs, dag ins, string opstr, string argstr>
        : CenturionInst24<outs, ins, opstr, argstr> {
    
    bits<4> r;
    bits<8> arg;
    let Inst{23-19} = opcode;
    let Inst{18-16} = 0b101; // this is the M = 5 case
    let Inst{15-12} = r;
    let Inst{11-8} = m_prime;
    let Inst{7-0} = arg;
}