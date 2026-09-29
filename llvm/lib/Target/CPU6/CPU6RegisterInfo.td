// Declarations that describe the CPU6 register file

// All CPU6 registers can be accessed as upper/lower subregisters, define that here
class CPU6Reg<bits<16> Enc, string name, list<Register> subregs = []> : RegisterWithSubRegs<name, subregs> {
    let HWEncoding = Enc;
    let Namespace = "CPU6";
}

let Namespace = "CPU6" in {
    def sub_lo : SubRegIndex<8>;
    def sub_hi : SubRegIndex<8, 8>;
}


/* Register addressing table from EE200 spec
   Whole 16 bit register is addressed from the MSB addr when using
   word instructions
+------------------+---------+---------+
| Register Address | (M.S.B) | (L.S.B) |
+------------------+---------+---------+
| 0-1              | A       | A       |
| 2-3              | B       | B       |
| 4-5              | X       | X       |
| 6-7              | Y       | Y       |
| 8-9              | Z       | Z       |
| A-B              | S       | S       |
| C-D              | C       | C       |
| E-F              | P       | P       |
+------------------+---------+---------+
*/

// We need to prefix our registers with r here because we have instructions that share a name

// Define the hi/lo 8 bit regs
def rAU : CPU6Reg<0, "AU">, DwarfRegNum<[0]>;
def rAL : CPU6Reg<1, "AL">, DwarfRegNum<[1]>;
def rBU : CPU6Reg<2, "BU">, DwarfRegNum<[2]>;
def rBL : CPU6Reg<3, "BL">, DwarfRegNum<[3]>;
def rXU : CPU6Reg<4, "XU">, DwarfRegNum<[4]>;
def rXL : CPU6Reg<5, "XL">, DwarfRegNum<[5]>;
def rYU : CPU6Reg<6, "YU">, DwarfRegNum<[6]>;
def rYL : CPU6Reg<7, "YL">, DwarfRegNum<[7]>;
def rZU : CPU6Reg<8, "ZU">, DwarfRegNum<[8]>;
def rZL : CPU6Reg<9, "ZL">, DwarfRegNum<[9]>;
def rSU : CPU6Reg<10, "SU">, DwarfRegNum<[10]>;
def rSL : CPU6Reg<11, "SL">, DwarfRegNum<[11]>;
def rCU : CPU6Reg<12, "CU">, DwarfRegNum<[12]>;
def rCL : CPU6Reg<13, "CL">, DwarfRegNum<[13]>;
def rPU : CPU6Reg<14, "PU">, DwarfRegNum<[14]>;
def rPL : CPU6Reg<15, "PL">, DwarfRegNum<[15]>;

// Defining our full 16 bit registers
let SubRegIndices = [sub_hi, sub_lo] in {
    def rA : CPU6Reg<0, "A", [rAU,rAL]>, DwarfRegNum<[0]>;
    def rB : CPU6Reg<2, "B", [rBU,rBL]>, DwarfRegNum<[2]>;
    def rX : CPU6Reg<4, "X", [rXU,rXL]>, DwarfRegNum<[4]>;
    def rY : CPU6Reg<6, "Y", [rYU,rYL]>, DwarfRegNum<[6]>;
    def rZ : CPU6Reg<8, "Z", [rZU,rZL]>, DwarfRegNum<[8]>;
    def rS : CPU6Reg<10, "S", [rSU,rSL]>, DwarfRegNum<[10]>;
    def rC : CPU6Reg<12, "C", [rCU,rCL]>, DwarfRegNum<[12]>;
    def rP : CPU6Reg<14, "P", [rPU,rPL]>, DwarfRegNum<[14]>;
}

// Define the classes of registers. This is to keep track of what registers should be used for what,
// and register restrictions should be enforced here

def GPR : RegisterClass<"CPU6", [i16], 8, (add rA, rB, rX, rY, rZ, rS, rC, rP)>;

def GPRhi : RegisterClass<"CPU6", [i8], 8, (add rAU, rBU, rXU, rYU, rZU, rSU, rCU, rPU)>;
def GPRlo : RegisterClass<"CPU6", [i8], 8, (add rAL, rBL, rXL, rYL, rZL, rSL, rCL, rPL)>;
// All the 8 bit registers, some instructions can use both hi and lo
def GPRB  : RegisterClass<"CPU6", [i8], 8, (add rAU, rBU, rXU, rYU, rZU, rSU, rCU, rPU,
                                            rAL, rBL, rXL, rYL, rZL, rSL, rCL, rPL)>;


//TODO: Do I need to implement a pseudo register to keep track of F,L,M,V flags?
// -- from gecho
// FLMV are the flags (Overflow, Carry, Sign and Zero). 
// There are instructions that can manipulate them directly,
// but in the CPU4 you can only read them with the branch instructions.