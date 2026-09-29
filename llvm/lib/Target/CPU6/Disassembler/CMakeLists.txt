add_llvm_component_library(LLVMCPU6Disassembler
CPU6Disassembler.cpp

LINK_COMPONENTS
MC
MCDisassembler
CPU6Desc
CPU6Info
Support


ADD_TO_COMPONENT
CPU6
)