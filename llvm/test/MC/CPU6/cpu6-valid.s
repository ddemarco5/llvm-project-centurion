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
# CHECK-ASM-AND-OBJ: SYN
# CHECK-ASM: encoding: [0x0c]
SYN
# CHECK-ASM-AND-OBJ: PCX
# CHECK-ASM: encoding: [0x0d]
PCX
# CHECK-ASM-AND-OBJ: DLY
# CHECK-ASM: encoding: [0x0e]
DLY
# CHECK-ASM-AND-OBJ: RSV
# CHECK-ASM: encoding: [0x0f]
RSV

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
# CHECK-ASM-AND-OBJ: BI 50
# CHECK-ASM: encoding: [0x1e,0x32]
BI 50
# CHECK-ASM-AND-OBJ: BCK 50
# CHECK-ASM: encoding: [0x1f,0x32]
BCK 50

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
# CHECK-ASM-AND-OBJ: CLR B,0
# CHECK-ASM: encoding: [0x32,0x20]
CLR B,0
# CHECK-ASM-AND-OBJ: CLRB BU,0
# CHECK-ASM: encoding: [0x22,0x20]
CLRB BU,0
# CHECK-ASM-AND-OBJ: IVR B,0
# CHECK-ASM: encoding: [0x33,0x20]
IVR B,0
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
# CHECK-ASM-AND-OBJ: DCX
# CHECK-ASM: encoding: [0x3f]
DCX

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
# CHECK-ASM-AND-OBJ: LDAB 241
# CHECK-ASM: encoding: [0x80,0xf1]
LDAB 241
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
# CHECK-ASM-AND-OBJ: LDAB (X)
# CHECK-ASM: encoding: [0x85,0x40]
LDAB (X)
# CHECK-ASM-AND-OBJ: LDA_I (X)
# CHECK-ASM: encoding: [0x95,0x41]
LDA_I (X)
# CHECK-ASM-AND-OBJ: LDAB_I (X)
# CHECK-ASM: encoding: [0x85,0x41]
LDAB_I (X)
# CHECK-ASM-AND-OBJ: LDA_D (X)
# CHECK-ASM: encoding: [0x95,0x42]
LDA_D (X)
# CHECK-ASM-AND-OBJ: LDAB_D (X)
# CHECK-ASM: encoding: [0x85,0x42]
LDAB_D (X)

# CHECK-ASM-AND-OBJ: LDA ((X))
# CHECK-ASM: encoding: [0x95,0x44]
LDA ((X))
# CHECK-ASM-AND-OBJ: LDAB ((X))
# CHECK-ASM: encoding: [0x85,0x44]
LDAB ((X))
# CHECK-ASM-AND-OBJ: LDA_I ((X))
# CHECK-ASM: encoding: [0x95,0x45]
LDA_I ((X))
# CHECK-ASM-AND-OBJ: LDAB_I ((X))
# CHECK-ASM: encoding: [0x85,0x45]
LDAB_I ((X))
# CHECK-ASM-AND-OBJ: LDA_D ((X))
# CHECK-ASM: encoding: [0x95,0x46]
LDA_D ((X))
# CHECK-ASM-AND-OBJ: LDAB_D ((X))
# CHECK-ASM: encoding: [0x85,0x46]
LDAB_D ((X))

# CHECK-ASM-AND-OBJ: LDA (X),21
# CHECK-ASM: encoding: [0x95,0x48,0x15]
LDA (X),21
# CHECK-ASM-AND-OBJ: LDAB (X),21
# CHECK-ASM: encoding: [0x85,0x48,0x15]
LDAB (X),21
# CHECK-ASM-AND-OBJ: LDA_I (X),21
# CHECK-ASM: encoding: [0x95,0x49,0x15]
LDA_I (X),21
# CHECK-ASM-AND-OBJ: LDAB_I (X),21
# CHECK-ASM: encoding: [0x85,0x49,0x15]
LDAB_I (X),21
# CHECK-ASM-AND-OBJ: LDA_D (X),21
# CHECK-ASM: encoding: [0x95,0x4a,0x15]
LDA_D (X),21
# CHECK-ASM-AND-OBJ: LDAB_D (X),21
# CHECK-ASM: encoding: [0x85,0x4a,0x15]
LDAB_D (X),21

# CHECK-ASM-AND-OBJ: LDA_? (X),21
# CHECK-ASM: encoding: [0x95,0x4c,0x15]
LDA_? (X),21
# CHECK-ASM-AND-OBJ: LDAB_? (X),21
# CHECK-ASM: encoding: [0x85,0x4c,0x15]
LDAB_? (X),21
# CHECK-ASM-AND-OBJ: LDA_I ((X)),21
# CHECK-ASM: encoding: [0x95,0x4d,0x15]
LDA_I ((X)),21
# CHECK-ASM-AND-OBJ: LDAB_I ((X)),21
# CHECK-ASM: encoding: [0x85,0x4d,0x15]
LDAB_I ((X)),21
# CHECK-ASM-AND-OBJ: LDA_D ((X)),21
# CHECK-ASM: encoding: [0x95,0x4e,0x15]
LDA_D ((X)),21
# CHECK-ASM-AND-OBJ: LDAB_D ((X)),21
# CHECK-ASM: encoding: [0x85,0x4e,0x15]
LDAB_D ((X)),21

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

# CHECK-ASM-AND-OBJ: SVC 16
# CHECK-ASM: encoding: [0x66,0x10]
SVC 16

# CHECK-ASM-AND-OBJ: SAD X
# CHECK-ASM: encoding: [0x2f,0x40]
SAD X
# CHECK-ASM-AND-OBJ: SDV 0
# CHECK-ASM: encoding: [0x2f,0x04]
SDV 0

# CHECK-ASM-AND-OBJ: STA 48879
# CHECK-ASM: encoding: [0xb0,0xbe,0xef]
STA 48879
# CHECK-ASM-AND-OBJ: STAB 0
# CHECK-ASM: encoding: [0xa0,0x00]
STAB 0
# CHECK-ASM-AND-OBJ: STA (48879)
# CHECK-ASM: encoding: [0xb1,0xbe,0xef]
STA (48879)
# CHECK-ASM-AND-OBJ: STAB (48879)
# CHECK-ASM: encoding: [0xa1,0xbe,0xef]
STAB (48879)
# CHECK-ASM-AND-OBJ: STA ((48879))
# CHECK-ASM: encoding: [0xb2,0xbe,0xef]
STA ((48879))
# CHECK-ASM-AND-OBJ: STAB ((48879))
# CHECK-ASM: encoding: [0xa2,0xbe,0xef]
STAB ((48879))

# CHECK-ASM-AND-OBJ: STA (PC),205
# CHECK-ASM: encoding: [0xb3,0xcd]
STA (PC),205
# CHECK-ASM-AND-OBJ: STAB (PC),205
# CHECK-ASM: encoding: [0xa3,0xcd]
STAB (PC),205
# CHECK-ASM-AND-OBJ: STA ((PC),205)
# CHECK-ASM: encoding: [0xb4,0xcd]
STA ((PC),205)
# CHECK-ASM-AND-OBJ: STAB ((PC),205)
# CHECK-ASM: encoding: [0xa4,0xcd]
STAB ((PC),205)

# CHECK-ASM-AND-OBJ: STA (X)
# CHECK-ASM: encoding: [0xb5,0x40]
STA (X)
# CHECK-ASM-AND-OBJ: STAB (X)
# CHECK-ASM: encoding: [0xa5,0x40]
STAB (X)
# CHECK-ASM-AND-OBJ: STA_I (X)
# CHECK-ASM: encoding: [0xb5,0x41]
STA_I (X)
# CHECK-ASM-AND-OBJ: STAB_I (X)
# CHECK-ASM: encoding: [0xa5,0x41]
STAB_I (X)
# CHECK-ASM-AND-OBJ: STA_D (X)
# CHECK-ASM: encoding: [0xb5,0x42]
STA_D (X)
# CHECK-ASM-AND-OBJ: STAB_D (X)
# CHECK-ASM: encoding: [0xa5,0x42]
STAB_D (X)

# CHECK-ASM-AND-OBJ: STA ((X))
# CHECK-ASM: encoding: [0xb5,0x44]
STA ((X))
# CHECK-ASM-AND-OBJ: STAB ((X))
# CHECK-ASM: encoding: [0xa5,0x44]
STAB ((X))
# CHECK-ASM-AND-OBJ: STA_I ((X))
# CHECK-ASM: encoding: [0xb5,0x45]
STA_I ((X))
# CHECK-ASM-AND-OBJ: STAB_I ((X))
# CHECK-ASM: encoding: [0xa5,0x45]
STAB_I ((X))
# CHECK-ASM-AND-OBJ: STA_D ((X))
# CHECK-ASM: encoding: [0xb5,0x46]
STA_D ((X))
# CHECK-ASM-AND-OBJ: STAB_D ((X))
# CHECK-ASM: encoding: [0xa5,0x46]
STAB_D ((X))

# CHECK-ASM-AND-OBJ: STA (X),21
# CHECK-ASM: encoding: [0xb5,0x48,0x15]
STA (X),21
# CHECK-ASM-AND-OBJ: STAB (X),21
# CHECK-ASM: encoding: [0xa5,0x48,0x15]
STAB (X),21
# CHECK-ASM-AND-OBJ: STA_I (X),21
# CHECK-ASM: encoding: [0xb5,0x49,0x15]
STA_I (X),21
# CHECK-ASM-AND-OBJ: STAB_I (X),21
# CHECK-ASM: encoding: [0xa5,0x49,0x15]
STAB_I (X),21
# CHECK-ASM-AND-OBJ: STA_D (X),21
# CHECK-ASM: encoding: [0xb5,0x4a,0x15]
STA_D (X),21
# CHECK-ASM-AND-OBJ: STAB_D (X),21
# CHECK-ASM: encoding: [0xa5,0x4a,0x15]
STAB_D (X),21

# CHECK-ASM-AND-OBJ: STA_? (X),21
# CHECK-ASM: encoding: [0xb5,0x4c,0x15]
STA_? (X),21
# CHECK-ASM-AND-OBJ: STAB_? (X),21
# CHECK-ASM: encoding: [0xa5,0x4c,0x15]
STAB_? (X),21
# CHECK-ASM-AND-OBJ: STA_I ((X)),21
# CHECK-ASM: encoding: [0xb5,0x4d,0x15]
STA_I ((X)),21
# CHECK-ASM-AND-OBJ: STAB_I ((X)),21
# CHECK-ASM: encoding: [0xa5,0x4d,0x15]
STAB_I ((X)),21
# CHECK-ASM-AND-OBJ: STA_D ((X)),21
# CHECK-ASM: encoding: [0xb5,0x4e,0x15]
STA_D ((X)),21
# CHECK-ASM-AND-OBJ: STAB_D ((X)),21
# CHECK-ASM: encoding: [0xa5,0x4e,0x15]
STAB_D ((X)),21

# CHECK-ASM-AND-OBJ: STA_A
# CHECK-ASM: encoding: [0xb8]
STA_A
# CHECK-ASM-AND-OBJ: STAB_A
# CHECK-ASM: encoding: [0xa8]
STAB_A
# CHECK-ASM-AND-OBJ: STA_B
# CHECK-ASM: encoding: [0xb9]
STA_B
# CHECK-ASM-AND-OBJ: STAB_B
# CHECK-ASM: encoding: [0xa9]
STAB_B
# CHECK-ASM-AND-OBJ: STA_X
# CHECK-ASM: encoding: [0xba]
STA_X
# CHECK-ASM-AND-OBJ: STAB_X
# CHECK-ASM: encoding: [0xaa]
STAB_X
# CHECK-ASM-AND-OBJ: STA_Y
# CHECK-ASM: encoding: [0xbb]
STA_Y
# CHECK-ASM-AND-OBJ: STAB_Y
# CHECK-ASM: encoding: [0xab]
STAB_Y
# CHECK-ASM-AND-OBJ: STA_Z
# CHECK-ASM: encoding: [0xbc]
STA_Z
# CHECK-ASM-AND-OBJ: STAB_Z
# CHECK-ASM: encoding: [0xac]
STAB_Z
# CHECK-ASM-AND-OBJ: STA_S
# CHECK-ASM: encoding: [0xbd]
STA_S
# CHECK-ASM-AND-OBJ: STAB_S
# CHECK-ASM: encoding: [0xad]
STAB_S
# CHECK-ASM-AND-OBJ: STA_C
# CHECK-ASM: encoding: [0xbe]
STA_C
# CHECK-ASM-AND-OBJ: STAB_C
# CHECK-ASM: encoding: [0xae]
STAB_C
# CHECK-ASM-AND-OBJ: STA_P
# CHECK-ASM: encoding: [0xbf]
STA_P
# CHECK-ASM-AND-OBJ: STAB_P
# CHECK-ASM: encoding: [0xaf]
STAB_P

# CHECK-ASM-AND-OBJ: LDB 48879
# CHECK-ASM: encoding: [0xd0,0xbe,0xef]
LDB 48879
# CHECK-ASM-AND-OBJ: LDBB 3
# CHECK-ASM: encoding: [0xc0,0x03]
LDBB 3
# CHECK-ASM-AND-OBJ: LDB (48879)
# CHECK-ASM: encoding: [0xd1,0xbe,0xef]
LDB (48879)
# CHECK-ASM-AND-OBJ: LDBB (48879)
# CHECK-ASM: encoding: [0xc1,0xbe,0xef]
LDBB (48879)
# CHECK-ASM-AND-OBJ: LDB ((48879))
# CHECK-ASM: encoding: [0xd2,0xbe,0xef]
LDB ((48879))
# CHECK-ASM-AND-OBJ: LDBB ((48879))
# CHECK-ASM: encoding: [0xc2,0xbe,0xef]
LDBB ((48879))

