static:
  from os import getHomeDir,walkDir,`/`,PathComponent,execShellCmd,parentDir,existsFile,existsDir,createDir
  from strutils import contains
  import json

  proc getPkgDir():string=
    when defined debugBuild:
      result = parentDir(currentSourcePath())
    else:
      let nimblePkgsDir = getHomeDir() / ".nimble" / "pkgs"
      for s in walkDir(nimblePkgsDir):
        if s.kind == pcDir and s.path.contains("INim"): return s.path

  # Save the kernel spec
  let kernelspec = %*{
    "argv": [getPkgDir() / "nimkernel",  "{connection_file}"],
    "display_name": "Nim",
    "language": "nim",
    "file_extension": ".nim" }
  
  writeFile(getPkgDir()/"nim-spec"/"kernel.json", $kernelspec)
  echo staticExec(r"jupyter-kernelspec install " & getPkgDir() / "nim-spec" & " --user") # install the spec

# Append custom js
var custompath = getHomeDir()/".jupyter"/"custom"/"custom.js"
createDir(parentDir(custompath)) # create the dirs we need to store custom.js
proc appendCustom(f:string)=
  var f = open(getHomeDir()/".jupyter"/"custom"/"custom.js",fmAppend)
  
  f.write(readFile(getPkgDir()/"nim-mode"/"custom.js"))
  f.close()

if existsDir(parentDir(custompath)): appendCustom(custompath)
else: echo "Could not install highlighting, refer to github.com/stisa/INim for instructions to manually do this"
