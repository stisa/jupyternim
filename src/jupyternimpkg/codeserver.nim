{.push warning[User]:off .}

import hotcodereloading, os, strutils

import codecells #the code to be run

template debug*(str: varargs[string, `$`]) =
  when not defined(release):
    let inst = instantiationinfo()
    echo "[" & $inst.filename & ":" & $inst.line & "] ", str.join(" ")

proc codeserver() =
  # we start in paused state, then when we get run we exec once and then go back to paused
  var pausedbyJN = true
  while true:
    let cmd = stdin.readLine
    debug "CODESERVERGOTACOMMAND", cmd
    if cmd.contains("#runNimCodeServer"):
      debug cmd.contains("#runNimCodeServer")
      pausedbyJN = false
    
    if pausedbyJN: continue

  
    performCodeReload()
    debug "#### RELOAD PERFORMED ####"
    runNewJupyterCellCode()

    pausedbyJN = true
    stdout.writeLine("#serverReplied")      
    stdout.flushFile

codeserver() # run the codeserver

{.pop.}