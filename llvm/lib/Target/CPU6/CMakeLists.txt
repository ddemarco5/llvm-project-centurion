add_llvm_component_group(CPU6)

set(LLVM_TARGET_DEFINITIONS CPU6.td)

tablegen(LLVM CPU6GenRegisterInfo.inc -gen-register-info)
tablegen(LLVM CPU6GenInstrInfo.inc -gen-instr-info)
tablegen(LLVM CPU6GenMCCodeEmitter.inc -gen-emitter)
tablegen(LLVM CPU6GenAsmMatcher.inc -gen-asm-matcher)
tablegen(LLVM CPU6GenSubtargetInfo.inc -gen-subtarget)
tablegen(LLVM CPU6GenAsmWriter.inc -gen-asm-writer)
tablegen(LLVM CPU6GenDisassemblerTables.inc -gen-disassembler)
tablegen(LLVM CPU6GenCallingConv.inc -gen-callingconv)
tablegen(LLVM CPU6GenDAGISel.inc -gen-dag-isel)

add_public_tablegen_target(CPU6CommonTableGen)

add_llvm_target(CPU6CodeGen
    CPU6AsmPrinter.cpp
    CPU6CodeGenPassBuilder.cpp
    CPU6FrameLowering.cpp
    CPU6ISelDAGToDAG.cpp
    CPU6ISelLowering.cpp
    CPU6InstrInfo.cpp
    CPU6MCInstLower.cpp
    CPU6RegisterInfo.cpp
    CPU6Subtarget.cpp
    CPU6TargetMachine.cpp

    LINK_COMPONENTS
    Analysis
    AsmPrinter
    CodeGen
    CodeGenTypes
    Core
    MC
    CPU6Desc
    CPU6Info
    SelectionDAG
    Support
    Target
    TargetParser

    ADD_TO_COMPONENT
    CPU6
)

add_subdirectory(MCTargetDesc)
add_subdirectory(TargetInfo)
add_subdirectory(AsmParser)
add_subdirectory(Disassembler)