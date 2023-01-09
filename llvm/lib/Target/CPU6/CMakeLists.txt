add_llvm_component_group(CPU6)

set(LLVM_TARGET_DEFINITIONS CPU6.td)

tablegen(LLVM CPU6GenRegisterInfo.inc -gen-register-info)
tablegen(LLVM CPU6GenInstrInfo.inc -gen-instr-info)
tablegen(LLVM CPU6GenMCCodeEmitter.inc -gen-emitter)
tablegen(LLVM CPU6GenAsmMatcher.inc -gen-asm-matcher)
tablegen(LLVM CPU6GenSubtargetInfo.inc -gen-subtarget)
tablegen(LLVM CPU6GenAsmWriter.inc -gen-asm-writer)

add_public_tablegen_target(CPU6CommonTableGen)

add_llvm_target(CPU6CodeGen
    CPU6TargetMachine.cpp

    LINK_COMPONENTS
    MC
    CPU6Desc
    CPU6Info
    Support
    Target

    ADD_TO_COMPONENT
    CPU6
)

add_subdirectory(MCTargetDesc)
add_subdirectory(TargetInfo)
add_subdirectory(AsmParser)