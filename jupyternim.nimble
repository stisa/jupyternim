# Package

version       = "0.1.7"
author        = "Silvio T."
description   = "A Jupyter Kernel for Nim"
license       = "MIT"

# Dependencies

requires "nim >= 0.14.2"
requires "zmq"
requires "hmac"
requires "nimSHA2"
requires "python3"
# Optional: graph

bin = @["jupyternim"]
srcDir = "src"