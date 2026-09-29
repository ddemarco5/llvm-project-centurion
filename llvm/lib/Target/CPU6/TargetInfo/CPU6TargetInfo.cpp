#include "TargetInfo/CPU6TargetInfo.h"
#include "llvm/MC/TargetRegistry.h"

using namespace llvm;

Target &llvm::getTheCPU6Target() {
    static Target TheCPU6Target;
    return TheCPU6Target;
}

extern "C" LLVM_EXTERNAL_VISIBILITY void LLVMInitializeCPU6TargetInfo() {
    RegisterTarget<Triple::cpu6, /*HasJIT=*/false> X(getTheCPU6Target(), "cpu6", "Centurion CPU6", "CPU6");
}
