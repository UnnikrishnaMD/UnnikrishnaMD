#!/usr/bin/env python3
"""Turn the Processing sketch folder into one plain Java file, doing the same
rewrites the Processing preprocessor does (float literals, float() casts,
public draw/setup/settings/keyPressed), so the sketch can be compiled against
processing core and run without the Processing app.

usage: pde_to_java.py <sketch_folder> <out.java> [NAME=value ...]
NAME=value overrides a top-level setting, e.g. RECORD_ON_START=true
"""
import re, sys, pathlib

folder, out = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
overrides = dict(a.split("=", 1) for a in sys.argv[3:])
main = folder / (folder.name + ".pde")
tabs = [main] + sorted(p for p in folder.glob("*.pde") if p != main)
src = "\n".join(p.read_text() for p in tabs)

# the PDF exporter needs the pdf library; the headless render doesn't use it
src = src.replace("import processing.pdf.*;", "")
src = re.sub(r"void savePDF\(\) \{.*?\n\}\n", "void savePDF() { println(\"PDF export is not part of the headless build\"); }\n", src, flags=re.S)

for name, value in overrides.items():
    src, n = re.subn(rf"^(\s*\w+\s+{name}\s*=\s*)[^;]+;", rf"\g<1>{value};", src, count=1, flags=re.M)
    if not n: sys.exit(f"setting {name} not found")

imports = re.findall(r"^import [^;]+;\n", src, flags=re.M)
src = re.sub(r"^import [^;]+;\n", "", src, flags=re.M)

STR = re.compile(r'"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])\'|//[^\n]*|/\*.*?\*/', re.S)
def code_only(text):
    parts, last = [], 0
    for m in STR.finditer(text):
        parts.append(fix(text[last:m.start()])); parts.append(m.group(0)); last = m.end()
    parts.append(fix(text[last:]))
    return "".join(parts)

def fix(code):
    code = re.sub(r"(?<![\w.])(\d+\.\d*|\.\d+)(?![\w.])", r"\1f", code)   # 0.5 → 0.5f
    code = re.sub(r"\bfloat\(", "parseFloat(", code)
    code = re.sub(r"\bint\(", "parseInt(", code)
    code = re.sub(r"^void (settings|setup|draw|keyPressed)\(\)", r"public void \1()", code, flags=re.M)
    return code

src = code_only(src)
cls = "Sketch"
java = ("import processing.core.*;\nimport java.util.*;\n" + "".join(imports) +
        f"\npublic class {cls} extends PApplet {{\n{src}\n"
        f"  public static void main(String[] args) {{ PApplet.main(\"{cls}\", args); }}\n}}\n")
out.write_text(java)
print("wrote", out)
