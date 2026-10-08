import argparse, pathlib, shlex, subprocess
parser=argparse.ArgumentParser()
parser.add_argument("build",type=pathlib.Path)
parser.add_argument("output",type=pathlib.Path)
a=parser.parse_args(); build=a.build.resolve(); out=a.output.resolve(); out.mkdir(parents=True,exist_ok=True)
source=pathlib.Path(__file__).resolve().parent
lines=subprocess.check_output(["ninja","-C",str(build),"-t","commands","AppKit"],text=True).splitlines()
argv=shlex.split(next(x for x in lines if " -c " in x and "/NSView.m" in x))
clean=[]; i=0
while i<len(argv):
 x=argv[i]
 if x in ("-o","-c","-MT","-MF"): i+=2; continue
 if x in ("-MD","-MMD"): i+=1; continue
 clean.append(x); i+=1
assert "aarch64-apple-darwin20" in clean or "arm64" in clean
link=next(x for x in lines if " -o src/external/cocotron/AppKit/AppKit " in x)
maps=[x for x in shlex.split(link) if "-dylib_file," in x]
for name in ["graphics","window"]:
 obj=out/(name+".o")
 subprocess.run(clean+["-c",str(source/(name+".m")),"-o",str(obj)],cwd=build,check=True)
 subprocess.run(["/usr/bin/clang","-target","aarch64-apple-darwin20","-nostdlib",
  "-fuse-ld="+str(build/"host-tools-build/ld64/aarch64-apple-darwin20-ld"),"-Wl,-Z",
  "-Wl,-platform_version,macos,11.0,11.0",*maps,"-o",str(out/name),str(obj),
  "src/external/cocotron/AppKit/AppKit","src/external/cocotron/QuartzCore/QuartzCore",
  "src/external/foundation/Foundation","src/external/objc4/runtime/libobjc.A.dylib",
  "src/external/libsystem/libSystem.B.dylib","src/external/metal/Metal"],cwd=build,check=True)
