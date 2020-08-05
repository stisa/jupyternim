# Package

version       = "0.5.1"
author        = "stisa"
description   = "A Jupyter Kernel for Nim"
license       = "MIT"

# Dependencies

requires "nim >= 1.0.0"
requires "zmq >= 0.3.1"
requires "hmac"
requires "nimSHA2"

installDirs = @["jupyternimpkg", "jupyternimspec"]
srcDir = "src"
bin = @["jupyternim"]

after install:
  exec("jupyternim")