# CHECK-ASM-AND-OBJ: LDB (PC),205
# CHECK-ASM: encoding: [0xd3,0xcd]
LDB (PC),205
# CHECK-ASM-AND-OBJ: LDBB (PC),205
# CHECK-ASM: encoding: [0xc3,0xcd]
LDBB (PC),205
# CHECK-ASM-AND-OBJ: LDB ((PC),205)
# CHECK-ASM: encoding: [0xd4,0xcd]
LDB ((PC),205)
# CHECK-ASM-AND-OBJ: LDBB ((PC),205)
# CHECK-ASM: encoding: [0xc4,0xcd]
LDBB ((PC),205)

# CHECK-ASM-AND-OBJ: LDB (X)
# CHECK-ASM: encoding: [0xd5,0x40]
LDB (X)
# CHECK-ASM-AND-OBJ: LDBB (X)
# CHECK-ASM: encoding: [0xc5,0x40]
LDBB (X)
# CHECK-ASM-AND-OBJ: LDB_I (X)
# CHECK-ASM: encoding: [0xd5,0x41]
LDB_I (X)
# CHECK-ASM-AND-OBJ: LDBB_I (X)
# CHECK-ASM: encoding: [0xc5,0x41]
LDBB_I (X)
# CHECK-ASM-AND-OBJ: LDB_D (X)
# CHECK-ASM: encoding: [0xd5,0x42]
LDB_D (X)
# CHECK-ASM-AND-OBJ: LDBB_D (X)
# CHECK-ASM: encoding: [0xc5,0x42]
LDBB_D (X)

# CHECK-ASM-AND-OBJ: LDB ((X))
# CHECK-ASM: encoding: [0xd5,0x44]
LDB ((X))
# CHECK-ASM-AND-OBJ: LDBB ((X))
# CHECK-ASM: encoding: [0xc5,0x44]
LDBB ((X))
# CHECK-ASM-AND-OBJ: LDB_I ((X))
# CHECK-ASM: encoding: [0xd5,0x45]
LDB_I ((X))
# CHECK-ASM-AND-OBJ: LDBB_I ((X))
# CHECK-ASM: encoding: [0xc5,0x45]
LDBB_I ((X))
# CHECK-ASM-AND-OBJ: LDB_D ((X))
# CHECK-ASM: encoding: [0xd5,0x46]
LDB_D ((X))
# CHECK-ASM-AND-OBJ: LDBB_D ((X))
# CHECK-ASM: encoding: [0xc5,0x46]
LDBB_D ((X))

# CHECK-ASM-AND-OBJ: LDB (X),21
# CHECK-ASM: encoding: [0xd5,0x48,0x15]
LDB (X),21
# CHECK-ASM-AND-OBJ: LDBB (X),21
# CHECK-ASM: encoding: [0xc5,0x48,0x15]
LDBB (X),21
# CHECK-ASM-AND-OBJ: LDB_I (X),21
# CHECK-ASM: encoding: [0xd5,0x49,0x15]
LDB_I (X),21
# CHECK-ASM-AND-OBJ: LDBB_I (X),21
# CHECK-ASM: encoding: [0xc5,0x49,0x15]
LDBB_I (X),21
# CHECK-ASM-AND-OBJ: LDB_D (X),21
# CHECK-ASM: encoding: [0xd5,0x4a,0x15]
LDB_D (X),21
# CHECK-ASM-AND-OBJ: LDBB_D (X),21
# CHECK-ASM: encoding: [0xc5,0x4a,0x15]
LDBB_D (X),21

# CHECK-ASM-AND-OBJ: LDB_? (X),21
# CHECK-ASM: encoding: [0xd5,0x4c,0x15]
LDB_? (X),21
# CHECK-ASM-AND-OBJ: LDBB_? (X),21
# CHECK-ASM: encoding: [0xc5,0x4c,0x15]
LDBB_? (X),21
# CHECK-ASM-AND-OBJ: LDB_I ((X)),21
# CHECK-ASM: encoding: [0xd5,0x4d,0x15]
LDB_I ((X)),21
# CHECK-ASM-AND-OBJ: LDBB_I ((X)),21
# CHECK-ASM: encoding: [0xc5,0x4d,0x15]
LDBB_I ((X)),21
# CHECK-ASM-AND-OBJ: LDB_D ((X)),21
# CHECK-ASM: encoding: [0xd5,0x4e,0x15]
LDB_D ((X)),21
# CHECK-ASM-AND-OBJ: LDBB_D ((X)),21
# CHECK-ASM: encoding: [0xc5,0x4e,0x15]
LDBB_D ((X)),21

# CHECK-ASM-AND-OBJ: LDB_A
# CHECK-ASM: encoding: [0xd8]
LDB_A
# CHECK-ASM-AND-OBJ: LDBB_A
# CHECK-ASM: encoding: [0xc8]
LDBB_A
# CHECK-ASM-AND-OBJ: LDB_B
# CHECK-ASM: encoding: [0xd9]
LDB_B
# CHECK-ASM-AND-OBJ: LDBB_B
# CHECK-ASM: encoding: [0xc9]
LDBB_B
# CHECK-ASM-AND-OBJ: LDB_X
# CHECK-ASM: encoding: [0xda]
LDB_X
# CHECK-ASM-AND-OBJ: LDBB_X
# CHECK-ASM: encoding: [0xca]
LDBB_X
# CHECK-ASM-AND-OBJ: LDB_Y
# CHECK-ASM: encoding: [0xdb]
LDB_Y
# CHECK-ASM-AND-OBJ: LDBB_Y
# CHECK-ASM: encoding: [0xcb]
LDBB_Y
# CHECK-ASM-AND-OBJ: LDB_Z
# CHECK-ASM: encoding: [0xdc]
LDB_Z
# CHECK-ASM-AND-OBJ: LDBB_Z
# CHECK-ASM: encoding: [0xcc]
LDBB_Z
# CHECK-ASM-AND-OBJ: LDB_S
# CHECK-ASM: encoding: [0xdd]
LDB_S
# CHECK-ASM-AND-OBJ: LDBB_S
# CHECK-ASM: encoding: [0xcd]
LDBB_S
# CHECK-ASM-AND-OBJ: LDB_C
# CHECK-ASM: encoding: [0xde]
LDB_C
# CHECK-ASM-AND-OBJ: LDBB_C
# CHECK-ASM: encoding: [0xce]
LDBB_C
# CHECK-ASM-AND-OBJ: LDB_P
# CHECK-ASM: encoding: [0xdf]
LDB_P
# CHECK-ASM-AND-OBJ: LDBB_P
# CHECK-ASM: encoding: [0xcf]
LDBB_P

# CHECK-ASM-AND-OBJ: STB 48879
# CHECK-ASM: encoding: [0xf0,0xbe,0xef]
STB 48879
# CHECK-ASM-AND-OBJ: STBB 0
# CHECK-ASM: encoding: [0xe0,0x00]
STBB 0
# CHECK-ASM-AND-OBJ: STB (48879)
# CHECK-ASM: encoding: [0xf1,0xbe,0xef]
STB (48879)
# CHECK-ASM-AND-OBJ: STBB (48879)
# CHECK-ASM: encoding: [0xe1,0xbe,0xef]
STBB (48879)
# CHECK-ASM-AND-OBJ: STB ((48879))
# CHECK-ASM: encoding: [0xf2,0xbe,0xef]
STB ((48879))
# CHECK-ASM-AND-OBJ: STBB ((48879))
# CHECK-ASM: encoding: [0xe2,0xbe,0xef]
STBB ((48879))

# CHECK-ASM-AND-OBJ: STB (PC),205
# CHECK-ASM: encoding: [0xf3,0xcd]
STB (PC),205
# CHECK-ASM-AND-OBJ: STBB (PC),205
# CHECK-ASM: encoding: [0xe3,0xcd]
STBB (PC),205
# CHECK-ASM-AND-OBJ: STB ((PC),205)
# CHECK-ASM: encoding: [0xf4,0xcd]
STB ((PC),205)
# CHECK-ASM-AND-OBJ: STBB ((PC),205)
# CHECK-ASM: encoding: [0xe4,0xcd]
STBB ((PC),205)

# CHECK-ASM-AND-OBJ: STB (X)
# CHECK-ASM: encoding: [0xf5,0x40]
STB (X)
# CHECK-ASM-AND-OBJ: STBB (X)
# CHECK-ASM: encoding: [0xe5,0x40]
STBB (X)
# CHECK-ASM-AND-OBJ: STB_I (X)
# CHECK-ASM: encoding: [0xf5,0x41]
STB_I (X)
# CHECK-ASM-AND-OBJ: STBB_I (X)
# CHECK-ASM: encoding: [0xe5,0x41]
STBB_I (X)
# CHECK-ASM-AND-OBJ: STB_D (X)
# CHECK-ASM: encoding: [0xf5,0x42]
STB_D (X)
# CHECK-ASM-AND-OBJ: STBB_D (X)
# CHECK-ASM: encoding: [0xe5,0x42]
STBB_D (X)

# CHECK-ASM-AND-OBJ: STB ((X))
# CHECK-ASM: encoding: [0xf5,0x44]
STB ((X))
# CHECK-ASM-AND-OBJ: STBB ((X))
# CHECK-ASM: encoding: [0xe5,0x44]
STBB ((X))
# CHECK-ASM-AND-OBJ: STB_I ((X))
# CHECK-ASM: encoding: [0xf5,0x45]
STB_I ((X))
# CHECK-ASM-AND-OBJ: STBB_I ((X))
# CHECK-ASM: encoding: [0xe5,0x45]
STBB_I ((X))
# CHECK-ASM-AND-OBJ: STB_D ((X))
# CHECK-ASM: encoding: [0xf5,0x46]
STB_D ((X))
# CHECK-ASM-AND-OBJ: STBB_D ((X))
# CHECK-ASM: encoding: [0xe5,0x46]
STBB_D ((X))

# CHECK-ASM-AND-OBJ: STB (X),21
# CHECK-ASM: encoding: [0xf5,0x48,0x15]
STB (X),21
# CHECK-ASM-AND-OBJ: STBB (X),21
# CHECK-ASM: encoding: [0xe5,0x48,0x15]
STBB (X),21
# CHECK-ASM-AND-OBJ: STB_I (X),21
# CHECK-ASM: encoding: [0xf5,0x49,0x15]
STB_I (X),21
# CHECK-ASM-AND-OBJ: STBB_I (X),21
# CHECK-ASM: encoding: [0xe5,0x49,0x15]
STBB_I (X),21
# CHECK-ASM-AND-OBJ: STB_D (X),21
# CHECK-ASM: encoding: [0xf5,0x4a,0x15]
STB_D (X),21
# CHECK-ASM-AND-OBJ: STBB_D (X),21
# CHECK-ASM: encoding: [0xe5,0x4a,0x15]
STBB_D (X),21

# CHECK-ASM-AND-OBJ: STB_? (X),21
# CHECK-ASM: encoding: [0xf5,0x4c,0x15]
STB_? (X),21
# CHECK-ASM-AND-OBJ: STBB_? (X),21
# CHECK-ASM: encoding: [0xe5,0x4c,0x15]
STBB_? (X),21
# CHECK-ASM-AND-OBJ: STB_I ((X)),21
# CHECK-ASM: encoding: [0xf5,0x4d,0x15]
STB_I ((X)),21
# CHECK-ASM-AND-OBJ: STBB_I ((X)),21
# CHECK-ASM: encoding: [0xe5,0x4d,0x15]
STBB_I ((X)),21
# CHECK-ASM-AND-OBJ: STB_D ((X)),21
# CHECK-ASM: encoding: [0xf5,0x4e,0x15]
STB_D ((X)),21
# CHECK-ASM-AND-OBJ: STBB_D ((X)),21
# CHECK-ASM: encoding: [0xe5,0x4e,0x15]
STBB_D ((X)),21

# CHECK-ASM-AND-OBJ: STB_A
# CHECK-ASM: encoding: [0xf8]
STB_A
# CHECK-ASM-AND-OBJ: STBB_A
# CHECK-ASM: encoding: [0xe8]
STBB_A
# CHECK-ASM-AND-OBJ: STB_B
# CHECK-ASM: encoding: [0xf9]
STB_B
# CHECK-ASM-AND-OBJ: STBB_B
# CHECK-ASM: encoding: [0xe9]
STBB_B
# CHECK-ASM-AND-OBJ: STB_X
# CHECK-ASM: encoding: [0xfa]
STB_X
# CHECK-ASM-AND-OBJ: STBB_X
# CHECK-ASM: encoding: [0xea]
STBB_X
# CHECK-ASM-AND-OBJ: STB_Y
# CHECK-ASM: encoding: [0xfb]
STB_Y
# CHECK-ASM-AND-OBJ: STBB_Y
# CHECK-ASM: encoding: [0xeb]
STBB_Y
# CHECK-ASM-AND-OBJ: STB_Z
# CHECK-ASM: encoding: [0xfc]
STB_Z
# CHECK-ASM-AND-OBJ: STBB_Z
# CHECK-ASM: encoding: [0xec]
STBB_Z
# CHECK-ASM-AND-OBJ: STB_S
# CHECK-ASM: encoding: [0xfd]
STB_S
# CHECK-ASM-AND-OBJ: STBB_S
# CHECK-ASM: encoding: [0xed]
STBB_S
# CHECK-ASM-AND-OBJ: STB_C
# CHECK-ASM: encoding: [0xfe]
STB_C
# CHECK-ASM-AND-OBJ: STBB_C
# CHECK-ASM: encoding: [0xee]
STBB_C
# CHECK-ASM-AND-OBJ: STB_P
# CHECK-ASM: encoding: [0xff]
STB_P
# CHECK-ASM-AND-OBJ: STBB_P
# CHECK-ASM: encoding: [0xef]
STBB_P

