set(LLVM_LINK_COMPONENTS
  BinaryFormat
  Object
  Support
  )

add_llvm_tool(llvm-cpu6-ld
  llvm-cpu6-ld.cpp
  )
