; A word bswap exchanges the two byte halves. XFRB prints source, then
; destination: `XFRB AL,BU` is BU = AL. There is no byte-swap opcode, and
; RLR rotates through Link. An i32 or i64 is the same swap on each word,
; with the words themselves reversed. (x << 8) | (x >> 8) is this node.
;
; RUN: llc -mtriple=cpu6 -O0 -verify-machineinstrs < %s | FileCheck %s --check-prefix=O0
; RUN: llc -mtriple=cpu6 -O2 -verify-machineinstrs < %s | FileCheck %s --check-prefix=O2

; The result is A, and the argument arrived in A. The high byte is parked
; in BL, then the halves are written back.
; O0-LABEL: bswap16:
; O0:      XFRB AU,BL
; O0-NEXT: XFRB AL,AU
; O0:      XFRB BL,AL
; O0-NEXT: RSR
; The swapped word is built in B, then copied to A.
; O2-LABEL: bswap16:
; O2-NEXT: # %bb.0:
; O2-NEXT: XFRB AL,BU
; O2-NEXT: XFRB AU,BL
; O2-NEXT: XFR B,A
; O2-NEXT: RSR
define i16 @bswap16(i16 %x) nounwind {
  %r = call i16 @llvm.bswap.i16(i16 %x)
  ret i16 %r
}

; %b arrives in B. Its low byte is the high byte of the result in A.
; O0-LABEL: bswap_b:
; O0:      XFR B,A
; O0-NEXT: XFRB AU,BL
; O0-NEXT: XFRB AL,AU
; O0:      XFRB BL,AL
; O0-NEXT: RSR
; O2-LABEL: bswap_b:
; O2-NEXT: # %bb.0:
; O2-NEXT: XFRB BL,AU
; O2-NEXT: XFRB BU,AL
; O2-NEXT: RSR
define i16 @bswap_b(i16 %a, i16 %b) nounwind {
  %r = call i16 @llvm.bswap.i16(i16 %b)
  ret i16 %r
}

; O0-LABEL: manual:
; O0:      XFRB AU,BL
; O0-NEXT: XFRB AL,AU
; O0:      XFRB BL,AL
; O0-NEXT: RSR
; O2-LABEL: manual:
; O2-NEXT: # %bb.0:
; O2-NEXT: XFRB AL,BU
; O2-NEXT: XFRB AU,BL
; O2-NEXT: XFR B,A
; O2-NEXT: RSR
define i16 @manual(i16 %x) nounwind {
  %a = shl i16 %x, 8
  %b = lshr i16 %x, 8
  %c = or i16 %a, %b
  ret i16 %c
}

; The original word is still live, so the swap is built in B and added
; back to A.
; O0-LABEL: both:
; O0:      XFRB AU,CL
; O0-NEXT: XFRB AL,BU
; O0:      XFRB CL,BL
; O0-NEXT: ADD B,A
; O0-NEXT: RSR
; O2-LABEL: both:
; O2-NEXT: # %bb.0:
; O2-NEXT: XFRB AL,BU
; O2-NEXT: XFRB AU,BL
; O2-NEXT: ADD B,A
; O2-NEXT: RSR
define i16 @both(i16 %x) nounwind {
  %r = call i16 @llvm.bswap.i16(i16 %x)
  %s = add i16 %r, %x
  ret i16 %s
}

; High half in A, low half in B. The words are exchanged, then each is
; byte-swapped. At -O2 the low word's bytes land in C and the high word's
; bytes land back in B.
; O0-LABEL: bswap32:
; O0:      XAB
; O0:      XFRB AU,CL
; O0-NEXT: XFRB AL,AU
; O0:      XFRB CL,AL
; O0:      XFRB BU,CL
; O0-NEXT: XFRB BL,BU
; O0:      XFRB CL,BL
; O0:      RSR
; O2-LABEL: bswap32:
; O2-NEXT: # %bb.0:
; O2-NEXT: XFRB BL,CU
; O2-NEXT: XFRB BU,CL
; O2-NEXT: XFRB AL,BU
; O2-NEXT: XFRB AU,BL
; O2-NEXT: XFR C,A
; O2-NEXT: RSR
define i32 @bswap32(i32 %x) nounwind {
  %r = call i32 @llvm.bswap.i32(i32 %x)
  ret i32 %r
}

; A, B, Y, Z are the four words, high first. The result is those words
; reversed and each byte-swapped.
; O0-LABEL: bswap64:
; O0:      XFR B,Y
; O0:      XAZ
; O0:      XFRB AU,CL
; O0-NEXT: XFRB AL,AU
; O0:      XFRB CL,AL
; O0:      XFRB BU,CL
; O0-NEXT: XFRB BL,BU
; O0:      XFRB CL,BL
; O0:      XFRB YU,CL
; O0-NEXT: XFRB YL,YU
; O0:      XFRB CL,YL
; O0:      XFRB ZU,CL
; O0-NEXT: XFRB ZL,ZU
; O0:      XFRB CL,ZL
; O0:      RSR
; O2-LABEL: bswap64:
; O2:      XFRB ZL,CU
; O2-NEXT: XFRB ZU,CL
; O2-NEXT: XFRB YL,XU
; O2-NEXT: XFRB YU,XL
; O2-NEXT: XFRB BL,YU
; O2-NEXT: XFRB BU,YL
; O2-NEXT: XFRB AL,ZU
; O2-NEXT: XFRB AU,ZL
; O2-NEXT: XFR C,A
; O2-NEXT: XFR X,B
; O2:      RSR
define i64 @bswap64(i64 %x) nounwind {
  %r = call i64 @llvm.bswap.i64(i64 %x)
  ret i64 %r
}

declare i16 @llvm.bswap.i16(i16)
declare i32 @llvm.bswap.i32(i32)
declare i64 @llvm.bswap.i64(i64)
