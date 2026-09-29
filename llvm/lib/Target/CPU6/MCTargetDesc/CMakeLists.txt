add_llvm_component_library(LLVMCPU6Desc
    CPU6AsmBackend.cpp
    CPU6ELFObjectWriter.cpp
    CPU6InstPrinter.cpp
    CPU6MCAsmInfo.cpp
    CPU6MCCodeEmitter.cpp
    CPU6MCTargetDesc.cpp

    LINK_COMPONENTS
    MC
    CPU6Info
    Support

    ADD_TO_COMPONENT
    CPU6
)