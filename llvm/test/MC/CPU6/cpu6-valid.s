# RUN: llvm-mc %s -triple=cpu6 -show-encoding \
# RUN:     | FileCheck -check-prefixes=CHECK-ASM,CHECK-ASM-AND-OBJ %s
# RUN: llvm-mc %s -filetype=obj -triple=cpu6 < %s \
# RUN:      | llvm-objdump -d -r - \
# RUN:      | FileCheck --check-prefix=CHECK-ASM-AND-OBJ %s

# CHECK-ASM-AND-OBJ: HLT
# CHECK-ASM: encoding: [0x00]
HLT
# CHECK-ASM-AND-OBJ: NOP
# CHECK-ASM: encoding: [0x01]
NOP
# CHECK-ASM-AND-OBJ: SF
# CHECK-ASM: encoding: [0x02]
SF
# CHECK-ASM-AND-OBJ: RF
# CHECK-ASM: encoding: [0x03]
RF
# CHECK-ASM-AND-OBJ: EI
# CHECK-ASM: encoding: [0x04]
EI
# CHECK-ASM-AND-OBJ: DI
# CHECK-ASM: encoding: [0x05]
DI
# CHECK-ASM-AND-OBJ: SL
# CHECK-ASM: encoding: [0x06]
SL
# CHECK-ASM-AND-OBJ: RL
# CHECK-ASM: encoding: [0x07]
RL
# CHECK-ASM-AND-OBJ: CL
# CHECK-ASM: encoding: [0x08]
CL
# CHECK-ASM-AND-OBJ: RSR
# CHECK-ASM: encoding: [0x09]
RSR
# CHECK-ASM-AND-OBJ: RI
# CHECK-ASM: encoding: [0x0a]
RI
# CHECK-ASM-AND-OBJ: RIM
# CHECK-ASM: encoding: [0x0b]
RIM
# CHECK-ASM-AND-OBJ: ELO
# CHECK-ASM: encoding: [0x0c]
ELO
# CHECK-ASM-AND-OBJ: PCX
# CHECK-ASM: encoding: [0x0d]
PCX
# CHECK-ASM-AND-OBJ: DLY
# CHECK-ASM: encoding: [0x0e]
DLY
# CHECK-ASM-AND-OBJ: RSYS
# CHECK-ASM: encoding: [0x0f]
RSYS

# CHECK-ASM-AND-OBJ: BL 50
# CHECK-ASM: encoding: [0x10,0x32]
BL 50
# CHECK-ASM-AND-OBJ: BNL 50
# CHECK-ASM: encoding: [0x11,0x32]
BNL 50
# CHECK-ASM-AND-OBJ: BF 50
# CHECK-ASM: encoding: [0x12,0x32]
BF 50
# CHECK-ASM-AND-OBJ: BNF 50
# CHECK-ASM: encoding: [0x13,0x32]
BNF 50
# CHECK-ASM-AND-OBJ: BZ 50
# CHECK-ASM: encoding: [0x14,0x32]
BZ 50
# CHECK-ASM-AND-OBJ: BNZ 50
# CHECK-ASM: encoding: [0x15,0x32]
BNZ 50
# CHECK-ASM-AND-OBJ: BM 50
# CHECK-ASM: encoding: [0x16,0x32]
BM 50
# CHECK-ASM-AND-OBJ: BP 50
# CHECK-ASM: encoding: [0x17,0x32]
BP 50
# CHECK-ASM-AND-OBJ: BGZ 50
# CHECK-ASM: encoding: [0x18,0x32]
BGZ 50
# CHECK-ASM-AND-OBJ: BLE 50
# CHECK-ASM: encoding: [0x19,0x32]
BLE 50
# CHECK-ASM-AND-OBJ: BS1 50
# CHECK-ASM: encoding: [0x1a,0x32]
BS1 50
# CHECK-ASM-AND-OBJ: BS2 50
# CHECK-ASM: encoding: [0x1b,0x32]
BS2 50
# CHECK-ASM-AND-OBJ: BS3 50
# CHECK-ASM: encoding: [0x1c,0x32]
BS3 50
# CHECK-ASM-AND-OBJ: BS4 50
# CHECK-ASM: encoding: [0x1d,0x32]
BS4 50
# CHECK-ASM-AND-OBJ: BIE 50
# CHECK-ASM: encoding: [0x1e,0x32]
BIE 50
# CHECK-ASM-AND-OBJ: BEP 50
# CHECK-ASM: encoding: [0x1f,0x32]
BEP 50

