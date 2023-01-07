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

// Define the hi/lo 8 bit regs
def AU : CPU6Reg<0, "AU">, DwarfRegNum<[0]>;
def AL : CPU6Reg<1, "AL">, DwarfRegNum<[2]>;
def BU : CPU6Reg<2, "BU">, DwarfRegNum<[2]>;
def BL : CPU6Reg<3, "BL">, DwarfRegNum<[3]>;
def XU : CPU6Reg<4, "XU">, DwarfRegNum<[4]>;
def XL : CPU6Reg<5, "XL">, DwarfRegNum<[5]>;
def YU : CPU6Reg<6, "YU">, DwarfRegNum<[6]>;
def YL : CPU6Reg<7, "YL">, DwarfRegNum<[7]>;
def ZU : CPU6Reg<8, "ZU">, DwarfRegNum<[8]>;
def ZL : CPU6Reg<9, "ZL">, DwarfRegNum<[9]>;
def SU : CPU6Reg<10, "SU">, DwarfRegNum<[10]>;
def SL : CPU6Reg<11, "SL">, DwarfRegNum<[11]>;
def CU : CPU6Reg<12, "CU">, DwarfRegNum<[12]>;
def CL : CPU6Reg<13, "CL">, DwarfRegNum<[13]>;
def PU : CPU6Reg<14, "PU">, DwarfRegNum<[14]>;
def PL : CPU6Reg<15, "PL">, DwarfRegNum<[15]>;

// Defining our full 16 bit registers
let SubRegIndices = [sub_hi, sub_lo] in {
    def A : CPU6Reg<16, "A", [AU,AL]>, DwarfRegNum<[16]>;
    def B : CPU6Reg<17, "B", [BU,BL]>, DwarfRegNum<[17]>;
    def X : CPU6Reg<18, "X", [XU,XL]>, DwarfRegNum<[18]>;
    def Y : CPU6Reg<19, "Y", [YU,YL]>, DwarfRegNum<[19]>;
    def Z : CPU6Reg<20, "Z", [ZU,ZL]>, DwarfRegNum<[20]>;
    def S : CPU6Reg<21, "S", [SU,SL]>, DwarfRegNum<[21]>;
    def C : CPU6Reg<22, "C", [CU,CL]>, DwarfRegNum<[22]>;
    def P : CPU6Reg<23, "P", [PU,PL]>, DwarfRegNum<[16]>;
}

// Define the classes of registers. This is to keep track of what registers should be used for what,
// and register restrictions should be enforced here

def GPR : RegisterClass<"CPU6", [i16], 8, (add A, B, X, Y, Z, S, C, P)>;

def GPRhi : RegisterClass<"CPU6", [i8], 8, (add AU, BU, XU, YU, ZU, SU, CU, PU)>;
def GPRlo : RegisterClass<"CPU6", [i8], 8, (add AL, BL, XL, YL, ZL, SL, CL, PL)>;


//TODO: Do I need to implement a pseudo register to keep track of F,L,M,V flags?
// -- from gecho
// FLMV are the flags (Overflow, Carry, Sign and Zero). 
// There are instructions that can manipulate them directly,
// but in the CPU4 you can only read them with the branch instructions.