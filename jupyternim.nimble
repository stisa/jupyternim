# Package

version       = "0.5.8"
author        = "stisa"
description   = "A Jupyter Kernel for Nim"
license       = "MIT"

# Dependencies

requires "nim >= 1.0.0"
requires "zmq >= 0.3.1"
requires "hmac"
requires "nimSHA2"
requires "nimPNG"

installDirs = @["jupyternimpkg", "jupyternimspec"]
srcDir = "src"
bin = @["jupyternim"]

import os, strutils

after install:
  var jnpath = gorgeEx("nimble path jupyternim")
  jnpath.output.stripLineEnd
  if jnpath.exitCode == 0:
    exec(jnpath.output / bin[0].changeFileExt(ExeExt))
  else:
    echo "Error: jupyternim not installed in nimble"

task dev, "Build a debug version":
  # Assumes cwd is jupyternim/
  var jnpath = gorgeEx("nimble path jupyternim")
  jnpath.output.stripLineEnd
  if jnpath.exitCode == 0:
    exec("nim c -d:debug -o:" & jnpath.output / bin[0].changeFileExt(ExeExt) & " src/jupyternim.nim")
  else:
    echo "Can't find an installed jupyternim"

task hcr, "Build a debug version with -d:useHcr":
  # Assumes cwd is jupyternim/
  var jnpath = gorgeEx("nimble path jupyternim")
  jnpath.output.stripLineEnd
  if jnpath.exitCode == 0:
    exec("nim c -d:debug -d:useHcr -o:" & jnpath.output / bin[0].changeFileExt(ExeExt) & " src/jupyternim.nim")
  else:
    echo "Can't find an installed jupyternim"

task rhcr, "Build and register a release version with -d:useHcr":
  # Assumes cwd is jupyternim/
  var jnpath = gorgeEx("nimble path jupyternim")
  jnpath.output.stripLineEnd
  if jnpath.exitCode == 0:
    exec("nim c -d:release -d:useHcr -o:" & jnpath.output / bin[0].changeFileExt(ExeExt) & " src/jupyternim.nim")
    exec(jnpath.output / bin[0].changeFileExt(ExeExt))
  else:
    echo "Can't find an installed jupyternim"
