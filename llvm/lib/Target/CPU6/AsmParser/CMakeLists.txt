add_llvm_component_library(LLVMCPU6AsmParser
CPU6AsmParser.cpp

LINK_COMPONENTS
MC
MCParser
CPU6Desc
CPU6Info
Support


ADD_TO_COMPONENT
CPU6
)