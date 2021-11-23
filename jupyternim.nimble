# Package

version       = "0.7.0"
author        = "stisa"
description   = "A Jupyter Kernel for Nim"
license       = "MIT"

# Dependencies

requires "nim >= 1.2.0"
requires "zmq >= 1.2.1 & < 1.3.0"
requires "hmac >= 0.2.0 & < 0.3.0"
requires "nimSHA2#b8f666069dff1ed0c5142dd1ca692f0e71434716"
requires "nimPNG >= 0.3.1 & < 0.4.0"
requires "regex >= 0.19.0 & < 0.20.0"

installDirs = @["jupyternimpkg", "jupyternimspec"]
srcDir = "src"
bin = @["jupyternim"]

import os, strutils

after install:
  when defined(macosx) and defined(arm64):
    # M1 Homebrew lives in /opt/homebrew; libzmq isn't in /usr/local.
    # Setting DYLD_LIBRARY_PATH works in some cases, but macOS "SIP" nulls out
    # DYLD_LIBRARY_PATH for some child procs (/bin/sh, /usr/bin/env). gorgeEx
    # uses /bin/sh so running jupyternim from NimScript will fail to find
    # libzmq.dylib.
    echo "\nTo install Jupyter Nim kernel, run:\n"
    echo "  jupyternim\n"
  else:
    var jnpath = gorgeEx("nimble path jupyternim")
    jnpath.output.stripLineEnd
    if jnpath.exitCode == 0:
      var path = jnpath.output.splitLines()[^1]
      exec(path / bin[0].changeFileExt(ExeExt))
    else:
      echo "Error: jupyternim not installed in nimble"

task dev, "Build a debug version":
  # Assumes cwd is jupyternim/
  var jnpath = gorgeEx("nimble path jupyternim")
  jnpath.output.stripLineEnd
  if jnpath.exitCode == 0:
    var path = jnpath.output.splitLines()[^1]
    exec("nim c -d:debug -o:" & path / bin[0].changeFileExt(ExeExt) & " src/jupyternim.nim")
  else:
    echo "Can't find an installed jupyternim"

task hcr, "Build a debug version with -d:useHcr":
  # Assumes cwd is jupyternim/
  var jnpath = gorgeEx("nimble path jupyternim")
  jnpath.output.stripLineEnd
  if jnpath.exitCode == 0:
    var path = jnpath.output.splitLines()[^1]
    exec("nim c -d:debug -d:useHcr -o:" & path / bin[0].changeFileExt(ExeExt) & " src/jupyternim.nim")
  else:
    echo "Can't find an installed jupyternim"

task rhcr, "Build and register a release version with -d:useHcr":
  # Assumes cwd is jupyternim/
  var jnpath = gorgeEx("nimble path jupyternim")
  jnpath.output.stripLineEnd
  if jnpath.exitCode == 0:
    var path = jnpath.output.splitLines()[^1]
    exec("nim c -d:release -d:useHcr -o:" & path / bin[0].changeFileExt(ExeExt) & " src/jupyternim.nim")
    exec(path / bin[0].changeFileExt(ExeExt))
  else:
    echo "Can't find an installed jupyternim"

task docs, "Build docs":
  exec(r"nim doc -O:.\docs\display.html .\src\jupyternimpkg\display.nim")
  exec(r"nim doc -O:.\docs\index.html .\src\jupyternim.nim")
