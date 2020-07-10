# Package

version       = "0.4.0"
author        = "Silvio T."
description   = "A Jupyter Kernel for Nim"
license       = "MIT"

# Dependencies

requires "nim >= 1.0.0"
requires "zmq >= 0.3.1"
requires "hmac"
requires "nimSHA2"
requires "python3@#head"
# Optional: graph

bin = @["jupyternim"]
srcDir = "src"