# CHECK-ASM-AND-OBJ: LDX 48879
# CHECK-ASM: encoding: [0x60,0xbe,0xef]
LDX 48879

# CHECK-ASM-AND-OBJ: STX 48879
# CHECK-ASM: encoding: [0x68,0xbe,0xef]
STX 48879
# CHECK-ASM-AND-OBJ: STX (48879)
# CHECK-ASM: encoding: [0x69,0xbe,0xef]
STX (48879)
# CHECK-ASM-AND-OBJ: STX ((48879))
# CHECK-ASM: encoding: [0x6a,0xbe,0xef]
STX ((48879))
# CHECK-ASM-AND-OBJ: STX (PC),10
# CHECK-ASM: encoding: [0x6b,0x0a]
STX (PC),10
# CHECK-ASM-AND-OBJ: STX ((PC),10)
# CHECK-ASM: encoding: [0x6c,0x0a]
STX ((PC),10)
# CHECK-ASM-AND-OBJ: STX (X)
# CHECK-ASM: encoding: [0x6d,0x40]
STX (X)
# CHECK-ASM-AND-OBJ: STX_I (X)
# CHECK-ASM: encoding: [0x6d,0x41]
STX_I (X)
# CHECK-ASM-AND-OBJ: STX_D (X)
# CHECK-ASM: encoding: [0x6d,0x42]
STX_D (X)
# CHECK-ASM-AND-OBJ: STX ((X))
# CHECK-ASM: encoding: [0x6d,0x44]
STX ((X))
# CHECK-ASM-AND-OBJ: STX_I ((X))
# CHECK-ASM: encoding: [0x6d,0x45]
STX_I ((X))
# CHECK-ASM-AND-OBJ: STX_D ((X))
# CHECK-ASM: encoding: [0x6d,0x46]
STX_D ((X))
# CHECK-ASM-AND-OBJ: STX (X),10
# CHECK-ASM: encoding: [0x6d,0x48,0x0a]
STX (X),10
# CHECK-ASM-AND-OBJ: STX_I (X),10
# CHECK-ASM: encoding: [0x6d,0x49,0x0a]
STX_I (X),10
# CHECK-ASM-AND-OBJ: STX_D (X),10
# CHECK-ASM: encoding: [0x6d,0x4a,0x0a]
STX_D (X),10
# CHECK-ASM-AND-OBJ: STX_? (X),10
# CHECK-ASM: encoding: [0x6d,0x4c,0x0a]
STX_? (X),10
# CHECK-ASM-AND-OBJ: STX_I ((X)),10
# CHECK-ASM: encoding: [0x6d,0x4d,0x0a]
STX_I ((X)),10
# CHECK-ASM-AND-OBJ: STX_D ((X)),10
# CHECK-ASM: encoding: [0x6d,0x4e,0x0a]
STX_D ((X)),10

# CHECK-ASM-AND-OBJ: JMP (48879)
# CHECK-ASM: encoding: [0x71,0xbe,0xef]
JMP (48879)
# CHECK-ASM-AND-OBJ: JMP ((48879))
# CHECK-ASM: encoding: [0x72,0xbe,0xef]
JMP ((48879))
# CHECK-ASM-AND-OBJ: JMP (PC),10
# CHECK-ASM: encoding: [0x73,0x0a]
JMP (PC),10
# CHECK-ASM-AND-OBJ: JMP ((PC),10)
# CHECK-ASM: encoding: [0x74,0x0a]
JMP ((PC),10)
# CHECK-ASM-AND-OBJ: JMP (X)
# CHECK-ASM: encoding: [0x75,0x40]
JMP (X)
# CHECK-ASM-AND-OBJ: JMP_I (X)
# CHECK-ASM: encoding: [0x75,0x41]
JMP_I (X)
# CHECK-ASM-AND-OBJ: JMP_D (X)
# CHECK-ASM: encoding: [0x75,0x42]
JMP_D (X)
# CHECK-ASM-AND-OBJ: JMP ((X))
# CHECK-ASM: encoding: [0x75,0x44]
JMP ((X))
# CHECK-ASM-AND-OBJ: JMP_I ((X))
# CHECK-ASM: encoding: [0x75,0x45]
JMP_I ((X))
# CHECK-ASM-AND-OBJ: JMP_D ((X))
# CHECK-ASM: encoding: [0x75,0x46]
JMP_D ((X))
# CHECK-ASM-AND-OBJ: JMP (X),10
# CHECK-ASM: encoding: [0x75,0x48,0x0a]
JMP (X),10
# CHECK-ASM-AND-OBJ: JMP_I (X),10
# CHECK-ASM: encoding: [0x75,0x49,0x0a]
JMP_I (X),10
# CHECK-ASM-AND-OBJ: JMP_D (X),10
# CHECK-ASM: encoding: [0x75,0x4a,0x0a]
JMP_D (X),10
# CHECK-ASM-AND-OBJ: JMP_? (X),10
# CHECK-ASM: encoding: [0x75,0x4c,0x0a]
JMP_? (X),10
# CHECK-ASM-AND-OBJ: JMP_I ((X)),10
# CHECK-ASM: encoding: [0x75,0x4d,0x0a]
JMP_I ((X)),10
# CHECK-ASM-AND-OBJ: JMP_D ((X)),10
# CHECK-ASM: encoding: [0x75,0x4e,0x0a]
JMP_D ((X)),10

# CHECK-ASM-AND-OBJ: JSR (48879)
# CHECK-ASM: encoding: [0x79,0xbe,0xef]
JSR (48879)
# CHECK-ASM-AND-OBJ: JSR ((48879))
# CHECK-ASM: encoding: [0x7a,0xbe,0xef]
JSR ((48879))
# CHECK-ASM-AND-OBJ: JSR (PC),10
# CHECK-ASM: encoding: [0x7b,0x0a]
JSR (PC),10
# CHECK-ASM-AND-OBJ: JSR ((PC),10)
# CHECK-ASM: encoding: [0x7c,0x0a]
JSR ((PC),10)
# CHECK-ASM-AND-OBJ: JSR (X)
# CHECK-ASM: encoding: [0x7d,0x40]
JSR (X)
# CHECK-ASM-AND-OBJ: JSR_I (X)
# CHECK-ASM: encoding: [0x7d,0x41]
JSR_I (X)
# CHECK-ASM-AND-OBJ: JSR_D (X)
# CHECK-ASM: encoding: [0x7d,0x42]
JSR_D (X)
# CHECK-ASM-AND-OBJ: JSR ((X))
# CHECK-ASM: encoding: [0x7d,0x44]
JSR ((X))
# CHECK-ASM-AND-OBJ: JSR_I ((X))
# CHECK-ASM: encoding: [0x7d,0x45]
JSR_I ((X))
# CHECK-ASM-AND-OBJ: JSR_D ((X))
# CHECK-ASM: encoding: [0x7d,0x46]
JSR_D ((X))
# CHECK-ASM-AND-OBJ: JSR (X),10
# CHECK-ASM: encoding: [0x7d,0x48,0x0a]
JSR (X),10
# CHECK-ASM-AND-OBJ: JSR_I (X),10
# CHECK-ASM: encoding: [0x7d,0x49,0x0a]
JSR_I (X),10
# CHECK-ASM-AND-OBJ: JSR_D (X),10
# CHECK-ASM: encoding: [0x7d,0x4a,0x0a]
JSR_D (X),10
# CHECK-ASM-AND-OBJ: JSR_? (X),10
# CHECK-ASM: encoding: [0x7d,0x4c,0x0a]
JSR_? (X),10
# CHECK-ASM-AND-OBJ: JSR_I ((X)),10
# CHECK-ASM: encoding: [0x7d,0x4d,0x0a]
JSR_I ((X)),10
# CHECK-ASM-AND-OBJ: JSR_D ((X)),10
# CHECK-ASM: encoding: [0x7d,0x4e,0x0a]
JSR_D ((X)),10

# CHECK-ASM-AND-OBJ: LST (16),(32)
# CHECK-ASM: encoding: [0x6e,0x10,0x20]
LST (16),(32)
# CHECK-ASM-AND-OBJ: SST (16),(32)
# CHECK-ASM: encoding: [0x6f,0x10,0x20]
SST (16),(32)

# CHECK-ASM-AND-OBJ: MUL B,X
# CHECK-ASM: encoding: [0x77,0x24]
MUL B,X
# CHECK-ASM-AND-OBJ: DIV B,X
# CHECK-ASM: encoding: [0x78,0x24]
DIV B,X

# CHECK-ASM-AND-OBJ: RAD X
# CHECK-ASM: encoding: [0x2f,0x41]
RAD X
# CHECK-ASM-AND-OBJ: SCT X
# CHECK-ASM: encoding: [0x2f,0x42]
SCT X
# CHECK-ASM-AND-OBJ: RCT X
# CHECK-ASM: encoding: [0x2f,0x43]
RCT X
# CHECK-ASM-AND-OBJ: RDV X
# CHECK-ASM: encoding: [0x2f,0x45]
RDV X
# CHECK-ASM-AND-OBJ: EAB X
# CHECK-ASM: encoding: [0x2f,0x46]
EAB X
# CHECK-ASM-AND-OBJ: DAB X
# CHECK-ASM: encoding: [0x2f,0x47]
DAB X
# CHECK-ASM-AND-OBJ: SMN X
# CHECK-ASM: encoding: [0x2f,0x48]
SMN X
# CHECK-ASM-AND-OBJ: RMN X
# CHECK-ASM: encoding: [0x2f,0x49]
RMN X

# CHECK-ASM-AND-OBJ: BNA 4,2,48879,205
# CHECK-ASM: encoding: [0x46,0x42,0x00,0xbe,0xef,0x00,0xcd]
BNA 4,2,48879,205
# CHECK-ASM-AND-OBJ: BNA 4,2,48879,(48879)
# CHECK-ASM: encoding: [0x46,0x42,0x01,0xbe,0xef,0xbe,0xef]
BNA 4,2,48879,(48879)
# CHECK-ASM-AND-OBJ: BNA 4,2,48879,(Y),10
# CHECK-ASM: encoding: [0x46,0x42,0x02,0xbe,0xef,0x60,0x0a]
BNA 4,2,48879,(Y),10
# CHECK-ASM-AND-OBJ: BNA 4,2,(48879),205
# CHECK-ASM: encoding: [0x46,0x42,0x04,0xbe,0xef,0x00,0xcd]
BNA 4,2,(48879),205
# CHECK-ASM-AND-OBJ: BNA 4,2,(48879),(48879)
# CHECK-ASM: encoding: [0x46,0x42,0x05,0xbe,0xef,0xbe,0xef]
BNA 4,2,(48879),(48879)
# CHECK-ASM-AND-OBJ: BNA 4,2,(48879),(Y),10
# CHECK-ASM: encoding: [0x46,0x42,0x06,0xbe,0xef,0x60,0x0a]
BNA 4,2,(48879),(Y),10
# CHECK-ASM-AND-OBJ: BNA 4,2,(X),21,205
# CHECK-ASM: encoding: [0x46,0x42,0x08,0x40,0x15,0x00,0xcd]
BNA 4,2,(X),21,205
# CHECK-ASM-AND-OBJ: BNA 4,2,(X),21,(48879)
# CHECK-ASM: encoding: [0x46,0x42,0x09,0x40,0x15,0xbe,0xef]
BNA 4,2,(X),21,(48879)
# CHECK-ASM-AND-OBJ: BNA 4,2,(X),21,(Y),10
# CHECK-ASM: encoding: [0x46,0x42,0x0a,0x40,0x15,0x60,0x0a]
BNA 4,2,(X),21,(Y),10

# CHECK-ASM-AND-OBJ: BNS 4,2,48879,205
# CHECK-ASM: encoding: [0x46,0x42,0x10,0xbe,0xef,0x00,0xcd]
BNS 4,2,48879,205
# CHECK-ASM-AND-OBJ: BNS 4,2,48879,(48879)
# CHECK-ASM: encoding: [0x46,0x42,0x11,0xbe,0xef,0xbe,0xef]
BNS 4,2,48879,(48879)
# CHECK-ASM-AND-OBJ: BNS 4,2,48879,(Y),10
# CHECK-ASM: encoding: [0x46,0x42,0x12,0xbe,0xef,0x60,0x0a]
BNS 4,2,48879,(Y),10
# CHECK-ASM-AND-OBJ: BNS 4,2,(48879),205
# CHECK-ASM: encoding: [0x46,0x42,0x14,0xbe,0xef,0x00,0xcd]
BNS 4,2,(48879),205
# CHECK-ASM-AND-OBJ: BNS 4,2,(48879),(48879)
# CHECK-ASM: encoding: [0x46,0x42,0x15,0xbe,0xef,0xbe,0xef]
BNS 4,2,(48879),(48879)
# CHECK-ASM-AND-OBJ: BNS 4,2,(48879),(Y),10
# CHECK-ASM: encoding: [0x46,0x42,0x16,0xbe,0xef,0x60,0x0a]
BNS 4,2,(48879),(Y),10
# CHECK-ASM-AND-OBJ: BNS 4,2,(X),21,205
# CHECK-ASM: encoding: [0x46,0x42,0x18,0x40,0x15,0x00,0xcd]
BNS 4,2,(X),21,205
# CHECK-ASM-AND-OBJ: BNS 4,2,(X),21,(48879)
# CHECK-ASM: encoding: [0x46,0x42,0x19,0x40,0x15,0xbe,0xef]
BNS 4,2,(X),21,(48879)
# CHECK-ASM-AND-OBJ: BNS 4,2,(X),21,(Y),10
# CHECK-ASM: encoding: [0x46,0x42,0x1a,0x40,0x15,0x60,0x0a]
BNS 4,2,(X),21,(Y),10

