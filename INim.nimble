# Package

version       = "0.1.0"
author        = "Silvio T."
description   = "A Jupyter Kernel for Nim"
license       = "MIT"

# Dependencies

requires "nim >= 0.14.2"
requires "zmq"
requires "hmac"
requires "nimSHA2"

bin = @["nimkernel"]

after install:
  echo "Saving kernel spec"
  exec(r"nim c -r --hints:off --d:release kernelspec.nim")
  
after build:
  echo "Saving kernel spec"
  #when defined windows:
  #  echo thisDir() & r"\nimkernel"
  #else:
  #  echo thisDir() & "/nimkernel"
  exec(r"nim c -r --hints:off -d:debugBuild kernelspec.nim")
  