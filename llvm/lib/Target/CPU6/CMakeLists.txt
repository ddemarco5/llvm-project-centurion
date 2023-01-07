add_llvm_component_group(CPU6)

#set(LLVM_TARGET_DEFINITIONS CPU6.td)

add_llvm_target(CPU6CodeGen
    CPU6TargetMachine.cpp
)

add_subdirectory(TargetInfo)