# CHECK-ASM-AND-OBJ: INR B,5
# CHECK-ASM: encoding: [0x30,0x25]
INR B,5
# CHECK-ASM-AND-OBJ: INRB BU,5
# CHECK-ASM: encoding: [0x20,0x25]
INRB BU,5
# CHECK-ASM-AND-OBJ: DCR B,5
# CHECK-ASM: encoding: [0x31,0x25]
DCR B,5
# CHECK-ASM-AND-OBJ: DCRB BU,5
# CHECK-ASM: encoding: [0x21,0x25]
DCRB BU,5
# CHECK-ASM-AND-OBJ: CLR B
# CHECK-ASM: encoding: [0x32,0x20]
CLR B
# CHECK-ASM-AND-OBJ: CLRB BU
# CHECK-ASM: encoding: [0x22,0x20]
CLRB BU
# CHECK-ASM-AND-OBJ: IVR B
# CHECK-ASM: encoding: [0x33,0x20]
IVR B
# CHECK-ASM-AND-OBJ: IVRB BU
# CHECK-ASM: encoding: [0x23,0x20]
IVRB BU
# CHECK-ASM-AND-OBJ: SRR B,5
# CHECK-ASM: encoding: [0x34,0x25]
SRR B,5
# CHECK-ASM-AND-OBJ: SRRB BU,5
# CHECK-ASM: encoding: [0x24,0x25]
SRRB BU,5
# CHECK-ASM-AND-OBJ: SLR B,5
# CHECK-ASM: encoding: [0x35,0x25]
SLR B,5
# CHECK-ASM-AND-OBJ: SLRB BU,5
# CHECK-ASM: encoding: [0x25,0x25]
SLRB BU,5
# CHECK-ASM-AND-OBJ: RRR B,5
# CHECK-ASM: encoding: [0x36,0x25]
RRR B,5
# CHECK-ASM-AND-OBJ: RRRB BU,5
# CHECK-ASM: encoding: [0x26,0x25]
RRRB BU,5
# CHECK-ASM-AND-OBJ: RLR B,5
# CHECK-ASM: encoding: [0x37,0x25]
RLR B,5
# CHECK-ASM-AND-OBJ: RLRB BU,5
# CHECK-ASM: encoding: [0x27,0x25]
RLRB BU,5

# CHECK-ASM-AND-OBJ: INA
# CHECK-ASM: encoding: [0x38]
INA
# CHECK-ASM-AND-OBJ: INAB
# CHECK-ASM: encoding: [0x28]
INAB
# CHECK-ASM-AND-OBJ: DCA
# CHECK-ASM: encoding: [0x39]
DCA
# CHECK-ASM-AND-OBJ: DCAB
# CHECK-ASM: encoding: [0x29]
DCAB
# CHECK-ASM-AND-OBJ: CLA
# CHECK-ASM: encoding: [0x3a]
CLA
# CHECK-ASM-AND-OBJ: CLAB
# CHECK-ASM: encoding: [0x2a]
CLAB
# CHECK-ASM-AND-OBJ: IVA
# CHECK-ASM: encoding: [0x3b]
IVA
# CHECK-ASM-AND-OBJ: IVAB
# CHECK-ASM: encoding: [0x2b]
IVAB
# CHECK-ASM-AND-OBJ: SRA
# CHECK-ASM: encoding: [0x3c]
SRA
# CHECK-ASM-AND-OBJ: SRAB
# CHECK-ASM: encoding: [0x2c]
SRAB
# CHECK-ASM-AND-OBJ: SLA
# CHECK-ASM: encoding: [0x3d]
SLA
# CHECK-ASM-AND-OBJ: SLAB
# CHECK-ASM: encoding: [0x2d]
SLAB
# CHECK-ASM-AND-OBJ: INX
# CHECK-ASM: encoding: [0x3e]
INX
# CHECK-ASM-AND-OBJ: DNX
# CHECK-ASM: encoding: [0x3f]
DNX

