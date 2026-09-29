add_llvm_component_library(LLVMCPU6Info
  CPU6TargetInfo.cpp

  LINK_COMPONENTS
  MC
  Support

  ADD_TO_COMPONENT
  CPU6
  )