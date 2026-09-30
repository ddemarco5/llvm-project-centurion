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
// `ret void` does not consult these lists. A returned i16 does, once
// LowerReturn calls AnalyzeReturn.

// Incoming arguments. Word values are i16 because GPR holds 16 bits.
// Uncomment and pick the registers you want the first arguments to land in.
// Anything that does not match has to go to a stack slot, and we have no
// frame store yet, so leave that for later.

def CC_CPU6 : CallingConv<[
  CCIfType<[i16], CCAssignToReg<[rA, rB, rY, rZ]>>,
]>;

// Where `ret i16 %v` places %v. One register is enough for the first tests.

def RetCC_CPU6 : CallingConv<[
  CCIfType<[i16], CCAssignToReg<[rA]>>,
]>;

// Registers a callee must hand back unchanged. X, Y, and Z sit next to each
// other, so STK and POP can move a contiguous stretch in one instruction.
// A function that writes only Z saves Z. One that writes X and Z, but not Y,
// saves those two and leaves the gap. spillCalleeSavedRegisters emits that.
// A, B, C, and P stay caller-saved. Y and Z are also argument registers:
// the incoming value is the argument, and the callee still restores it.
// X has to be here: it holds the return address that RSR jumps through.
// The order is Z, Y, X on purpose. The prologue inserter gives the first
// register in this list the slot nearest the incoming S, and STK leaves Z
// there with X at the lowest address.
def CSR : CalleeSavedRegs<(add rZ, rY, rX)>;
