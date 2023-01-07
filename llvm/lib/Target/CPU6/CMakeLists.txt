add_llvm_component_group(CPU6)

set(LLVM_TARGET_DEFINITIONS CPU6.td)

tablegen(LLVM CPU6GenRegisterInfo.inc -gen-register-info)
tablegen(LLVM CPU6GenInstrInfo.inc -gen-instr-info)

add_llvm_target(CPU6CodeGen
    CPU6TargetMachine.cpp
)

add_subdirectory(TargetInfo)