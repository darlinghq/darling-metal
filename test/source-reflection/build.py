import argparse, pathlib, shlex, subprocess
parser=argparse.ArgumentParser()
parser.add_argument("build", type=pathlib.Path)
parser.add_argument("output", type=pathlib.Path)
parser.add_argument("--library", type=pathlib.Path)
parser.add_argument("--candidate", action="store_true")
parser.add_argument("--reader", type=pathlib.Path)
args=parser.parse_args()
build=args.build.resolve(); output=args.output.resolve()
source=pathlib.Path(__file__).resolve().parents[2]
lines=subprocess.check_output(["ninja", "-C", str(build), "-t", "commands", "Metal"],text=True).splitlines()
line=next(x for x in lines if " -c " in x and "/MTLMSLReflection.mm" in x)
argv=shlex.split(line); donor=pathlib.Path(argv[argv.index("-c")+1]).parents[2]
clean=[]; i=0
while i<len(argv):
 a=argv[i]
 if a in ("-o", "-c", "-MT", "-MF"): i+=2; continue
 if a in ("-MD", "-MMD"): i+=1; continue
 clean.append(a.replace(str(donor),str(source))); i+=1
assert "aarch64-apple-darwin20" in clean or "arm64" in clean
objects=[str(output.with_suffix(".o"))]
subprocess.run(clean+["-c",str(source/"test/source-reflection/resources.mm"),"-o",objects[0]],cwd=build,check=True)
if args.candidate or args.reader:
 reader=str(output.with_suffix(".reader.o"))
 subprocess.run(clean+["-c",str(args.reader.resolve() if args.reader else source/"src/Metal/MTLMSLReflection.mm"),"-o",reader],cwd=build,check=True)
 objects.append(reader)
link=next(x for x in lines if " -o src/external/metal/Metal " in x)
maps=[x for x in shlex.split(link) if "-dylib_file," in x]
library=args.library.resolve() if args.library else build/"src/external/metal/Metal"
subprocess.run(["/usr/bin/clang","-target","aarch64-apple-darwin20","-nostdlib",
 "-fuse-ld="+str(build/"host-tools-build/ld64/aarch64-apple-darwin20-ld"),
 "-Wl,-Z","-Wl,-platform_version,macos,11.0,11.0",*maps,"-o",str(output),*objects,
 str(library),"src/external/foundation/Foundation","src/external/objc4/runtime/libobjc.A.dylib",
 "src/external/libsystem/libSystem.B.dylib","src/external/libcxx/libc++.1.dylib"],cwd=build,check=True)
