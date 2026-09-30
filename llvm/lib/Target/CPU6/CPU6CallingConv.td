//===-- CPU6CallingConv.td - Calling conventions for CPU6 ----*- tablegen -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// Which physical registers hold incoming arguments and the value `ret` hands
// back. TableGen turns each CallingConv into a C++ function
// (CC_CPU6 / RetCC_CPU6) that CCState::Analyze* calls.
//
// A CC action returns false when it handled the value. If every action
// declines, the generated function returns true and Analyze* reports
// "unable to allocate function argument/return".
//
// The lists below are empty on purpose. `ret void` does not consult them.
// The first function that returns an i16 will, once LowerReturn calls
// AnalyzeReturn.

// Incoming arguments. Word values are i16 because GPR holds 16 bits.
// Uncomment and pick the registers you want the first arguments to land in.
// Anything that does not match has to go to a stack slot, and we have no
// frame store yet, so leave that for later.
//
// def CC_CPU6 : CallingConv<[
//   CCIfType<[i16], CCAssignToReg<[rA, rB, rX, rY, rZ]>>,
// ]>;
def CC_CPU6 : CallingConv<[]>;

// Where `ret i16 %v` places %v. One register is enough for the first tests.
//
// def RetCC_CPU6 : CallingConv<[
//   CCIfType<[i16], CCAssignToReg<[rA]>>,
// ]>;
def RetCC_CPU6 : CallingConv<[]>;

// Registers a call must not clobber. Empty means every allocatable register
// is caller-saved, so a call-free function does not need a prologue.
// Add registers here when a callee is expected to preserve them:
//   def CSR : CalleeSavedRegs<(add rX, rY, rZ)>;
def CSR : CalleeSavedRegs<(add)>;
