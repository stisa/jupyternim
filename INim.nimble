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

## Post install setup
#postinstall:
#  exec "nim c --threads:on -d:release nimkernel.nim" # compile the kernel

#  write the spec... 

#  writeFile("nim-spec/kernel.json", r"""{
# "argv": ["<nimbledir>\inim\\nimkernel",  "{connection_file}"],
#  "display_name": "nim - pure",
#  "language": "nim",
#  "file_extension": ".nim"
#}""")

#  exec "jupyter-kernelspec install nim-spec" # install the spec
#  setCommand("nop")