# CHECK-ASM-AND-OBJ: BNC 4,2,48879,205
# CHECK-ASM: encoding: [0x46,0x42,0x20,0xbe,0xef,0x00,0xcd]
BNC 4,2,48879,205
# CHECK-ASM-AND-OBJ: BNC 4,2,48879,(48879)
# CHECK-ASM: encoding: [0x46,0x42,0x21,0xbe,0xef,0xbe,0xef]
BNC 4,2,48879,(48879)
# CHECK-ASM-AND-OBJ: BNC 4,2,48879,(Y),10
# CHECK-ASM: encoding: [0x46,0x42,0x22,0xbe,0xef,0x60,0x0a]
BNC 4,2,48879,(Y),10
# CHECK-ASM-AND-OBJ: BNC 4,2,(48879),205
# CHECK-ASM: encoding: [0x46,0x42,0x24,0xbe,0xef,0x00,0xcd]
BNC 4,2,(48879),205
# CHECK-ASM-AND-OBJ: BNC 4,2,(48879),(48879)
# CHECK-ASM: encoding: [0x46,0x42,0x25,0xbe,0xef,0xbe,0xef]
BNC 4,2,(48879),(48879)
# CHECK-ASM-AND-OBJ: BNC 4,2,(48879),(Y),10
# CHECK-ASM: encoding: [0x46,0x42,0x26,0xbe,0xef,0x60,0x0a]
BNC 4,2,(48879),(Y),10
# CHECK-ASM-AND-OBJ: BNC 4,2,(X),21,205
# CHECK-ASM: encoding: [0x46,0x42,0x28,0x40,0x15,0x00,0xcd]
BNC 4,2,(X),21,205
# CHECK-ASM-AND-OBJ: BNC 4,2,(X),21,(48879)
# CHECK-ASM: encoding: [0x46,0x42,0x29,0x40,0x15,0xbe,0xef]
BNC 4,2,(X),21,(48879)
# CHECK-ASM-AND-OBJ: BNC 4,2,(X),21,(Y),10
# CHECK-ASM: encoding: [0x46,0x42,0x2a,0x40,0x15,0x60,0x0a]
BNC 4,2,(X),21,(Y),10

# CHECK-ASM-AND-OBJ: ZAD 4,2,48879,205
# CHECK-ASM: encoding: [0x46,0x42,0x30,0xbe,0xef,0x00,0xcd]
ZAD 4,2,48879,205
# CHECK-ASM-AND-OBJ: ZAD 4,2,48879,(48879)
# CHECK-ASM: encoding: [0x46,0x42,0x31,0xbe,0xef,0xbe,0xef]
ZAD 4,2,48879,(48879)
# CHECK-ASM-AND-OBJ: ZAD 4,2,48879,(Y),10
# CHECK-ASM: encoding: [0x46,0x42,0x32,0xbe,0xef,0x60,0x0a]
ZAD 4,2,48879,(Y),10
# CHECK-ASM-AND-OBJ: ZAD 4,2,(48879),205
# CHECK-ASM: encoding: [0x46,0x42,0x34,0xbe,0xef,0x00,0xcd]
ZAD 4,2,(48879),205
# CHECK-ASM-AND-OBJ: ZAD 4,2,(48879),(48879)
# CHECK-ASM: encoding: [0x46,0x42,0x35,0xbe,0xef,0xbe,0xef]
ZAD 4,2,(48879),(48879)
# CHECK-ASM-AND-OBJ: ZAD 4,2,(48879),(Y),10
# CHECK-ASM: encoding: [0x46,0x42,0x36,0xbe,0xef,0x60,0x0a]
ZAD 4,2,(48879),(Y),10
# CHECK-ASM-AND-OBJ: ZAD 4,2,(X),21,205
# CHECK-ASM: encoding: [0x46,0x42,0x38,0x40,0x15,0x00,0xcd]
ZAD 4,2,(X),21,205
# CHECK-ASM-AND-OBJ: ZAD 4,2,(X),21,(48879)
# CHECK-ASM: encoding: [0x46,0x42,0x39,0x40,0x15,0xbe,0xef]
ZAD 4,2,(X),21,(48879)
# CHECK-ASM-AND-OBJ: ZAD 4,2,(X),21,(Y),10
# CHECK-ASM: encoding: [0x46,0x42,0x3a,0x40,0x15,0x60,0x0a]
ZAD 4,2,(X),21,(Y),10

# CHECK-ASM-AND-OBJ: ZSU 4,2,48879,205
# CHECK-ASM: encoding: [0x46,0x42,0x40,0xbe,0xef,0x00,0xcd]
ZSU 4,2,48879,205
# CHECK-ASM-AND-OBJ: ZSU 4,2,48879,(48879)
# CHECK-ASM: encoding: [0x46,0x42,0x41,0xbe,0xef,0xbe,0xef]
ZSU 4,2,48879,(48879)
# CHECK-ASM-AND-OBJ: ZSU 4,2,48879,(Y),10
# CHECK-ASM: encoding: [0x46,0x42,0x42,0xbe,0xef,0x60,0x0a]
ZSU 4,2,48879,(Y),10
# CHECK-ASM-AND-OBJ: ZSU 4,2,(48879),205
# CHECK-ASM: encoding: [0x46,0x42,0x44,0xbe,0xef,0x00,0xcd]
ZSU 4,2,(48879),205
# CHECK-ASM-AND-OBJ: ZSU 4,2,(48879),(48879)
# CHECK-ASM: encoding: [0x46,0x42,0x45,0xbe,0xef,0xbe,0xef]
ZSU 4,2,(48879),(48879)
# CHECK-ASM-AND-OBJ: ZSU 4,2,(48879),(Y),10
# CHECK-ASM: encoding: [0x46,0x42,0x46,0xbe,0xef,0x60,0x0a]
ZSU 4,2,(48879),(Y),10
# CHECK-ASM-AND-OBJ: ZSU 4,2,(X),21,205
# CHECK-ASM: encoding: [0x46,0x42,0x48,0x40,0x15,0x00,0xcd]
ZSU 4,2,(X),21,205
# CHECK-ASM-AND-OBJ: ZSU 4,2,(X),21,(48879)
# CHECK-ASM: encoding: [0x46,0x42,0x49,0x40,0x15,0xbe,0xef]
ZSU 4,2,(X),21,(48879)
# CHECK-ASM-AND-OBJ: ZSU 4,2,(X),21,(Y),10
# CHECK-ASM: encoding: [0x46,0x42,0x4a,0x40,0x15,0x60,0x0a]
ZSU 4,2,(X),21,(Y),10

# CHECK-ASM-AND-OBJ: M 4,2,48879,205
# CHECK-ASM: encoding: [0x46,0x42,0x50,0xbe,0xef,0x00,0xcd]
M 4,2,48879,205
# CHECK-ASM-AND-OBJ: M 4,2,48879,(48879)
# CHECK-ASM: encoding: [0x46,0x42,0x51,0xbe,0xef,0xbe,0xef]
M 4,2,48879,(48879)
# CHECK-ASM-AND-OBJ: M 4,2,48879,(Y),10
# CHECK-ASM: encoding: [0x46,0x42,0x52,0xbe,0xef,0x60,0x0a]
M 4,2,48879,(Y),10
# CHECK-ASM-AND-OBJ: M 4,2,(48879),205
# CHECK-ASM: encoding: [0x46,0x42,0x54,0xbe,0xef,0x00,0xcd]
M 4,2,(48879),205
# CHECK-ASM-AND-OBJ: M 4,2,(48879),(48879)
# CHECK-ASM: encoding: [0x46,0x42,0x55,0xbe,0xef,0xbe,0xef]
M 4,2,(48879),(48879)
# CHECK-ASM-AND-OBJ: M 4,2,(48879),(Y),10
# CHECK-ASM: encoding: [0x46,0x42,0x56,0xbe,0xef,0x60,0x0a]
M 4,2,(48879),(Y),10
# CHECK-ASM-AND-OBJ: M 4,2,(X),21,205
# CHECK-ASM: encoding: [0x46,0x42,0x58,0x40,0x15,0x00,0xcd]
M 4,2,(X),21,205
# CHECK-ASM-AND-OBJ: M 4,2,(X),21,(48879)
# CHECK-ASM: encoding: [0x46,0x42,0x59,0x40,0x15,0xbe,0xef]
M 4,2,(X),21,(48879)
# CHECK-ASM-AND-OBJ: M 4,2,(X),21,(Y),10
# CHECK-ASM: encoding: [0x46,0x42,0x5a,0x40,0x15,0x60,0x0a]
M 4,2,(X),21,(Y),10

# CHECK-ASM-AND-OBJ: D 4,2,48879,205
# CHECK-ASM: encoding: [0x46,0x42,0x60,0xbe,0xef,0x00,0xcd]
D 4,2,48879,205
# CHECK-ASM-AND-OBJ: D 4,2,48879,(48879)
# CHECK-ASM: encoding: [0x46,0x42,0x61,0xbe,0xef,0xbe,0xef]
D 4,2,48879,(48879)
# CHECK-ASM-AND-OBJ: D 4,2,48879,(Y),10
# CHECK-ASM: encoding: [0x46,0x42,0x62,0xbe,0xef,0x60,0x0a]
D 4,2,48879,(Y),10
# CHECK-ASM-AND-OBJ: D 4,2,(48879),205
# CHECK-ASM: encoding: [0x46,0x42,0x64,0xbe,0xef,0x00,0xcd]
D 4,2,(48879),205
# CHECK-ASM-AND-OBJ: D 4,2,(48879),(48879)
# CHECK-ASM: encoding: [0x46,0x42,0x65,0xbe,0xef,0xbe,0xef]
D 4,2,(48879),(48879)
# CHECK-ASM-AND-OBJ: D 4,2,(48879),(Y),10
# CHECK-ASM: encoding: [0x46,0x42,0x66,0xbe,0xef,0x60,0x0a]
D 4,2,(48879),(Y),10
# CHECK-ASM-AND-OBJ: D 4,2,(X),21,205
# CHECK-ASM: encoding: [0x46,0x42,0x68,0x40,0x15,0x00,0xcd]
D 4,2,(X),21,205
# CHECK-ASM-AND-OBJ: D 4,2,(X),21,(48879)
# CHECK-ASM: encoding: [0x46,0x42,0x69,0x40,0x15,0xbe,0xef]
D 4,2,(X),21,(48879)
# CHECK-ASM-AND-OBJ: D 4,2,(X),21,(Y),10
# CHECK-ASM: encoding: [0x46,0x42,0x6a,0x40,0x15,0x60,0x0a]
D 4,2,(X),21,(Y),10

# CHECK-ASM-AND-OBJ: DRM 4,2,48879,205
# CHECK-ASM: encoding: [0x46,0x42,0x70,0xbe,0xef,0x00,0xcd]
DRM 4,2,48879,205
# CHECK-ASM-AND-OBJ: DRM 4,2,48879,(48879)
# CHECK-ASM: encoding: [0x46,0x42,0x71,0xbe,0xef,0xbe,0xef]
DRM 4,2,48879,(48879)
# CHECK-ASM-AND-OBJ: DRM 4,2,48879,(Y),10
# CHECK-ASM: encoding: [0x46,0x42,0x72,0xbe,0xef,0x60,0x0a]
DRM 4,2,48879,(Y),10
# CHECK-ASM-AND-OBJ: DRM 4,2,(48879),205
# CHECK-ASM: encoding: [0x46,0x42,0x74,0xbe,0xef,0x00,0xcd]
DRM 4,2,(48879),205
# CHECK-ASM-AND-OBJ: DRM 4,2,(48879),(48879)
# CHECK-ASM: encoding: [0x46,0x42,0x75,0xbe,0xef,0xbe,0xef]
DRM 4,2,(48879),(48879)
# CHECK-ASM-AND-OBJ: DRM 4,2,(48879),(Y),10
# CHECK-ASM: encoding: [0x46,0x42,0x76,0xbe,0xef,0x60,0x0a]
DRM 4,2,(48879),(Y),10
# CHECK-ASM-AND-OBJ: DRM 4,2,(X),21,205
# CHECK-ASM: encoding: [0x46,0x42,0x78,0x40,0x15,0x00,0xcd]
DRM 4,2,(X),21,205
# CHECK-ASM-AND-OBJ: DRM 4,2,(X),21,(48879)
# CHECK-ASM: encoding: [0x46,0x42,0x79,0x40,0x15,0xbe,0xef]
DRM 4,2,(X),21,(48879)
# CHECK-ASM-AND-OBJ: DRM 4,2,(X),21,(Y),10
# CHECK-ASM: encoding: [0x46,0x42,0x7a,0x40,0x15,0x60,0x0a]
DRM 4,2,(X),21,(Y),10