# CHECK-ASM-AND-OBJ: ADD B,X
# CHECK-ASM: encoding: [0x50,0x24]
ADD B,X
# CHECK-ASM-AND-OBJ: ADDB BU,XU
# CHECK-ASM: encoding: [0x40,0x24]
ADDB BU,XU
# CHECK-ASM-AND-OBJ: SUB B,X
# CHECK-ASM: encoding: [0x51,0x24]
SUB B,X
# CHECK-ASM-AND-OBJ: SUBB BU,XU
# CHECK-ASM: encoding: [0x41,0x24]
SUBB BU,XU
# CHECK-ASM-AND-OBJ: AND B,X
# CHECK-ASM: encoding: [0x52,0x24]
AND B,X
# CHECK-ASM-AND-OBJ: ANDB BU,XU
# CHECK-ASM: encoding: [0x42,0x24]
ANDB BU,XU
# CHECK-ASM-AND-OBJ: ORI B,X
# CHECK-ASM: encoding: [0x53,0x24]
ORI B,X
# CHECK-ASM-AND-OBJ: ORIB BU,XU
# CHECK-ASM: encoding: [0x43,0x24]
ORIB BU,XU
# CHECK-ASM-AND-OBJ: ORE B,X
# CHECK-ASM: encoding: [0x54,0x24]
ORE B,X
# CHECK-ASM-AND-OBJ: OREB BU,XU
# CHECK-ASM: encoding: [0x44,0x24]
OREB BU,XU
# CHECK-ASM-AND-OBJ: XFR B,X
# CHECK-ASM: encoding: [0x55,0x24]
XFR B,X
# CHECK-ASM-AND-OBJ: XFRB BU,XU
# CHECK-ASM: encoding: [0x45,0x24]
XFRB BU,XU

# CHECK-ASM-AND-OBJ: AAB
# CHECK-ASM: encoding: [0x58]
AAB
# CHECK-ASM-AND-OBJ: AABB
# CHECK-ASM: encoding: [0x48]
AABB
# CHECK-ASM-AND-OBJ: SAB
# CHECK-ASM: encoding: [0x59]
SAB
# CHECK-ASM-AND-OBJ: SABB
# CHECK-ASM: encoding: [0x49]
SABB
# CHECK-ASM-AND-OBJ: NAB
# CHECK-ASM: encoding: [0x5a]
NAB
# CHECK-ASM-AND-OBJ: NABB
# CHECK-ASM: encoding: [0x4a]
NABB
# CHECK-ASM-AND-OBJ: XAX
# CHECK-ASM: encoding: [0x5b]
XAX
# CHECK-ASM-AND-OBJ: XAXB
# CHECK-ASM: encoding: [0x4b]
XAXB
# CHECK-ASM-AND-OBJ: XAY
# CHECK-ASM: encoding: [0x5c]
XAY
# CHECK-ASM-AND-OBJ: XAYB
# CHECK-ASM: encoding: [0x4c]
XAYB
# CHECK-ASM-AND-OBJ: XAB
# CHECK-ASM: encoding: [0x5d]
XAB
# CHECK-ASM-AND-OBJ: XABB
# CHECK-ASM: encoding: [0x4d]
XABB
# CHECK-ASM-AND-OBJ: XAZ
# CHECK-ASM: encoding: [0x5e]
XAZ
# CHECK-ASM-AND-OBJ: XAZB
# CHECK-ASM: encoding: [0x4e]
XAZB
# CHECK-ASM-AND-OBJ: XAS
# CHECK-ASM: encoding: [0x5f]
XAS
# CHECK-ASM-AND-OBJ: XASB
# CHECK-ASM: encoding: [0x4f]
XASB

# CHECK-ASM-AND-OBJ: LDA 48879
# CHECK-ASM: encoding: [0x90,0xbe,0xef]
LDA 48879
# CHECK-ASM-AND-OBJ: LDAB 48879
# CHECK-ASM: encoding: [0x80,0xbe,0xef]
LDAB 48879
# CHECK-ASM-AND-OBJ: LDA (48879)
# CHECK-ASM: encoding: [0x91,0xbe,0xef]
LDA (48879)
# CHECK-ASM-AND-OBJ: LDAB (48879)
# CHECK-ASM: encoding: [0x81,0xbe,0xef]
LDAB (48879)
# CHECK-ASM-AND-OBJ: LDA ((48879))
# CHECK-ASM: encoding: [0x92,0xbe,0xef]
LDA ((48879))
# CHECK-ASM-AND-OBJ: LDAB ((48879))
# CHECK-ASM: encoding: [0x82,0xbe,0xef]
LDAB ((48879))
# CHECK-ASM-AND-OBJ: LDA (PC),205
# CHECK-ASM: encoding: [0x93,0xcd]
LDA (PC),205
# CHECK-ASM-AND-OBJ: LDAB (PC),205
# CHECK-ASM: encoding: [0x83,0xcd]
LDAB (PC),205
# CHECK-ASM-AND-OBJ: LDA ((PC),205)
# CHECK-ASM: encoding: [0x94,0xcd]
LDA ((PC),205)
# CHECK-ASM-AND-OBJ: LDAB ((PC),205)
# CHECK-ASM: encoding: [0x84,0xcd]
LDAB ((PC),205)
# CHECK-ASM-AND-OBJ: LDA (X)
# CHECK-ASM: encoding: [0x95,0x40]
LDA (X)
# CHECK-ASM-AND-OBJ: LDAB (XU)
# CHECK-ASM: encoding: [0x85,0x40]
LDAB (XU)
# CHECK-ASM-AND-OBJ: LDA_I (X)
# CHECK-ASM: encoding: [0x95,0x41]
LDA_I (X)
# CHECK-ASM-AND-OBJ: LDAB_I (XU)
# CHECK-ASM: encoding: [0x85,0x41]
LDAB_I (XU)
# CHECK-ASM-AND-OBJ: LDA_D (X)
# CHECK-ASM: encoding: [0x95,0x42]
LDA_D (X)
# CHECK-ASM-AND-OBJ: LDAB_D (XU)
# CHECK-ASM: encoding: [0x85,0x42]
LDAB_D (XU)

