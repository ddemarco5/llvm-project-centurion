// Declarations that describe the CPU6 register file

// All CPU6 registers can be accessed as upper/lower subregisters, define that here
class CPU6Reg<bits<16> Enc, string name, list<Register> subregs = []> : RegisterWithSubRegs<name, subregs> {
    let HWEncoding = Enc;
    let Namespace = "CPU6";
}

// A word register is big-endian in the register file: the upper byte sits at
// the even address and the lower byte at the odd one. sub_hi is bits 15-8 of
// the word (AU), sub_lo is bits 7-0 (AL).
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

// Define the hi/lo 8 bit regs. A byte operand nibble is the register-file
// byte address: webCenREE get_rb(n) reads byte (n & 15), and its regname
// table lists AU AL BU BL XU XL YU YL ZU ZL SU SL CU CL PU PL in that order.
// A word operand nibble is the even address of the pair (get_rw(n & 14)).
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

// LDA and STA always touch A. A result or stored value has to land there.
def Acc : RegisterClass<"CPU6", [i16], 8, (add rA)>;

def GPRhi : RegisterClass<"CPU6", [i8], 8, (add rAU, rBU, rXU, rYU, rZU, rSU, rCU, rPU)>;
def GPRlo : RegisterClass<"CPU6", [i8], 8, (add rAL, rBL, rXL, rYL, rZL, rSL, rCL, rPL)>;
// All the 8 bit registers, some instructions can use both hi and lo. i8
// values live here. The low halves come first so a byte lands where the byte
// accumulator (AL) and zero/sign extension into the word want it.
def GPRB  : RegisterClass<"CPU6", [i8], 8, (add rAL, rBL, rXL, rYL, rZL, rSL, rCL, rPL,
                                            rAU, rBU, rXU, rYU, rZU, rSU, rCU, rPU)>;

// LDAB and STAB always touch AL, the byte half of the accumulator.
def AccB : RegisterClass<"CPU6", [i8], 8, (add rAL)>;

// Condition flags. The wiki packs them into C, in bits 7-4 of the low byte:
//   7 Value (zero), 6 Minus (sign), 5 Fault (overflow), 4 Link (carry).
// Bits 3-0 of that byte are the page map, and bits 15-12 are the previous
// interrupt level. webCenREE does not keep the flags in the register file.
// ccr_v, ccr_m, ccr_f and ccr_l are separate, and the branches read those.
// Writing C does not, by itself, change what BL or BZ test.
//
// These four registers are that state. They are reserved and not part of C,
// so a use of one is a real dependence and the allocator cannot hand it out.
// An instruction defs only the bits it writes. XFR writes Minus and Value
// and leaves Fault and Link, so a later branch on Link still depends on the
// instruction that set Link.
def rV : CPU6Reg<16, "V">;
def rM : CPU6Reg<17, "M">;
def rF : CPU6Reg<18, "F">;
def rL : CPU6Reg<19, "L">;