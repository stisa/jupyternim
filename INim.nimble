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
# Optional: graph

##  Write the spec... 
#  writeFile("nim-spec/kernel.json", r"""{
# "argv": ["<nimbledir>\inim\\nimkernel",  "{connection_file}"],
#  "display_name": "nim - pure",
#  "language": "nim",
#  "file_extension": ".nim"
#}""")
bin = @["nimkernel"]

after install:
  echo "Saving kernel spec"
  echo thisDir() & "nimkernel"
  exec(r"nim c --hints:off --d:release kernelspec.nim")
  
after build:
  echo "Saving kernel spec"
  #when defined windows:
  #  echo thisDir() & r"\nimkernel"
  #else:
  #  echo thisDir() & "/nimkernel"
  exec(r"nim c -d:debugBuild kernelspec.nim")

task setup, "Setup the Kernel":
  echo "Saving kernel spec"
  exec(r"nim c kernelspec.nim")
  echo "Building Kernel"
  exec(r"nim c --threads:on nimkernel.nim") # compile kernel
  exec(r"jupyter-kernelspec install nim-spec --user") # install the spec

task buildkernel, "Build the Kernel":
  exec(r"nim c --threads:on nimkernel.nim") # compile kernel
