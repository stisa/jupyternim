# Package

version       = "0.2.0"
author        = "Silvio T."
description   = "A Jupyter Kernel for Nim"
license       = "MIT"

# Dependencies

requires "nim >= 1.0.0"
requires "zmq"
requires "hmac"
requires "nimSHA2"
requires "python3"
# Optional: graph

bin = @["jupyternim"]
srcDir = "src"