# CHECK-ASM-AND-OBJ: LDA ((X))
# CHECK-ASM: encoding: [0x95,0x44]
LDA ((X))
# CHECK-ASM-AND-OBJ: LDAB ((XU))
# CHECK-ASM: encoding: [0x85,0x44]
LDAB ((XU))
# CHECK-ASM-AND-OBJ: LDA_I ((X))
# CHECK-ASM: encoding: [0x95,0x45]
LDA_I ((X))
# CHECK-ASM-AND-OBJ: LDAB_I ((XU))
# CHECK-ASM: encoding: [0x85,0x45]
LDAB_I ((XU))
# CHECK-ASM-AND-OBJ: LDA_D ((X))
# CHECK-ASM: encoding: [0x95,0x46]
LDA_D ((X))
# CHECK-ASM-AND-OBJ: LDAB_D ((XU))
# CHECK-ASM: encoding: [0x85,0x46]
LDAB_D ((XU))

# CHECK-ASM-AND-OBJ: LDA (X),21
# CHECK-ASM: encoding: [0x95,0x48,0x15]
LDA (X),21
# CHECK-ASM-AND-OBJ: LDAB (XU),21
# CHECK-ASM: encoding: [0x85,0x48,0x15]
LDAB (XU),21
# CHECK-ASM-AND-OBJ: LDA_I (X),21
# CHECK-ASM: encoding: [0x95,0x49,0x15]
LDA_I (X),21
# CHECK-ASM-AND-OBJ: LDAB_I (XU),21
# CHECK-ASM: encoding: [0x85,0x49,0x15]
LDAB_I (XU),21
# CHECK-ASM-AND-OBJ: LDA_D (X),21
# CHECK-ASM: encoding: [0x95,0x4a,0x15]
LDA_D (X),21
# CHECK-ASM-AND-OBJ: LDAB_D (XU),21
# CHECK-ASM: encoding: [0x85,0x4a,0x15]
LDAB_D (XU),21

# CHECK-ASM-AND-OBJ: LDA_? (X),21
# CHECK-ASM: encoding: [0x95,0x4c,0x15]
LDA_? (X),21
# CHECK-ASM-AND-OBJ: LDAB_? (XU),21
# CHECK-ASM: encoding: [0x85,0x4c,0x15]
LDAB_? (XU),21
# CHECK-ASM-AND-OBJ: LDA_I ((X)),21
# CHECK-ASM: encoding: [0x95,0x4d,0x15]
LDA_I ((X)),21
# CHECK-ASM-AND-OBJ: LDAB_I ((XU)),21
# CHECK-ASM: encoding: [0x85,0x4d,0x15]
LDAB_I ((XU)),21
# CHECK-ASM-AND-OBJ: LDA_D ((X)),21
# CHECK-ASM: encoding: [0x95,0x4e,0x15]
LDA_D ((X)),21
# CHECK-ASM-AND-OBJ: LDAB_D ((XU)),21
# CHECK-ASM: encoding: [0x85,0x4e,0x15]
LDAB_D ((XU)),21

