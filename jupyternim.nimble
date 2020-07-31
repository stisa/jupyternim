# Package

version       = "0.5.0"
author        = "stisa"
description   = "A Jupyter Kernel for Nim"
license       = "MIT"

# Dependencies

requires "nim >= 1.0.0"
requires "zmq >= 0.3.1"
requires "hmac"
requires "nimSHA2"

srcDir = "src"

bin = @["jupyternim"]
