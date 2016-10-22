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

after install:
  echo "Saving kernel spec"
  echo(r"nim c kernelspec.nim")
  echo "Building Kernel"
  exec(r"nim c --threads:on nimkernel.nim") # compile kernel
  exec(r"jupyter-kernelspec install nim-spec") # install the spec
  
task setup, "Setup the Kernel":
  exec(r"nim c --threads:on nimkernel.nim") # compile kernel
  exec(r"jupyter-kernelspec install nim-spec") # install the spec
  setCommand("nop")

task buildkernel, "Build the Kernel":
  exec(r"nim c --threads:on nimkernel.nim") # compile kernel
