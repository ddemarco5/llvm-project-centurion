import os
import subprocess
import tempfile
from pathlib import Path

llc = Path("build/Release/bin/llc.exe")
mc = Path("build/Release/bin/llvm-mc.exe")
tmp = Path(tempfile.gettempdir())

cases = {
    "regadd": "define i16 @f(i16 %a, i16 %b) { %v = add i16 %a, %b\n ret i16 %v }\n",
    "sub-imm": "define i16 @f(i16 %a) { %v = sub i16 %a, 3\n ret i16 %v }\n",
    "branch": "define i16 @f(i16 %a) {\n %c = icmp eq i16 %a, 0\n br i1 %c, label %t, label %e\nt:\n ret i16 1\ne:\n ret i16 2 }\n",
    "global-ld": "@g = global i16 5\ndefine i16 @f() { %v = load i16, ptr @g\n ret i16 %v }\n",
    "ptr-ld": "define i16 @f(ptr %p) { %v = load i16, ptr %p\n ret i16 %v }\n",
    "gep-local": "define i16 @f(i16 %a) {\n %p = alloca [2 x i16]\n %q = getelementptr i16, ptr %p, i16 1\n store i16 %a, ptr %q\n %v = load i16, ptr %q\n ret i16 %v }\n",
    "addr-local": "declare void @use(ptr)\ndefine void @f() { %p = alloca i16\n call void @use(ptr %p)\n ret void }\n",
    "call": "declare i16 @g(i16)\ndefine i16 @f(i16 %a) { %v = call i16 @g(i16 %a)\n ret i16 %v }\n",
    "spill": "define i16 @f(i16 %a, i16 %b, i16 %c, i16 %d) {\n %x = add i16 %a, 1\n %y = add i16 %b, 2\n %z = add i16 %c, 3\n %w = add i16 %d, 4\n %p = alloca i16\n store i16 %x, ptr %p\n store i16 %y, ptr %p\n store i16 %z, ptr %p\n store i16 %w, ptr %p\n ret i16 %a }\n",
    "i8": "define i8 @f(i8 %a) { %v = add i8 %a, 1\n ret i8 %v }\n",
    "i32": "define i32 @f(i32 %a) { %v = add i32 %a, 1\n ret i32 %v }\n",
    "alloca-vla": "define void @f(i16 %n) { %p = alloca i16, i16 %n\n ret void }\n",
    "vararg": "define void @f(i16 %a, ...) { ret void }\n",
    "select": "define i16 @f(i16 %a, i16 %b, i1 %c) { %v = select i1 %c, i16 %a, i16 %b\n ret i16 %v }\n",
    "mul": "define i16 @f(i16 %a, i16 %b) { %v = mul i16 %a, %b\n ret i16 %v }\n",
    "sdiv": "define i16 @f(i16 %a, i16 %b) { %v = sdiv i16 %a, %b\n ret i16 %v }\n",
    "urem": "define i16 @f(i16 %a, i16 %b) { %v = urem i16 %a, %b\n ret i16 %v }\n",
    "shl": "define i16 @f(i16 %a, i16 %b) { %v = shl i16 %a, %b\n ret i16 %v }\n",
    "switch": "define i16 @f(i16 %a) { switch i16 %a, label %d [ i16 1, label %a1 i16 2, label %a2 ]\na1: ret i16 1\na2: ret i16 2\nd: ret i16 0 }\n",
    "phi-loop": "define i16 @f(i16 %n) {\nentry:\n br label %loop\nloop:\n %i = phi i16 [ 0, %entry ], [ %n2, %loop ]\n %n2 = add i16 %i, 1\n %c = icmp ult i16 %n2, %n\n br i1 %c, label %loop, label %done\ndone:\n ret i16 %n2 }\n",
}

def run(args, src_text, src_name):
    p = tmp / src_name
    p.write_text(src_text, encoding="ascii")
    r = subprocess.run(args + [str(p)], capture_output=True, text=True)
    blob = (r.stderr or "") + (r.stdout or "")
    if r.returncode == 0:
        return "ok"
    for line in blob.splitlines():
        if any(k in line for k in ("LLVM ERROR", "UNREACHABLE", "Cannot select", "error:", "fatal error")):
            return line.strip()[:180]
    return f"exit {r.returncode}"

print("-- llc -O0 asm --")
for name, ir in cases.items():
    print(f"{name:12} {run([str(llc), '-mtriple=cpu6', '-O0', '-verify-machineinstrs', '-o', 'NUL'], ir, name + '.ll')}")

print("-- llc -O2 asm (subset) --")
for name in ("branch", "call", "spill", "phi-loop", "global-ld"):
    print(f"{name:12} {run([str(llc), '-mtriple=cpu6', '-O2', '-verify-machineinstrs', '-o', 'NUL'], cases[name], name + '2.ll')}")

print("-- llc -filetype=obj --")
for name in ("branch", "call", "global-ld", "addr-local"):
    print(f"{name:12} {run([str(llc), '-mtriple=cpu6', '-O0', '-filetype=obj', '-o', str(tmp / (name + '.o'))], cases[name], name + 'o.ll')}")

print("-- llvm-mc labels --")
asms = {
    "JMP": "JMP lbl\nlbl: RSR\n",
    "JSR": "JSR lbl\nlbl: RSR\n",
    "BZ": "BZ lbl\nlbl: RSR\n",
    "LDA": "LDA lbl\nlbl: RSR\n",
}
for name, src in asms.items():
    print(f"{name:12} {run([str(mc), '-triple=cpu6', '-filetype=obj', '-o', 'NUL'], src, name + '.s')}")
