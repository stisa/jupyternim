import hotcodereloading, os, strutils

import codecells #the code to be run

template debug*(str: varargs[string, `$`]) =
  when not defined(release):
    let inst = instantiationinfo()
    echo "[" & $inst.filename & ":" & $inst.line & "] ", str.join(" ")

proc codeserver() =
  runNewJupyterCellCode()
  while true:
    if hasModuleChanged(codecells): 
      debug "#### RELOAD PERFORMED ####"
      performCodeReload()
      sleep(1000) # maybe waiting will help
      runNewJupyterCellCode()

codeserver() # run the codeserver