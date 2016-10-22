static:
  from os import getHomeDir,walkDir,`/`,PathComponent,execShellCmd
  from strutils import contains
  import json

  proc getPkgDir():string=
    let nimblePkgsDir = getHomeDir() / ".nimble" / "pkgs"
    for s in walkDir(nimblePkgsDir):
      if s.kind == pcDir and s.path.contains("INim"): return s.path
  
  let kernelspec = %*{
    "argv": [getPkgDir() / "nimkernel",  "{connection_file}"],
    "display_name": "Nim",
    "language": "nim",
    "file_extension": ".nim" }
  writeFile(getPkgDir()/"nim-spec"/"kernel.json", $kernelspec)
  echo staticExec(r"jupyter-kernelspec install " & getPkgDir() / "nim-spec" & " --user") # install the spec