# CHECK-ASM-AND-OBJ: CTB 4,2,48879,205
# CHECK-ASM: encoding: [0x46,0x42,0x80,0xbe,0xef,0x00,0xcd]
CTB 4,2,48879,205
# CHECK-ASM-AND-OBJ: CTB 4,2,48879,(48879)
# CHECK-ASM: encoding: [0x46,0x42,0x81,0xbe,0xef,0xbe,0xef]
CTB 4,2,48879,(48879)
# CHECK-ASM-AND-OBJ: CTB 4,2,48879,(Y),10
# CHECK-ASM: encoding: [0x46,0x42,0x82,0xbe,0xef,0x60,0x0a]
CTB 4,2,48879,(Y),10
# CHECK-ASM-AND-OBJ: CTB 4,2,(48879),205
# CHECK-ASM: encoding: [0x46,0x42,0x84,0xbe,0xef,0x00,0xcd]
CTB 4,2,(48879),205
# CHECK-ASM-AND-OBJ: CTB 4,2,(48879),(48879)
# CHECK-ASM: encoding: [0x46,0x42,0x85,0xbe,0xef,0xbe,0xef]
CTB 4,2,(48879),(48879)
# CHECK-ASM-AND-OBJ: CTB 4,2,(48879),(Y),10
# CHECK-ASM: encoding: [0x46,0x42,0x86,0xbe,0xef,0x60,0x0a]
CTB 4,2,(48879),(Y),10
# CHECK-ASM-AND-OBJ: CTB 4,2,(X),21,205
# CHECK-ASM: encoding: [0x46,0x42,0x88,0x40,0x15,0x00,0xcd]
CTB 4,2,(X),21,205
# CHECK-ASM-AND-OBJ: CTB 4,2,(X),21,(48879)
# CHECK-ASM: encoding: [0x46,0x42,0x89,0x40,0x15,0xbe,0xef]
CTB 4,2,(X),21,(48879)
# CHECK-ASM-AND-OBJ: CTB 4,2,(X),21,(Y),10
# CHECK-ASM: encoding: [0x46,0x42,0x8a,0x40,0x15,0x60,0x0a]
CTB 4,2,(X),21,(Y),10