# CHECK-ASM-AND-OBJ: LDA_A
# CHECK-ASM: encoding: [0x98]
LDA_A
# CHECK-ASM-AND-OBJ: LDAB_A
# CHECK-ASM: encoding: [0x88]
LDAB_A
# CHECK-ASM-AND-OBJ: LDA_B
# CHECK-ASM: encoding: [0x99]
LDA_B
# CHECK-ASM-AND-OBJ: LDAB_B
# CHECK-ASM: encoding: [0x89]
LDAB_B
# CHECK-ASM-AND-OBJ: LDA_X
# CHECK-ASM: encoding: [0x9a]
LDA_X
# CHECK-ASM-AND-OBJ: LDAB_X
# CHECK-ASM: encoding: [0x8a]
LDAB_X
# CHECK-ASM-AND-OBJ: LDA_Y
# CHECK-ASM: encoding: [0x9b]
LDA_Y
# CHECK-ASM-AND-OBJ: LDAB_Y
# CHECK-ASM: encoding: [0x8b]
LDAB_Y
# CHECK-ASM-AND-OBJ: LDA_Z
# CHECK-ASM: encoding: [0x9c]
LDA_Z
# CHECK-ASM-AND-OBJ: LDAB_Z
# CHECK-ASM: encoding: [0x8c]
LDAB_Z
# CHECK-ASM-AND-OBJ: LDA_S
# CHECK-ASM: encoding: [0x9d]
LDA_S
# CHECK-ASM-AND-OBJ: LDAB_S
# CHECK-ASM: encoding: [0x8d]
LDAB_S
# CHECK-ASM-AND-OBJ: LDA_C
# CHECK-ASM: encoding: [0x9e]
LDA_C
# CHECK-ASM-AND-OBJ: LDAB_C
# CHECK-ASM: encoding: [0x8e]
LDAB_C
# CHECK-ASM-AND-OBJ: LDA_P
# CHECK-ASM: encoding: [0x9f]
LDA_P
# CHECK-ASM-AND-OBJ: LDAB_P
# CHECK-ASM: encoding: [0x8f]
LDAB_P

# CHECK-ASM-AND-OBJ: LDX (48879)
# CHECK-ASM: encoding: [0x61,0xbe,0xef]
LDX (48879)
# CHECK-ASM-AND-OBJ: LDX ((48879))
# CHECK-ASM: encoding: [0x62,0xbe,0xef]
LDX ((48879))
# CHECK-ASM-AND-OBJ: LDX (PC),10
# CHECK-ASM: encoding: [0x63,0x0a]
LDX (PC),10
# CHECK-ASM-AND-OBJ: LDX ((PC),10)
# CHECK-ASM: encoding: [0x64,0x0a]
LDX ((PC),10)
# CHECK-ASM-AND-OBJ: LDX (X)
# CHECK-ASM: encoding: [0x65,0x40]
LDX (X)
# CHECK-ASM-AND-OBJ: LDX_I (X)
# CHECK-ASM: encoding: [0x65,0x41]
LDX_I (X)
# CHECK-ASM-AND-OBJ: LDX_D (X)
# CHECK-ASM: encoding: [0x65,0x42]
LDX_D (X)
# CHECK-ASM-AND-OBJ: LDX ((X))
# CHECK-ASM: encoding: [0x65,0x44]
LDX ((X))
# CHECK-ASM-AND-OBJ: LDX_I ((X))
# CHECK-ASM: encoding: [0x65,0x45]
LDX_I ((X))
# CHECK-ASM-AND-OBJ: LDX_D ((X))
# CHECK-ASM: encoding: [0x65,0x46]
LDX_D ((X))
# CHECK-ASM-AND-OBJ: LDX (X),10
# CHECK-ASM: encoding: [0x65,0x48,0x0a]
LDX (X),10
# CHECK-ASM-AND-OBJ: LDX_I (X),10
# CHECK-ASM: encoding: [0x65,0x49,0x0a]
LDX_I (X),10
# CHECK-ASM-AND-OBJ: LDX_D (X),10
# CHECK-ASM: encoding: [0x65,0x4a,0x0a]
LDX_D (X),10
# CHECK-ASM-AND-OBJ: LDX_? (X),10
# CHECK-ASM: encoding: [0x65,0x4c,0x0a]
LDX_? (X),10
# CHECK-ASM-AND-OBJ: LDX_I ((X)),10
# CHECK-ASM: encoding: [0x65,0x4d,0x0a]
LDX_I ((X)),10
# CHECK-ASM-AND-OBJ: LDX_D ((X)),10
# CHECK-ASM: encoding: [0x65,0x4e,0x0a]
LDX_D ((X)),10