# CHECK-ASM-AND-OBJ: CFB 4,2,48879,205
# CHECK-ASM: encoding: [0x46,0x42,0x90,0xbe,0xef,0x00,0xcd]
CFB 4,2,48879,205
# CHECK-ASM-AND-OBJ: CFB 4,2,48879,(48879)
# CHECK-ASM: encoding: [0x46,0x42,0x91,0xbe,0xef,0xbe,0xef]
CFB 4,2,48879,(48879)
# CHECK-ASM-AND-OBJ: CFB 4,2,48879,(Y),10
# CHECK-ASM: encoding: [0x46,0x42,0x92,0xbe,0xef,0x60,0x0a]
CFB 4,2,48879,(Y),10
# CHECK-ASM-AND-OBJ: CFB 4,2,(48879),205
# CHECK-ASM: encoding: [0x46,0x42,0x94,0xbe,0xef,0x00,0xcd]
CFB 4,2,(48879),205
# CHECK-ASM-AND-OBJ: CFB 4,2,(48879),(48879)
# CHECK-ASM: encoding: [0x46,0x42,0x95,0xbe,0xef,0xbe,0xef]
CFB 4,2,(48879),(48879)
# CHECK-ASM-AND-OBJ: CFB 4,2,(48879),(Y),10
# CHECK-ASM: encoding: [0x46,0x42,0x96,0xbe,0xef,0x60,0x0a]
CFB 4,2,(48879),(Y),10
# CHECK-ASM-AND-OBJ: CFB 4,2,(X),21,205
# CHECK-ASM: encoding: [0x46,0x42,0x98,0x40,0x15,0x00,0xcd]
CFB 4,2,(X),21,205
# CHECK-ASM-AND-OBJ: CFB 4,2,(X),21,(48879)
# CHECK-ASM: encoding: [0x46,0x42,0x99,0x40,0x15,0xbe,0xef]
CFB 4,2,(X),21,(48879)
# CHECK-ASM-AND-OBJ: CFB 4,2,(X),21,(Y),10
# CHECK-ASM: encoding: [0x46,0x42,0x9a,0x40,0x15,0x60,0x0a]
CFB 4,2,(X),21,(Y),10
# CHECK-ASM-AND-OBJ: ADD X,X,65516
# CHECK-ASM: encoding: [0x50,0x54,0xff,0xec]
ADD X,X,65516
# CHECK-ASM-AND-OBJ: ADD B,X,400
# CHECK-ASM: encoding: [0x50,0x34,0x01,0x90]
ADD B,X,400
# CHECK-ASM-AND-OBJ: XFR Z,61952
# CHECK-ASM: encoding: [0x55,0x98,0xf2,0x00]
XFR Z,61952
# CHECK-ASM-AND-OBJ: XFR (B),X,5
# CHECK-ASM: encoding: [0x55,0x35,0x00,0x05]
XFR (B),X,5
# CHECK-ASM-AND-OBJ: XFR (S),Z,4
# CHECK-ASM: encoding: [0x55,0xb9,0x00,0x04]
XFR (S),Z,4
# rrfetchw mode 1. High nibble even, low nibble odd, then the address.
# 0x89 names Z in both nibbles; the low bit is the mode. This is the load
# that pairs with STR Z,(37559).
# CHECK-ASM-AND-OBJ: XFR (37559),Z
# CHECK-ASM: encoding: [0x55,0x89,0x92,0xb7]
XFR (37559),Z
# CHECK-ASM-AND-OBJ: XFR (256),A
# CHECK-ASM: encoding: [0x55,0x01,0x01,0x00]
XFR (256),A
# CHECK-ASM-AND-OBJ: STK X,5
# CHECK-ASM: encoding: [0x7e,0x45]
STK X,5
# CHECK-ASM-AND-OBJ: STK Z,1
# CHECK-ASM: encoding: [0x7e,0x81]
STK Z,1
# CHECK-ASM-AND-OBJ: POP X,5
# CHECK-ASM: encoding: [0x7f,0x45]
POP X,5
# CHECK-ASM-AND-OBJ: POP Z,1
# CHECK-ASM: encoding: [0x7f,0x81]
POP Z,1
# CHECK-ASM-AND-OBJ: SAR 6,P
# CHECK-ASM: encoding: [0xd7,0x6e]
SAR 6,P
# CHECK-ASM-AND-OBJ: SAR 6,A
# CHECK-ASM: encoding: [0xd7,0x60]
SAR 6,A
# CHECK-ASM-AND-OBJ: LAR 6,A
# CHECK-ASM: encoding: [0xe6,0x60]
LAR 6,A
# CHECK-ASM-AND-OBJ: LIO AL,Z,0
# CHECK-ASM: encoding: [0xf6,0x18,0x00]
LIO AL,Z,0
# CHECK-ASM-AND-OBJ: SIO AL,Z,13
# CHECK-ASM: encoding: [0xf6,0x19,0x0d]
SIO AL,Z,13
# CHECK-ASM-AND-OBJ: LIO BL,Z,15
# CHECK-ASM: encoding: [0xf6,0x38,0x0f]
LIO BL,Z,15
# CHECK-ASM-AND-OBJ: SIO BL,Z,0
# CHECK-ASM: encoding: [0xf6,0x39,0x00]
SIO BL,Z,0
# CHECK-ASM-AND-OBJ: SUB A,A,32767
# CHECK-ASM: encoding: [0x51,0x10,0x7f,0xff]
SUB A,A,32767
# CHECK-ASM-AND-OBJ: AND A,A,2
# CHECK-ASM: encoding: [0x52,0x10,0x00,0x02]
AND A,A,2
# CHECK-ASM-AND-OBJ: ORI A,A,1
# CHECK-ASM: encoding: [0x53,0x10,0x00,0x01]
ORI A,A,1
# CHECK-ASM-AND-OBJ: ORI B,B,3
# CHECK-ASM: encoding: [0x53,0x32,0x00,0x03]
ORI B,B,3
# CHECK-ASM-AND-OBJ: ORE A,A,2
# CHECK-ASM: encoding: [0x54,0x10,0x00,0x02]
ORE A,A,2
# CHECK-ASM-AND-OBJ: MUL B,B,10
# CHECK-ASM: encoding: [0x77,0x32,0x00,0x0a]
MUL B,B,10
# CHECK-ASM-AND-OBJ: DIV B,B,400
# CHECK-ASM: encoding: [0x78,0x32,0x01,0x90]
DIV B,B,400
# CHECK-ASM-AND-OBJ: CLR A,1
# CHECK-ASM: encoding: [0x32,0x01]
CLR A,1
# CHECK-ASM-AND-OBJ: CLR A,2
# CHECK-ASM: encoding: [0x32,0x02]
CLR A,2
# CHECK-ASM-AND-OBJ: CLRB BL,2
# CHECK-ASM: encoding: [0x22,0x32]
CLRB BL,2
# CHECK-ASM-AND-OBJ: IVR A,2
# CHECK-ASM: encoding: [0x33,0x02]
IVR A,2
# CHECK-ASM-AND-OBJ: INR (36557),0
# CHECK-ASM: encoding: [0x30,0x10,0x8e,0xcd]
INR (36557),0
# CHECK-ASM-AND-OBJ: INR (Y),53,0
# CHECK-ASM: encoding: [0x30,0x70,0x00,0x35]
INR (Y),53,0
# CHECK-ASM-AND-OBJ: DCR (36557),0
# CHECK-ASM: encoding: [0x31,0x10,0x8e,0xcd]
DCR (36557),0
# CHECK-ASM-AND-OBJ: DCR (Y),53,0
# CHECK-ASM: encoding: [0x31,0x70,0x00,0x35]
DCR (Y),53,0
# CHECK-ASM-AND-OBJ: CLR (36917),0
# CHECK-ASM: encoding: [0x32,0x10,0x90,0x35]
CLR (36917),0
# CHECK-ASM-AND-OBJ: CLR (Z),16,0
# CHECK-ASM: encoding: [0x32,0x90,0x00,0x10]
CLR (Z),16,0
# CHECK-ASM-AND-OBJ: IVR (53019),1
# CHECK-ASM: encoding: [0x33,0x11,0xcf,0x1b]
IVR (53019),1
# CHECK-ASM-AND-OBJ: IVR (Z),16,1
# CHECK-ASM: encoding: [0x33,0x91,0x00,0x10]
IVR (Z),16,1
# CHECK-ASM-AND-OBJ: SRR (36917),7
# CHECK-ASM: encoding: [0x34,0x17,0x90,0x35]
SRR (36917),7
# CHECK-ASM-AND-OBJ: SRR (Z),33536,7
# CHECK-ASM: encoding: [0x34,0x97,0x83,0x00]
SRR (Z),33536,7
# CHECK-ASM-AND-OBJ: MVF 0,255,(613)
# CHECK-ASM: encoding: [0x47,0x4c,0x00,0xff,0x02,0x65]
MVF 0,255,(613)
# CHECK-ASM-AND-OBJ: FIL 9,160,(869)
# CHECK-ASM: encoding: [0x47,0x9c,0x09,0xa0,0x03,0x65]
FIL 9,160,(869)
# CHECK-ASM-AND-OBJ: MVFR Z,Y
# CHECK-ASM: encoding: [0x67,0x4a,0x86]
MVFR Z,Y
# CHECK-ASM-AND-OBJ: MVFR Y,X
# CHECK-ASM: encoding: [0x67,0x4a,0x64]
MVFR Y,X
# CHECK-ASM-AND-OBJ: STR Z,(37559)
# CHECK-ASM: encoding: [0xd6,0x89,0x92,0xb7]
STR Z,(37559)
# CHECK-ASM-AND-OBJ: STR Y,(319)
# CHECK-ASM: encoding: [0xd6,0x67,0x01,0x3f]
STR Y,(319)
# CHECK-ASM-AND-OBJ: STR B,(X),5
# CHECK-ASM: encoding: [0xd6,0x53,0x00,0x05]
STR B,(X),5
# CHECK-ASM-AND-OBJ: STR A,(Z),0
# CHECK-ASM: encoding: [0xd6,0x91,0x00,0x00]
STR A,(Z),0
# CHECK-ASM-AND-OBJ: STR Z,(S),4
# CHECK-ASM: encoding: [0xd6,0xb9,0x00,0x04]
STR Z,(S),4
# CHECK-ASM-AND-OBJ: DIV (Z),B,28
# CHECK-ASM: encoding: [0x78,0x93,0x00,0x1c]
DIV (Z),B,28
# webCenREE operand widths.
# CHECK-ASM-AND-OBJ: MVF 9,B,A
# CHECK-ASM: encoding: [0x47,0x4a,0x09,0x20]
MVF 9,B,A
# CHECK-ASM-AND-OBJ: CPF 9,B,A
# CHECK-ASM: encoding: [0x47,0x8a,0x09,0x20]
CPF 9,B,A
# CHECK-ASM-AND-OBJ: MVF 9,X,(37858)
# CHECK-ASM: encoding: [0x47,0x48,0x09,0x40,0x93,0xe2]
MVF 9,X,(37858)
# CHECK-ASM-AND-OBJ: CPF 9,B,(613)
# CHECK-ASM: encoding: [0x47,0x88,0x09,0x20,0x02,0x65]
CPF 9,B,(613)
# CHECK-ASM-AND-OBJ: MVF 9,(37858),X
# CHECK-ASM: encoding: [0x47,0x42,0x09,0x93,0xe2,0x04]
MVF 9,(37858),X
# CHECK-ASM-AND-OBJ: CPF 9,(613),A
# CHECK-ASM: encoding: [0x47,0x82,0x09,0x02,0x65,0x00]
CPF 9,(613),A
# CHECK-ASM-AND-OBJ: MVF 2,(37428),(32956)
# CHECK-ASM: encoding: [0x47,0x40,0x02,0x92,0x34,0x80,0xbc]
MVF 2,(37428),(32956)
# CHECK-ASM-AND-OBJ: CPF 9,(613),(869)
# CHECK-ASM: encoding: [0x47,0x80,0x09,0x02,0x65,0x03,0x65]
CPF 9,(613),(869)
# CHECK-ASM-AND-OBJ: MVF 2,(X),13,(37428)
# CHECK-ASM: encoding: [0x47,0x44,0x02,0x40,0x0d,0x92,0x34]
MVF 2,(X),13,(37428)
# CHECK-ASM-AND-OBJ: CPF 9,(X),5,(613)
# CHECK-ASM: encoding: [0x47,0x84,0x09,0x40,0x05,0x02,0x65]
CPF 9,(X),5,(613)
# CHECK-ASM-AND-OBJ: MVF 15,(389),(Z),54
# CHECK-ASM: encoding: [0x47,0x41,0x0f,0x01,0x85,0x80,0x36]
MVF 15,(389),(Z),54
# CHECK-ASM-AND-OBJ: CPF 9,(613),(X),5
# CHECK-ASM: encoding: [0x47,0x81,0x09,0x02,0x65,0x40,0x05]
CPF 9,(613),(X),5
# CHECK-ASM-AND-OBJ: MVF 24,(B),2,(A),2
# CHECK-ASM: encoding: [0x47,0x45,0x18,0x20,0x02,0x00,0x02]
MVF 24,(B),2,(A),2
# CHECK-ASM-AND-OBJ: CPF 9,(X),5,(Y),6
# CHECK-ASM: encoding: [0x47,0x85,0x09,0x40,0x05,0x60,0x06]
CPF 9,(X),5,(Y),6
# CHECK-ASM-AND-OBJ: MVF 9,(X),5,A
# CHECK-ASM: encoding: [0x47,0x46,0x09,0x40,0x05,0x00]
MVF 9,(X),5,A
# CHECK-ASM-AND-OBJ: CPF 9,(X),5,A
# CHECK-ASM: encoding: [0x47,0x86,0x09,0x40,0x05,0x00]
CPF 9,(X),5,A
# CHECK-ASM-AND-OBJ: MVF 9,B,(X),5
# CHECK-ASM: encoding: [0x47,0x49,0x09,0x20,0x40,0x05]
MVF 9,B,(X),5
# CHECK-ASM-AND-OBJ: CPF 9,B,(X),5
# CHECK-ASM: encoding: [0x47,0x89,0x09,0x20,0x40,0x05]
CPF 9,B,(X),5
# CHECK-ASM-AND-OBJ: MVF 9,(X),(28),A
# CHECK-ASM: encoding: [0x47,0x46,0x09,0x50,0x00,0x1c,0x00]
MVF 9,(X),(28),A
# CHECK-ASM-AND-OBJ: CPF 9,(X),(28),A
# CHECK-ASM: encoding: [0x47,0x86,0x09,0x50,0x00,0x1c,0x00]
CPF 9,(X),(28),A
# CHECK-ASM-AND-OBJ: MVF 9,B,(X),(28)
# CHECK-ASM: encoding: [0x47,0x49,0x09,0x20,0x50,0x00,0x1c]
MVF 9,B,(X),(28)
# CHECK-ASM-AND-OBJ: CPF 9,B,(X),(28)
# CHECK-ASM: encoding: [0x47,0x89,0x09,0x20,0x50,0x00,0x1c]
CPF 9,B,(X),(28)
# CHECK-ASM-AND-OBJ: FIL 3,192,X
# CHECK-ASM: encoding: [0x47,0x9e,0x03,0xc0,0x04]
FIL 3,192,X
# CHECK-ASM-AND-OBJ: FIL 0,126,(A),-1
# CHECK-ASM: encoding: [0x47,0x9d,0x00,0x7e,0x00,0xff]
FIL 0,126,(A),-1
# CHECK-ASM-AND-OBJ: FIL 9,255,(X),(28)
# CHECK-ASM: encoding: [0x47,0x9d,0x09,0xff,0x50,0x00,0x1c]
FIL 9,255,(X),(28)
# CHECK-ASM-AND-OBJ: CPFR B,A
# CHECK-ASM: encoding: [0x67,0x8a,0x20]
CPFR B,A
# CHECK-ASM-AND-OBJ: MVFR B,(613)
# CHECK-ASM: encoding: [0x67,0x48,0x20,0x02,0x65]
MVFR B,(613)
# CHECK-ASM-AND-OBJ: CPFR B,(613)
# CHECK-ASM: encoding: [0x67,0x88,0x20,0x02,0x65]
CPFR B,(613)
# CHECK-ASM-AND-OBJ: MVFR (613),A
# CHECK-ASM: encoding: [0x67,0x42,0x02,0x65,0x00]
MVFR (613),A
# CHECK-ASM-AND-OBJ: CPFR (613),A
# CHECK-ASM: encoding: [0x67,0x82,0x02,0x65,0x00]
CPFR (613),A
# CHECK-ASM-AND-OBJ: MVFR (613),(869)
# CHECK-ASM: encoding: [0x67,0x40,0x02,0x65,0x03,0x65]
MVFR (613),(869)
# CHECK-ASM-AND-OBJ: CPFR (613),(869)
# CHECK-ASM: encoding: [0x67,0x80,0x02,0x65,0x03,0x65]
CPFR (613),(869)
# CHECK-ASM-AND-OBJ: MVFR (X),5,A
# CHECK-ASM: encoding: [0x67,0x46,0x40,0x05,0x00]
MVFR (X),5,A
# CHECK-ASM-AND-OBJ: CPFR (X),5,A
# CHECK-ASM: encoding: [0x67,0x86,0x40,0x05,0x00]
CPFR (X),5,A
# CHECK-ASM-AND-OBJ: MVFR B,(X),5
# CHECK-ASM: encoding: [0x67,0x49,0x20,0x40,0x05]
MVFR B,(X),5
# CHECK-ASM-AND-OBJ: CPFR B,(X),5
# CHECK-ASM: encoding: [0x67,0x89,0x20,0x40,0x05]
CPFR B,(X),5
# CHECK-ASM-AND-OBJ: MVFR (X),5,(613)
# CHECK-ASM: encoding: [0x67,0x44,0x40,0x05,0x02,0x65]
MVFR (X),5,(613)
# CHECK-ASM-AND-OBJ: CPFR (X),5,(613)
# CHECK-ASM: encoding: [0x67,0x84,0x40,0x05,0x02,0x65]
CPFR (X),5,(613)
# CHECK-ASM-AND-OBJ: MVFR (57099),(Z),2
# CHECK-ASM: encoding: [0x67,0x41,0xdf,0x0b,0x80,0x02]
MVFR (57099),(Z),2
# CHECK-ASM-AND-OBJ: CPFR (613),(X),5
# CHECK-ASM: encoding: [0x67,0x81,0x02,0x65,0x40,0x05]
CPFR (613),(X),5
# CHECK-ASM-AND-OBJ: MVFR (X),5,(Y),6
# CHECK-ASM: encoding: [0x67,0x45,0x40,0x05,0x60,0x06]
MVFR (X),5,(Y),6
# CHECK-ASM-AND-OBJ: CPFR (X),5,(Y),6
# CHECK-ASM: encoding: [0x67,0x85,0x40,0x05,0x60,0x06]
CPFR (X),5,(Y),6
# CHECK-ASM-AND-OBJ: MVFR (X),(28),A
# CHECK-ASM: encoding: [0x67,0x46,0x50,0x00,0x1c,0x00]
MVFR (X),(28),A
# CHECK-ASM-AND-OBJ: CPFR (X),(28),A
# CHECK-ASM: encoding: [0x67,0x86,0x50,0x00,0x1c,0x00]
CPFR (X),(28),A
# CHECK-ASM-AND-OBJ: MVFR B,(X),(28)
# CHECK-ASM: encoding: [0x67,0x49,0x20,0x50,0x00,0x1c]
MVFR B,(X),(28)
# CHECK-ASM-AND-OBJ: CPFR B,(X),(28)
# CHECK-ASM: encoding: [0x67,0x89,0x20,0x50,0x00,0x1c]
CPFR B,(X),(28)
# CHECK-ASM-AND-OBJ: MVFR (X),(28),(613)
# CHECK-ASM: encoding: [0x67,0x44,0x50,0x00,0x1c,0x02,0x65]
MVFR (X),(28),(613)
# CHECK-ASM-AND-OBJ: CPFR (X),(28),(613)
# CHECK-ASM: encoding: [0x67,0x84,0x50,0x00,0x1c,0x02,0x65]
CPFR (X),(28),(613)
# CHECK-ASM-AND-OBJ: MVFR (613),(X),(28)
# CHECK-ASM: encoding: [0x67,0x41,0x02,0x65,0x50,0x00,0x1c]
MVFR (613),(X),(28)
# CHECK-ASM-AND-OBJ: CPFR (613),(X),(28)
# CHECK-ASM: encoding: [0x67,0x81,0x02,0x65,0x50,0x00,0x1c]
CPFR (613),(X),(28)
# CHECK-ASM-AND-OBJ: MVFR (X),5,(Y),(29)
# CHECK-ASM: encoding: [0x67,0x45,0x40,0x05,0x70,0x00,0x1d]
MVFR (X),5,(Y),(29)
# CHECK-ASM-AND-OBJ: CPFR (X),5,(Y),(29)
# CHECK-ASM: encoding: [0x67,0x85,0x40,0x05,0x70,0x00,0x1d]
CPFR (X),5,(Y),(29)
# CHECK-ASM-AND-OBJ: MVFR (X),(28),(Y),6
# CHECK-ASM: encoding: [0x67,0x45,0x50,0x00,0x1c,0x60,0x06]
MVFR (X),(28),(Y),6
# CHECK-ASM-AND-OBJ: CPFR (X),(28),(Y),6
# CHECK-ASM: encoding: [0x67,0x85,0x50,0x00,0x1c,0x60,0x06]
CPFR (X),(28),(Y),6
# CHECK-ASM-AND-OBJ: FILR 160,B
# CHECK-ASM: encoding: [0x67,0x9e,0xa0,0x02]
FILR 160,B
# CHECK-ASM-AND-OBJ: FILR 0,(324)
# CHECK-ASM: encoding: [0x67,0x9c,0x00,0x01,0x44]
FILR 0,(324)
# CHECK-ASM-AND-OBJ: FILR 255,(X),5
# CHECK-ASM: encoding: [0x67,0x9d,0xff,0x40,0x05]
FILR 255,(X),5
# CHECK-ASM-AND-OBJ: FILR 253,(B),(454)
# CHECK-ASM: encoding: [0x67,0x9d,0xfd,0x30,0x01,0xc6]
FILR 253,(B),(454)
# CHECK-ASM-AND-OBJ: LDM 120,(453)
# CHECK-ASM: encoding: [0x2e,0x0c,0x78,0x01,0xc5]
LDM 120,(453)
# CHECK-ASM-AND-OBJ: STM 120,(32979)
# CHECK-ASM: encoding: [0x2e,0x1c,0x78,0x80,0xd3]
STM 120,(32979)
# CHECK-ASM-AND-OBJ: LSM 120,(613)
# CHECK-ASM: encoding: [0x2e,0x2c,0x78,0x02,0x65]
LSM 120,(613)
# CHECK-ASM-AND-OBJ: SSM 120,(613)
# CHECK-ASM: encoding: [0x2e,0x3c,0x78,0x02,0x65]
SSM 120,(613)
# CHECK-ASM-AND-OBJ: FLM 120,(613)
# CHECK-ASM: encoding: [0x2e,0x4c,0x78,0x02,0x65]
FLM 120,(613)
# CHECK-ASM-AND-OBJ: MFM 120,(613)
# CHECK-ASM: encoding: [0x2e,0x5c,0x78,0x02,0x65]
MFM 120,(613)
# CHECK-ASM-AND-OBJ: LDM 120,A
# CHECK-ASM: encoding: [0x2e,0x0e,0x78,0x00]
LDM 120,A
# CHECK-ASM-AND-OBJ: STM 120,A
# CHECK-ASM: encoding: [0x2e,0x1e,0x78,0x00]
STM 120,A
# CHECK-ASM-AND-OBJ: LSM 120,A
# CHECK-ASM: encoding: [0x2e,0x2e,0x78,0x00]
LSM 120,A
# CHECK-ASM-AND-OBJ: SSM 120,A
# CHECK-ASM: encoding: [0x2e,0x3e,0x78,0x00]
SSM 120,A
# CHECK-ASM-AND-OBJ: FLM 120,A
# CHECK-ASM: encoding: [0x2e,0x4e,0x78,0x00]
FLM 120,A
# CHECK-ASM-AND-OBJ: MFM 120,A
# CHECK-ASM: encoding: [0x2e,0x5e,0x78,0x00]
MFM 120,A
# CHECK-ASM-AND-OBJ: LDM 248,(A),54
# CHECK-ASM: encoding: [0x2e,0x0d,0xf8,0x00,0x36]
LDM 248,(A),54
# CHECK-ASM-AND-OBJ: STM 120,(X),5
# CHECK-ASM: encoding: [0x2e,0x1d,0x78,0x40,0x05]
STM 120,(X),5
# CHECK-ASM-AND-OBJ: LSM 120,(X),5
# CHECK-ASM: encoding: [0x2e,0x2d,0x78,0x40,0x05]
LSM 120,(X),5
# CHECK-ASM-AND-OBJ: SSM 120,(X),5
# CHECK-ASM: encoding: [0x2e,0x3d,0x78,0x40,0x05]
SSM 120,(X),5
# CHECK-ASM-AND-OBJ: FLM 120,(X),5
# CHECK-ASM: encoding: [0x2e,0x4d,0x78,0x40,0x05]
FLM 120,(X),5
# CHECK-ASM-AND-OBJ: MFM 120,(X),5
# CHECK-ASM: encoding: [0x2e,0x5d,0x78,0x40,0x05]
MFM 120,(X),5
# CHECK-ASM-AND-OBJ: LDM 120,(X),(28)
# CHECK-ASM: encoding: [0x2e,0x0d,0x78,0x50,0x00,0x1c]
LDM 120,(X),(28)
# CHECK-ASM-AND-OBJ: STM 120,(X),(28)
# CHECK-ASM: encoding: [0x2e,0x1d,0x78,0x50,0x00,0x1c]
STM 120,(X),(28)
# CHECK-ASM-AND-OBJ: LSM 120,(X),(28)
# CHECK-ASM: encoding: [0x2e,0x2d,0x78,0x50,0x00,0x1c]
LSM 120,(X),(28)
# CHECK-ASM-AND-OBJ: SSM 120,(X),(28)
# CHECK-ASM: encoding: [0x2e,0x3d,0x78,0x50,0x00,0x1c]
SSM 120,(X),(28)
# CHECK-ASM-AND-OBJ: FLM 120,(X),(28)
# CHECK-ASM: encoding: [0x2e,0x4d,0x78,0x50,0x00,0x1c]
FLM 120,(X),(28)
# CHECK-ASM-AND-OBJ: MFM 120,(X),(28)
# CHECK-ASM: encoding: [0x2e,0x5d,0x78,0x50,0x00,0x1c]
MFM 120,(X),(28)
# CHECK-ASM-AND-OBJ: LDM (613),(869)
# CHECK-ASM: encoding: [0x2e,0x00,0x02,0x65,0x03,0x65]
LDM (613),(869)
# CHECK-ASM-AND-OBJ: STM (613),(869)
# CHECK-ASM: encoding: [0x2e,0x10,0x02,0x65,0x03,0x65]
STM (613),(869)
# CHECK-ASM-AND-OBJ: LSM (613),(869)
# CHECK-ASM: encoding: [0x2e,0x20,0x02,0x65,0x03,0x65]
LSM (613),(869)
# CHECK-ASM-AND-OBJ: SSM (41468),(41211)
# CHECK-ASM: encoding: [0x2e,0x30,0xa1,0xfc,0xa0,0xfb]
SSM (41468),(41211)
# CHECK-ASM-AND-OBJ: FLM (613),(869)
# CHECK-ASM: encoding: [0x2e,0x40,0x02,0x65,0x03,0x65]
FLM (613),(869)
# CHECK-ASM-AND-OBJ: MFM (613),(869)
# CHECK-ASM: encoding: [0x2e,0x50,0x02,0x65,0x03,0x65]
MFM (613),(869)
# CHECK-ASM-AND-OBJ: LDM (613),A
# CHECK-ASM: encoding: [0x2e,0x02,0x02,0x65,0x00]
LDM (613),A
# CHECK-ASM-AND-OBJ: STM (613),A
# CHECK-ASM: encoding: [0x2e,0x12,0x02,0x65,0x00]
STM (613),A
# CHECK-ASM-AND-OBJ: LSM (613),A
# CHECK-ASM: encoding: [0x2e,0x22,0x02,0x65,0x00]
LSM (613),A
# CHECK-ASM-AND-OBJ: SSM (613),A
# CHECK-ASM: encoding: [0x2e,0x32,0x02,0x65,0x00]
SSM (613),A
# CHECK-ASM-AND-OBJ: FLM (613),A
# CHECK-ASM: encoding: [0x2e,0x42,0x02,0x65,0x00]
FLM (613),A
# CHECK-ASM-AND-OBJ: MFM (613),A
# CHECK-ASM: encoding: [0x2e,0x52,0x02,0x65,0x00]
MFM (613),A
# CHECK-ASM-AND-OBJ: LDM (613),(X),5
# CHECK-ASM: encoding: [0x2e,0x01,0x02,0x65,0x40,0x05]
LDM (613),(X),5
# CHECK-ASM-AND-OBJ: STM (613),(X),5
# CHECK-ASM: encoding: [0x2e,0x11,0x02,0x65,0x40,0x05]
STM (613),(X),5
# CHECK-ASM-AND-OBJ: LSM (613),(X),5
# CHECK-ASM: encoding: [0x2e,0x21,0x02,0x65,0x40,0x05]
LSM (613),(X),5
# CHECK-ASM-AND-OBJ: SSM (613),(X),5
# CHECK-ASM: encoding: [0x2e,0x31,0x02,0x65,0x40,0x05]
SSM (613),(X),5
# CHECK-ASM-AND-OBJ: FLM (613),(X),5
# CHECK-ASM: encoding: [0x2e,0x41,0x02,0x65,0x40,0x05]
FLM (613),(X),5
# CHECK-ASM-AND-OBJ: MFM (613),(X),5
# CHECK-ASM: encoding: [0x2e,0x51,0x02,0x65,0x40,0x05]
MFM (613),(X),5
# CHECK-ASM-AND-OBJ: LDM (613),(X),(28)
# CHECK-ASM: encoding: [0x2e,0x01,0x02,0x65,0x50,0x00,0x1c]
LDM (613),(X),(28)
# CHECK-ASM-AND-OBJ: STM (613),(X),(28)
# CHECK-ASM: encoding: [0x2e,0x11,0x02,0x65,0x50,0x00,0x1c]
STM (613),(X),(28)
# CHECK-ASM-AND-OBJ: LSM (613),(X),(28)
# CHECK-ASM: encoding: [0x2e,0x21,0x02,0x65,0x50,0x00,0x1c]
LSM (613),(X),(28)
# CHECK-ASM-AND-OBJ: SSM (613),(X),(28)
# CHECK-ASM: encoding: [0x2e,0x31,0x02,0x65,0x50,0x00,0x1c]
SSM (613),(X),(28)
# CHECK-ASM-AND-OBJ: FLM (613),(X),(28)
# CHECK-ASM: encoding: [0x2e,0x41,0x02,0x65,0x50,0x00,0x1c]
FLM (613),(X),(28)
# CHECK-ASM-AND-OBJ: MFM (613),(X),(28)
# CHECK-ASM: encoding: [0x2e,0x51,0x02,0x65,0x50,0x00,0x1c]
MFM (613),(X),(28)
# CHECK-ASM-AND-OBJ: LDM B,(613)
# CHECK-ASM: encoding: [0x2e,0x08,0x20,0x02,0x65]
LDM B,(613)
# CHECK-ASM-AND-OBJ: STM B,(613)
# CHECK-ASM: encoding: [0x2e,0x18,0x20,0x02,0x65]
STM B,(613)
# CHECK-ASM-AND-OBJ: LSM B,(613)
# CHECK-ASM: encoding: [0x2e,0x28,0x20,0x02,0x65]
LSM B,(613)
# CHECK-ASM-AND-OBJ: SSM B,(613)
# CHECK-ASM: encoding: [0x2e,0x38,0x20,0x02,0x65]
SSM B,(613)
# CHECK-ASM-AND-OBJ: FLM B,(613)
# CHECK-ASM: encoding: [0x2e,0x48,0x20,0x02,0x65]
FLM B,(613)
# CHECK-ASM-AND-OBJ: MFM B,(613)
# CHECK-ASM: encoding: [0x2e,0x58,0x20,0x02,0x65]
MFM B,(613)
# CHECK-ASM-AND-OBJ: LDM B,A
# CHECK-ASM: encoding: [0x2e,0x0a,0x20]
LDM B,A
# CHECK-ASM-AND-OBJ: STM B,A
# CHECK-ASM: encoding: [0x2e,0x1a,0x20]
STM B,A
# CHECK-ASM-AND-OBJ: LSM B,A
# CHECK-ASM: encoding: [0x2e,0x2a,0x20]
LSM B,A
# CHECK-ASM-AND-OBJ: SSM B,A
# CHECK-ASM: encoding: [0x2e,0x3a,0x20]
SSM B,A
# CHECK-ASM-AND-OBJ: FLM B,A
# CHECK-ASM: encoding: [0x2e,0x4a,0x20]
FLM B,A
# CHECK-ASM-AND-OBJ: MFM B,A
# CHECK-ASM: encoding: [0x2e,0x5a,0x20]
MFM B,A
# CHECK-ASM-AND-OBJ: LDM B,(X),5
# CHECK-ASM: encoding: [0x2e,0x09,0x20,0x40,0x05]
LDM B,(X),5
# CHECK-ASM-AND-OBJ: STM B,(X),5
# CHECK-ASM: encoding: [0x2e,0x19,0x20,0x40,0x05]
STM B,(X),5
# CHECK-ASM-AND-OBJ: LSM B,(X),5
# CHECK-ASM: encoding: [0x2e,0x29,0x20,0x40,0x05]
LSM B,(X),5
# CHECK-ASM-AND-OBJ: SSM B,(X),5
# CHECK-ASM: encoding: [0x2e,0x39,0x20,0x40,0x05]
SSM B,(X),5
# CHECK-ASM-AND-OBJ: FLM B,(X),5
# CHECK-ASM: encoding: [0x2e,0x49,0x20,0x40,0x05]
FLM B,(X),5
# CHECK-ASM-AND-OBJ: MFM B,(X),5
# CHECK-ASM: encoding: [0x2e,0x59,0x20,0x40,0x05]
MFM B,(X),5
# CHECK-ASM-AND-OBJ: LDM B,(X),(28)
# CHECK-ASM: encoding: [0x2e,0x09,0x20,0x50,0x00,0x1c]
LDM B,(X),(28)
# CHECK-ASM-AND-OBJ: STM B,(X),(28)
# CHECK-ASM: encoding: [0x2e,0x19,0x20,0x50,0x00,0x1c]
STM B,(X),(28)
# CHECK-ASM-AND-OBJ: LSM B,(X),(28)
# CHECK-ASM: encoding: [0x2e,0x29,0x20,0x50,0x00,0x1c]
LSM B,(X),(28)
# CHECK-ASM-AND-OBJ: SSM B,(X),(28)
# CHECK-ASM: encoding: [0x2e,0x39,0x20,0x50,0x00,0x1c]
SSM B,(X),(28)
# CHECK-ASM-AND-OBJ: FLM B,(X),(28)
# CHECK-ASM: encoding: [0x2e,0x49,0x20,0x50,0x00,0x1c]
FLM B,(X),(28)
# CHECK-ASM-AND-OBJ: MFM B,(X),(28)
# CHECK-ASM: encoding: [0x2e,0x59,0x20,0x50,0x00,0x1c]
MFM B,(X),(28)
# CHECK-ASM-AND-OBJ: LDM (X),5,(613)
# CHECK-ASM: encoding: [0x2e,0x04,0x40,0x05,0x02,0x65]
LDM (X),5,(613)
# CHECK-ASM-AND-OBJ: STM (X),5,(613)
# CHECK-ASM: encoding: [0x2e,0x14,0x40,0x05,0x02,0x65]
STM (X),5,(613)
# CHECK-ASM-AND-OBJ: LSM (X),5,(613)
# CHECK-ASM: encoding: [0x2e,0x24,0x40,0x05,0x02,0x65]
LSM (X),5,(613)
# CHECK-ASM-AND-OBJ: SSM (X),5,(613)
# CHECK-ASM: encoding: [0x2e,0x34,0x40,0x05,0x02,0x65]
SSM (X),5,(613)
# CHECK-ASM-AND-OBJ: FLM (X),5,(613)
# CHECK-ASM: encoding: [0x2e,0x44,0x40,0x05,0x02,0x65]
FLM (X),5,(613)
# CHECK-ASM-AND-OBJ: MFM (X),5,(613)
# CHECK-ASM: encoding: [0x2e,0x54,0x40,0x05,0x02,0x65]
MFM (X),5,(613)
# CHECK-ASM-AND-OBJ: LDM (X),5,A
# CHECK-ASM: encoding: [0x2e,0x06,0x40,0x05,0x00]
LDM (X),5,A
# CHECK-ASM-AND-OBJ: STM (X),5,A
# CHECK-ASM: encoding: [0x2e,0x16,0x40,0x05,0x00]
STM (X),5,A
# CHECK-ASM-AND-OBJ: LSM (X),5,A
# CHECK-ASM: encoding: [0x2e,0x26,0x40,0x05,0x00]
LSM (X),5,A
# CHECK-ASM-AND-OBJ: SSM (X),5,A
# CHECK-ASM: encoding: [0x2e,0x36,0x40,0x05,0x00]
SSM (X),5,A
# CHECK-ASM-AND-OBJ: FLM (X),5,A
# CHECK-ASM: encoding: [0x2e,0x46,0x40,0x05,0x00]
FLM (X),5,A
# CHECK-ASM-AND-OBJ: MFM (X),5,A
# CHECK-ASM: encoding: [0x2e,0x56,0x40,0x05,0x00]
MFM (X),5,A
# CHECK-ASM-AND-OBJ: LDM (X),5,(Y),6
# CHECK-ASM: encoding: [0x2e,0x05,0x40,0x05,0x60,0x06]
LDM (X),5,(Y),6
# CHECK-ASM-AND-OBJ: STM (X),5,(Y),6
# CHECK-ASM: encoding: [0x2e,0x15,0x40,0x05,0x60,0x06]
STM (X),5,(Y),6
# CHECK-ASM-AND-OBJ: LSM (X),5,(Y),6
# CHECK-ASM: encoding: [0x2e,0x25,0x40,0x05,0x60,0x06]
LSM (X),5,(Y),6
# CHECK-ASM-AND-OBJ: SSM (X),5,(Y),6
# CHECK-ASM: encoding: [0x2e,0x35,0x40,0x05,0x60,0x06]
SSM (X),5,(Y),6
# CHECK-ASM-AND-OBJ: FLM (X),5,(Y),6
# CHECK-ASM: encoding: [0x2e,0x45,0x40,0x05,0x60,0x06]
FLM (X),5,(Y),6
# CHECK-ASM-AND-OBJ: MFM (X),5,(Y),6
# CHECK-ASM: encoding: [0x2e,0x55,0x40,0x05,0x60,0x06]
MFM (X),5,(Y),6
# CHECK-ASM-AND-OBJ: LDM (X),5,(Y),(29)
# CHECK-ASM: encoding: [0x2e,0x05,0x40,0x05,0x70,0x00,0x1d]
LDM (X),5,(Y),(29)
# CHECK-ASM-AND-OBJ: STM (X),5,(Y),(29)
# CHECK-ASM: encoding: [0x2e,0x15,0x40,0x05,0x70,0x00,0x1d]
STM (X),5,(Y),(29)
# CHECK-ASM-AND-OBJ: LSM (X),5,(Y),(29)
# CHECK-ASM: encoding: [0x2e,0x25,0x40,0x05,0x70,0x00,0x1d]
LSM (X),5,(Y),(29)
# CHECK-ASM-AND-OBJ: SSM (X),5,(Y),(29)
# CHECK-ASM: encoding: [0x2e,0x35,0x40,0x05,0x70,0x00,0x1d]
SSM (X),5,(Y),(29)
# CHECK-ASM-AND-OBJ: FLM (X),5,(Y),(29)
# CHECK-ASM: encoding: [0x2e,0x45,0x40,0x05,0x70,0x00,0x1d]
FLM (X),5,(Y),(29)
# CHECK-ASM-AND-OBJ: MFM (X),5,(Y),(29)
# CHECK-ASM: encoding: [0x2e,0x55,0x40,0x05,0x70,0x00,0x1d]
MFM (X),5,(Y),(29)
# CHECK-ASM-AND-OBJ: LDM (X),(28),(613)
# CHECK-ASM: encoding: [0x2e,0x04,0x50,0x00,0x1c,0x02,0x65]
LDM (X),(28),(613)
# CHECK-ASM-AND-OBJ: STM (X),(28),(613)
# CHECK-ASM: encoding: [0x2e,0x14,0x50,0x00,0x1c,0x02,0x65]
STM (X),(28),(613)
# CHECK-ASM-AND-OBJ: LSM (X),(28),(613)
# CHECK-ASM: encoding: [0x2e,0x24,0x50,0x00,0x1c,0x02,0x65]
LSM (X),(28),(613)
# CHECK-ASM-AND-OBJ: SSM (X),(28),(613)
# CHECK-ASM: encoding: [0x2e,0x34,0x50,0x00,0x1c,0x02,0x65]
SSM (X),(28),(613)
# CHECK-ASM-AND-OBJ: FLM (X),(28),(613)
# CHECK-ASM: encoding: [0x2e,0x44,0x50,0x00,0x1c,0x02,0x65]
FLM (X),(28),(613)
# CHECK-ASM-AND-OBJ: MFM (X),(28),(613)
# CHECK-ASM: encoding: [0x2e,0x54,0x50,0x00,0x1c,0x02,0x65]
MFM (X),(28),(613)
# CHECK-ASM-AND-OBJ: LDM (X),(28),A
# CHECK-ASM: encoding: [0x2e,0x06,0x50,0x00,0x1c,0x00]
LDM (X),(28),A
# CHECK-ASM-AND-OBJ: STM (X),(28),A
# CHECK-ASM: encoding: [0x2e,0x16,0x50,0x00,0x1c,0x00]
STM (X),(28),A
# CHECK-ASM-AND-OBJ: LSM (X),(28),A
# CHECK-ASM: encoding: [0x2e,0x26,0x50,0x00,0x1c,0x00]
LSM (X),(28),A
# CHECK-ASM-AND-OBJ: SSM (X),(28),A
# CHECK-ASM: encoding: [0x2e,0x36,0x50,0x00,0x1c,0x00]
SSM (X),(28),A
# CHECK-ASM-AND-OBJ: FLM (X),(28),A
# CHECK-ASM: encoding: [0x2e,0x46,0x50,0x00,0x1c,0x00]
FLM (X),(28),A
# CHECK-ASM-AND-OBJ: MFM (X),(28),A
# CHECK-ASM: encoding: [0x2e,0x56,0x50,0x00,0x1c,0x00]
MFM (X),(28),A
# CHECK-ASM-AND-OBJ: LDM (X),(28),(Y),6
# CHECK-ASM: encoding: [0x2e,0x05,0x50,0x00,0x1c,0x60,0x06]
LDM (X),(28),(Y),6
# CHECK-ASM-AND-OBJ: STM (X),(28),(Y),6
# CHECK-ASM: encoding: [0x2e,0x15,0x50,0x00,0x1c,0x60,0x06]
STM (X),(28),(Y),6
# CHECK-ASM-AND-OBJ: LSM (X),(28),(Y),6
# CHECK-ASM: encoding: [0x2e,0x25,0x50,0x00,0x1c,0x60,0x06]
LSM (X),(28),(Y),6
# CHECK-ASM-AND-OBJ: SSM (X),(28),(Y),6
# CHECK-ASM: encoding: [0x2e,0x35,0x50,0x00,0x1c,0x60,0x06]
SSM (X),(28),(Y),6
# CHECK-ASM-AND-OBJ: FLM (X),(28),(Y),6
# CHECK-ASM: encoding: [0x2e,0x45,0x50,0x00,0x1c,0x60,0x06]
FLM (X),(28),(Y),6
# CHECK-ASM-AND-OBJ: MFM (X),(28),(Y),6
# CHECK-ASM: encoding: [0x2e,0x55,0x50,0x00,0x1c,0x60,0x06]
MFM (X),(28),(Y),6
# CHECK-ASM-AND-OBJ: BNA 1,255,(613)
# CHECK-ASM: encoding: [0x46,0x01,0x0c,0xff,0x02,0x65]
BNA 1,255,(613)
# CHECK-ASM-AND-OBJ: BNS 1,0,(42081)
# CHECK-ASM: encoding: [0x46,0x01,0x1c,0x00,0xa4,0x61]
BNS 1,0,(42081)
# CHECK-ASM-AND-OBJ: BNC 1,255,(613)
# CHECK-ASM: encoding: [0x46,0x01,0x2c,0xff,0x02,0x65]
BNC 1,255,(613)
# CHECK-ASM-AND-OBJ: ZAD 1,255,(613)
# CHECK-ASM: encoding: [0x46,0x01,0x3c,0xff,0x02,0x65]
ZAD 1,255,(613)
# CHECK-ASM-AND-OBJ: ZSU 1,255,(613)
# CHECK-ASM: encoding: [0x46,0x01,0x4c,0xff,0x02,0x65]
ZSU 1,255,(613)
# CHECK-ASM-AND-OBJ: M 1,255,(613)
# CHECK-ASM: encoding: [0x46,0x01,0x5c,0xff,0x02,0x65]
M 1,255,(613)
# CHECK-ASM-AND-OBJ: D 1,255,(613)
# CHECK-ASM: encoding: [0x46,0x01,0x6c,0xff,0x02,0x65]
D 1,255,(613)
# CHECK-ASM-AND-OBJ: DRM 1,255,(613)
# CHECK-ASM: encoding: [0x46,0x01,0x7c,0xff,0x02,0x65]
DRM 1,255,(613)
# CHECK-ASM-AND-OBJ: CTB 1,255,(613)
# CHECK-ASM: encoding: [0x46,0x01,0x8c,0xff,0x02,0x65]
CTB 1,255,(613)
# CHECK-ASM-AND-OBJ: CFB 1,255,(613)
# CHECK-ASM: encoding: [0x46,0x01,0x9c,0xff,0x02,0x65]
CFB 1,255,(613)
# CHECK-ASM-AND-OBJ: BNA 1,255,(X),5
# CHECK-ASM: encoding: [0x46,0x01,0x0d,0xff,0x40,0x05]
BNA 1,255,(X),5
# CHECK-ASM-AND-OBJ: BNS 1,255,(X),5
# CHECK-ASM: encoding: [0x46,0x01,0x1d,0xff,0x40,0x05]
BNS 1,255,(X),5
# CHECK-ASM-AND-OBJ: BNC 1,255,(X),5
# CHECK-ASM: encoding: [0x46,0x01,0x2d,0xff,0x40,0x05]
BNC 1,255,(X),5
# CHECK-ASM-AND-OBJ: ZAD 1,255,(X),5
# CHECK-ASM: encoding: [0x46,0x01,0x3d,0xff,0x40,0x05]
ZAD 1,255,(X),5
# CHECK-ASM-AND-OBJ: ZSU 1,255,(X),5
# CHECK-ASM: encoding: [0x46,0x01,0x4d,0xff,0x40,0x05]
ZSU 1,255,(X),5
# CHECK-ASM-AND-OBJ: M 1,255,(X),5
# CHECK-ASM: encoding: [0x46,0x01,0x5d,0xff,0x40,0x05]
M 1,255,(X),5
# CHECK-ASM-AND-OBJ: D 1,255,(X),5
# CHECK-ASM: encoding: [0x46,0x01,0x6d,0xff,0x40,0x05]
D 1,255,(X),5
# CHECK-ASM-AND-OBJ: DRM 1,255,(X),5
# CHECK-ASM: encoding: [0x46,0x01,0x7d,0xff,0x40,0x05]
DRM 1,255,(X),5
# CHECK-ASM-AND-OBJ: CTB 1,255,(X),5
# CHECK-ASM: encoding: [0x46,0x01,0x8d,0xff,0x40,0x05]
CTB 1,255,(X),5
# CHECK-ASM-AND-OBJ: CFB 1,255,(X),5
# CHECK-ASM: encoding: [0x46,0x01,0x9d,0xff,0x40,0x05]
CFB 1,255,(X),5
# CHECK-ASM-AND-OBJ: BNA 1,255,A
# CHECK-ASM: encoding: [0x46,0x01,0x0e,0xff,0x00]
BNA 1,255,A
# CHECK-ASM-AND-OBJ: BNS 1,255,A
# CHECK-ASM: encoding: [0x46,0x01,0x1e,0xff,0x00]
BNS 1,255,A
# CHECK-ASM-AND-OBJ: BNC 1,255,A
# CHECK-ASM: encoding: [0x46,0x01,0x2e,0xff,0x00]
BNC 1,255,A
# CHECK-ASM-AND-OBJ: ZAD 1,255,A
# CHECK-ASM: encoding: [0x46,0x01,0x3e,0xff,0x00]
ZAD 1,255,A
# CHECK-ASM-AND-OBJ: ZSU 1,255,A
# CHECK-ASM: encoding: [0x46,0x01,0x4e,0xff,0x00]
ZSU 1,255,A
# CHECK-ASM-AND-OBJ: M 1,255,A
# CHECK-ASM: encoding: [0x46,0x01,0x5e,0xff,0x00]
M 1,255,A
# CHECK-ASM-AND-OBJ: D 1,255,A
# CHECK-ASM: encoding: [0x46,0x01,0x6e,0xff,0x00]
D 1,255,A
# CHECK-ASM-AND-OBJ: DRM 1,255,A
# CHECK-ASM: encoding: [0x46,0x01,0x7e,0xff,0x00]
DRM 1,255,A
# CHECK-ASM-AND-OBJ: CTB 1,255,A
# CHECK-ASM: encoding: [0x46,0x01,0x8e,0xff,0x00]
CTB 1,255,A
# CHECK-ASM-AND-OBJ: CFB 1,255,A
# CHECK-ASM: encoding: [0x46,0x01,0x9e,0xff,0x00]
CFB 1,255,A
# CHECK-ASM-AND-OBJ: BNA 1,255,(X),(28)
# CHECK-ASM: encoding: [0x46,0x01,0x0d,0xff,0x50,0x00,0x1c]
BNA 1,255,(X),(28)
# CHECK-ASM-AND-OBJ: BNS 1,255,(X),(28)
# CHECK-ASM: encoding: [0x46,0x01,0x1d,0xff,0x50,0x00,0x1c]
BNS 1,255,(X),(28)
# CHECK-ASM-AND-OBJ: BNC 1,255,(X),(28)
# CHECK-ASM: encoding: [0x46,0x01,0x2d,0xff,0x50,0x00,0x1c]
BNC 1,255,(X),(28)
# CHECK-ASM-AND-OBJ: ZAD 1,255,(X),(28)
# CHECK-ASM: encoding: [0x46,0x01,0x3d,0xff,0x50,0x00,0x1c]
ZAD 1,255,(X),(28)
# CHECK-ASM-AND-OBJ: ZSU 1,255,(X),(28)
# CHECK-ASM: encoding: [0x46,0x01,0x4d,0xff,0x50,0x00,0x1c]
ZSU 1,255,(X),(28)
# CHECK-ASM-AND-OBJ: M 1,255,(X),(28)
# CHECK-ASM: encoding: [0x46,0x01,0x5d,0xff,0x50,0x00,0x1c]
M 1,255,(X),(28)
# CHECK-ASM-AND-OBJ: D 1,255,(X),(28)
# CHECK-ASM: encoding: [0x46,0x01,0x6d,0xff,0x50,0x00,0x1c]
D 1,255,(X),(28)
# CHECK-ASM-AND-OBJ: DRM 1,255,(X),(28)
# CHECK-ASM: encoding: [0x46,0x01,0x7d,0xff,0x50,0x00,0x1c]
DRM 1,255,(X),(28)
# CHECK-ASM-AND-OBJ: CTB 1,255,(X),(28)
# CHECK-ASM: encoding: [0x46,0x01,0x8d,0xff,0x50,0x00,0x1c]
CTB 1,255,(X),(28)
# CHECK-ASM-AND-OBJ: CFB 1,255,(X),(28)
# CHECK-ASM: encoding: [0x46,0x01,0x9d,0xff,0x50,0x00,0x1c]
CFB 1,255,(X),(28)
# CHECK-ASM-AND-OBJ: STR B,A
# CHECK-ASM: encoding: [0xd6,0x20]
STR B,A
# CHECK-ASM-AND-OBJ: STR A,120
# CHECK-ASM: encoding: [0xd6,0x10,0x00,0x78]
STR A,120
